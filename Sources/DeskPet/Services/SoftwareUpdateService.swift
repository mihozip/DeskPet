import AppKit
import Combine
import Foundation

@MainActor
final class SoftwareUpdateService: ObservableObject {
    enum UpdateError: LocalizedError {
        case invalidResponse
        case invalidVersion
        case updaterMissing
        case updaterInvalid

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "GitHub 更新資訊回傳格式無法辨識"
            case .invalidVersion: return "遠端 VERSION 格式不正確"
            case .updaterMissing: return "App bundle 內缺少 DeskPetUpdater.sh"
            case .updaterInvalid: return "更新程式未通過完整性格式檢查"
            }
        }
    }

    @Published private(set) var statusMessage = "尚未檢查更新"
    @Published private(set) var isChecking = false
    @Published private(set) var isInstalling = false
    @Published private(set) var availableVersion: String?
    @Published private(set) var installProgress = 0.0
    @Published private(set) var installStage = ""

    var onUpdateAvailable: ((String) -> Void)?

    let currentVersion: String

    private static let versionURL = URL(string: "https://raw.githubusercontent.com/mihozip/DeskPet/main/VERSION")!
    private static let lastAutomaticCheckKey = "DeskPet.softwareUpdate.lastAutomaticCheck.v1"
    private static let automaticCheckInterval: TimeInterval = 7 * 24 * 60 * 60
    private static let duePollingNanoseconds: UInt64 = 60 * 60 * 1_000_000_000
    private let session: URLSession
    private var updateProcess: Process?
    private var updateLogHandle: FileHandle?
    private var updateOutputPipe: Pipe?
    private var updateOutputBuffer = Data()
    private var hasRequestedTerminationForUpdate = false
    private var automaticCheckTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
        currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0.0"
    }

    var canInstall: Bool {
        availableVersion != nil && !isChecking && !isInstalling
    }

    var installPercentage: Int {
        Int((installProgress * 100).rounded())
    }

    /// Keeps a lightweight local due-check running while DeskPet is open. The
    /// network request itself is still gated to once every seven days.
    func startAutomaticChecking() {
        automaticCheckTask?.cancel()
        automaticCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkIfDue()
                try? await Task.sleep(nanoseconds: Self.duePollingNanoseconds)
            }
        }
    }

    func stopAutomaticChecking() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil
    }

    func checkIfDue() {
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastAutomaticCheckKey) as? Date
        if let lastCheck, Date().timeIntervalSince(lastCheck) < Self.automaticCheckInterval { return }
        Task { await checkForUpdates(isAutomatic: true) }
    }

    func checkForUpdates(isAutomatic: Bool = false) async {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        if !isAutomatic { statusMessage = "正在向 GitHub 檢查更新…" }
        defer { isChecking = false }

        do {
            var request = URLRequest(url: Self.versionURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 12
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  data.count <= 128,
                  let text = String(data: data, encoding: .utf8) else {
                throw UpdateError.invalidResponse
            }

            let latestVersion = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard Self.isValidVersion(latestVersion) else { throw UpdateError.invalidVersion }
            UserDefaults.standard.set(Date(), forKey: Self.lastAutomaticCheckKey)

            if Self.compareVersions(latestVersion, currentVersion) == .orderedDescending {
                availableVersion = latestVersion
                statusMessage = "有新版本：\(latestVersion)（目前 \(currentVersion)）"
                if isAutomatic {
                    onUpdateAvailable?(latestVersion)
                }
            } else {
                availableVersion = nil
                statusMessage = "已是最新版本：\(currentVersion)"
            }
        } catch {
            if !isAutomatic {
                statusMessage = "檢查更新失敗：\(error.localizedDescription)"
            }
        }
    }

    func installAvailableUpdate() {
        guard canInstall else { return }
        do {
            guard let updaterURL = Bundle.main.url(forResource: "DeskPetUpdater", withExtension: "sh") else {
                throw UpdateError.updaterMissing
            }
            let updaterData = try Data(contentsOf: updaterURL, options: .mappedIfSafe)
            guard updaterData.count <= 128 * 1024,
                  let updaterText = String(data: updaterData, encoding: .utf8),
                  updaterText.hasPrefix("#!/usr/bin/env bash"),
                  updaterText.contains("DESKPET_STANDALONE_UPDATER=1") else {
                throw UpdateError.updaterInvalid
            }

            let logDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/DeskPet", isDirectory: true)
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            let logURL = logDirectory.appendingPathComponent("update.log")
            if !FileManager.default.fileExists(atPath: logURL.path) {
                _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.seekToEnd()
            if let header = "\n=== DeskPet update started \(Date().formatted(.iso8601)) ===\n".data(using: .utf8) {
                try logHandle.write(contentsOf: header)
            }

            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                updaterURL.path,
                "--destination", Bundle.main.bundlePath,
                "--wait-pid", String(ProcessInfo.processInfo.processIdentifier),
            ]
            var environment = ProcessInfo.processInfo.environment
            environment["DESKPET_PROGRESS_PROTOCOL"] = "1"
            environment["DESKPET_PROGRESS_LOG"] = logURL.path
            process.environment = environment
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] outputHandle in
                let data = outputHandle.availableData
                guard !data.isEmpty else { return }
                try? logHandle.write(contentsOf: data)
                Task { @MainActor [weak self] in
                    self?.consumeUpdaterOutput(data)
                }
            }
            process.terminationHandler = { [weak self] finishedProcess in
                Task { @MainActor [weak self] in
                    self?.handleUpdaterTermination(status: finishedProcess.terminationStatus)
                }
            }

            installProgress = 0.02
            installStage = "正在啟動更新器"
            isInstalling = true
            hasRequestedTerminationForUpdate = false
            statusMessage = "更新已開始；下載與建置期間請保持 DeskPet 開啟。"
            updateOutputBuffer.removeAll(keepingCapacity: true)
            updateOutputPipe = outputPipe
            updateLogHandle = logHandle
            try process.run()
            updateProcess = process
        } catch {
            cleanUpUpdaterHandles()
            resetInstallProgress()
            statusMessage = "無法啟動更新：\(error.localizedDescription)"
        }
    }

    private func consumeUpdaterOutput(_ data: Data) {
        updateOutputBuffer.append(data)
        while let newlineIndex = updateOutputBuffer.firstIndex(of: 0x0A) {
            let lineData = Data(updateOutputBuffer[..<newlineIndex])
            updateOutputBuffer.removeSubrange(...newlineIndex)
            applyProgressLine(String(decoding: lineData, as: UTF8.self))
        }
        if updateOutputBuffer.count > 16 * 1024 {
            updateOutputBuffer.removeAll(keepingCapacity: true)
        }
    }

    private func applyProgressLine(_ line: String) {
        let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0] == "DESKPET_PROGRESS",
              let percent = Double(parts[1]),
              (0...100).contains(percent) else { return }
        let stage = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stage.isEmpty, stage.count <= 120 else { return }

        installProgress = max(installProgress, percent / 100)
        installStage = stage
        statusMessage = "更新進度 \(installPercentage)%：\(stage)"

        guard percent >= 88,
              stage.contains("準備替換"),
              !hasRequestedTerminationForUpdate else { return }

        hasRequestedTerminationForUpdate = true
        installStage = "準備重新啟動"
        statusMessage = "新版已建置完成；DeskPet 將先關閉，更新器確認舊程序結束後才啟動新版。"

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            NSApp.terminate(nil)
        }
    }

    private func handleUpdaterTermination(status: Int32) {
        cleanUpUpdaterHandles()
        if status == 0 {
            installProgress = 1
            installStage = "更新完成"
            isInstalling = false
            statusMessage = "更新完成；若 DeskPet 未自動重新開啟，請手動啟動 App。"
        } else {
            isInstalling = false
            installStage = "更新失敗"
            statusMessage = "更新失敗（exit \(status)）；原版本已保留。請查看 ~/Library/Logs/DeskPet/update.log。"
        }
    }

    private func cleanUpUpdaterHandles() {
        updateOutputPipe?.fileHandleForReading.readabilityHandler = nil
        try? updateLogHandle?.close()
        updateProcess = nil
        updateOutputPipe = nil
        updateLogHandle = nil
        updateOutputBuffer.removeAll(keepingCapacity: false)
    }

    private func resetInstallProgress() {
        isInstalling = false
        installProgress = 0
        installStage = ""
        hasRequestedTerminationForUpdate = false
    }

    private static func isValidVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber) && Int(part) != nil
        }
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }
        return .orderedSame
    }
}
