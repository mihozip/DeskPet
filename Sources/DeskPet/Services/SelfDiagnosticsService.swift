import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SelfDiagnosticsService: ObservableObject {
    @Published private(set) var items: [DiagnosticItem] = []
    @Published private(set) var generatedAt = Date()

    private let hotKeyService: GlobalHotKeyService
    private let aiConfiguration: AIConfigurationStore
    private let actionService: CalendarActionService
    private let gasConfiguration: GASTaskConfigurationStore
    private let ambientMonitor: GASTaskAmbientMonitor
    private let launchAtLogin: LaunchAtLoginService
    private let workEventStore: WorkEventStore

    init(
        hotKeyService: GlobalHotKeyService,
        aiConfiguration: AIConfigurationStore,
        actionService: CalendarActionService,
        gasConfiguration: GASTaskConfigurationStore,
        ambientMonitor: GASTaskAmbientMonitor,
        launchAtLogin: LaunchAtLoginService,
        workEventStore: WorkEventStore
    ) {
        self.hotKeyService = hotKeyService
        self.aiConfiguration = aiConfiguration
        self.actionService = actionService
        self.gasConfiguration = gasConfiguration
        self.ambientMonitor = ambientMonitor
        self.launchAtLogin = launchAtLogin
        self.workEventStore = workEventStore
        refresh()
    }

    func refresh() {
        actionService.refreshAuthorizationStatus()
        launchAtLogin.refresh()

        var result: [DiagnosticItem] = []
        result.append(appItem())
        result.append(assetItem())
        result.append(updaterItem())
        result.append(inboxItem())
        result.append(workDiaryItem())
        result.append(hotKeyItem())
        result.append(aiItem())
        result.append(gasItem())
        result.append(ambientItem())
        result.append(calendarItem())
        result.append(remindersItem())
        result.append(microphoneItem())
        result.append(speechItem())
        result.append(launchItem())

        items = result
        generatedAt = Date()
    }

    var reportText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        var lines = [
            "DeskPet \(version) — Self Diagnostics",
            "Generated: \(Self.timestampFormatter.string(from: generatedAt))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "App path: \(Bundle.main.bundlePath)",
            ""
        ]

        for item in items {
            let marker: String
            switch item.level {
            case .ok: marker = "OK"
            case .warning: marker = "WARN"
            case .error: marker = "ERROR"
            }
            lines.append("[\(marker)] \(item.title): \(item.detail)")
        }
        return lines.joined(separator: "\n")
    }

    func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
    }

    private func appItem() -> DiagnosticItem {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return DiagnosticItem(id: "app", title: "App 版本", detail: "\(version) (\(build))", level: .ok)
    }

    private func assetItem() -> DiagnosticItem {
        let names = ["pet_idle.png", "pet_listening.png", "pet_success.png", "pet_sleep.png"]
        guard let resourceURL = Bundle.main.resourceURL else {
            return DiagnosticItem(id: "assets", title: "桌寵素材", detail: "Contents/Resources 不可用", level: .warning)
        }
        let missing = names.filter { !FileManager.default.fileExists(atPath: resourceURL.appendingPathComponent($0).path) }
        if missing.isEmpty {
            return DiagnosticItem(id: "assets", title: "桌寵素材", detail: "4/4 預設圖片可用", level: .ok)
        }
        return DiagnosticItem(id: "assets", title: "桌寵素材", detail: "預設素材缺漏，使用 fallback：\(missing.joined(separator: ", "))", level: .warning)
    }

    private func updaterItem() -> DiagnosticItem {
        let updater = Bundle.main.url(forResource: "DeskPetUpdater", withExtension: "sh")
        let version = Bundle.main.url(forResource: "VERSION", withExtension: nil)
        if updater != nil, version != nil {
            return DiagnosticItem(id: "updater", title: "軟體更新", detail: "更新程式與 VERSION 已包含於 App bundle", level: .ok)
        }
        return DiagnosticItem(id: "updater", title: "軟體更新", detail: "此安裝版本未包含內建更新程式；請使用 README 的舊版更新指令", level: .warning)
    }

    private func inboxItem() -> DiagnosticItem {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let url = base?.appendingPathComponent("DeskPet/inbox.json")
        let detail = url?.path ?? "找不到 Application Support"
        let parentWritable: Bool
        if let parent = url?.deletingLastPathComponent() {
            parentWritable = FileManager.default.isWritableFile(atPath: parent.path) || !FileManager.default.fileExists(atPath: parent.path)
        } else {
            parentWritable = false
        }
        return DiagnosticItem(id: "inbox", title: "Inbox 儲存", detail: detail, level: parentWritable ? .ok : .warning)
    }

    private func workDiaryItem() -> DiagnosticItem {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let url = base?.appendingPathComponent("DeskPet/work-events.json")
        let todayCount = workEventStore.events(on: Date()).count
        let detail = "今日 \(todayCount) 筆事件；\(url?.path ?? "找不到 Application Support")"
        return DiagnosticItem(id: "diary", title: "Work Diary", detail: detail, level: .ok)
    }

    private func hotKeyItem() -> DiagnosticItem {
        DiagnosticItem(
            id: "hotkey",
            title: "快速記事快捷鍵",
            detail: hotKeyService.statusMessage,
            level: hotKeyService.isRegistered ? .ok : .warning
        )
    }

    private func aiItem() -> DiagnosticItem {
        if !aiConfiguration.isEnabled {
            return DiagnosticItem(id: "ai", title: "Gemini AI", detail: "未啟用；本機解析仍可使用", level: .warning)
        }
        if !aiConfiguration.hasAPIKey {
            return DiagnosticItem(id: "ai", title: "Gemini AI", detail: "已啟用但 Keychain 中沒有 API Key", level: .warning)
        }
        return DiagnosticItem(id: "ai", title: "Gemini AI", detail: "已啟用；模型：\(aiConfiguration.modelID)；API Key 已存在 Keychain", level: .ok)
    }

    private func gasItem() -> DiagnosticItem {
        if !gasConfiguration.isEnabled {
            return DiagnosticItem(id: "gas", title: "校務任務系統", detail: "未啟用", level: .warning)
        }
        let endpointOK = gasConfiguration.endpointURL != nil
        let tokenOK = gasConfiguration.hasAPIToken
        if endpointOK && tokenOK {
            return DiagnosticItem(id: "gas", title: "校務任務系統", detail: "Gateway URL 與 Token 已設定", level: .ok)
        }
        return DiagnosticItem(id: "gas", title: "校務任務系統", detail: "Gateway URL 或 Token 尚未完整設定", level: .warning)
    }

    private func ambientItem() -> DiagnosticItem {
        DiagnosticItem(
            id: "ambient",
            title: "Ambient Agent",
            detail: ambientMonitor.statusMessage,
            level: ambientMonitor.isMonitoring ? .ok : .warning
        )
    }

    private func calendarItem() -> DiagnosticItem {
        let text = actionService.calendarStatusText
        let ok = text.contains("已") && !text.contains("拒絕") && !text.contains("尚未")
        return DiagnosticItem(id: "calendar", title: "Calendar", detail: text, level: ok ? .ok : .warning)
    }

    private func remindersItem() -> DiagnosticItem {
        let text = actionService.remindersStatusText
        let ok = text.contains("已") && !text.contains("拒絕") && !text.contains("尚未")
        return DiagnosticItem(id: "reminders", title: "Reminders", detail: text, level: ok ? .ok : .warning)
    }

    private func microphoneItem() -> DiagnosticItem {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return DiagnosticItem(id: "microphone", title: "麥克風", detail: "已授權", level: .ok)
        case .notDetermined:
            return DiagnosticItem(id: "microphone", title: "麥克風", detail: "尚未要求權限", level: .warning)
        case .denied, .restricted:
            return DiagnosticItem(id: "microphone", title: "麥克風", detail: "未授權", level: .warning)
        @unknown default:
            return DiagnosticItem(id: "microphone", title: "麥克風", detail: "權限狀態未知", level: .warning)
        }
    }

    private func speechItem() -> DiagnosticItem {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return DiagnosticItem(id: "speech", title: "語音辨識", detail: "已授權", level: .ok)
        case .notDetermined:
            return DiagnosticItem(id: "speech", title: "語音辨識", detail: "尚未要求權限", level: .warning)
        case .denied, .restricted:
            return DiagnosticItem(id: "speech", title: "語音辨識", detail: "未授權", level: .warning)
        @unknown default:
            return DiagnosticItem(id: "speech", title: "語音辨識", detail: "權限狀態未知", level: .warning)
        }
    }

    private func launchItem() -> DiagnosticItem {
        DiagnosticItem(
            id: "launch",
            title: "登入後啟動",
            detail: launchAtLogin.statusMessage,
            level: launchAtLogin.isEnabled ? .ok : .warning
        )
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
