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

    let currentVersion: String

    private static let versionURL = URL(string: "https://raw.githubusercontent.com/mihozip/DeskPet/main/VERSION")!
    private static let lastAutomaticCheckKey = "DeskPet.softwareUpdate.lastAutomaticCheck.v1"
    private let session: URLSession
    private var updateProcess: Process?
    private var updateLogHandle: FileHandle?

    init(session: URLSession = .shared) {
        self.session = session
        currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0.0"
    }

    var canInstall: Bool {
        availableVersion != nil && !isChecking && !isInstalling
    }

    func checkIfDue() {
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastAutomaticCheckKey) as? Date
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 86_400 { return }
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
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.seekToEnd()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                updaterURL.path,
                "--destination", Bundle.main.bundlePath,
                "--wait-pid", String(ProcessInfo.processInfo.processIdentifier),
            ]
            process.standardOutput = logHandle
            process.standardError = logHandle
            try process.run()
            updateProcess = process
            updateLogHandle = logHandle

            isInstalling = true
            statusMessage = "更新程式已啟動；DeskPet 即將關閉，完成後會自動重新開啟。"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSApp.terminate(nil)
            }
        } catch {
            isInstalling = false
            statusMessage = "無法啟動更新：\(error.localizedDescription)"
        }
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
