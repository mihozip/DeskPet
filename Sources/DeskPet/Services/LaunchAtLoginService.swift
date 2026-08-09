import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var statusMessage = "正在讀取登入啟動狀態…"

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        statusMessage = Self.message(for: status)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            statusMessage = "登入啟動設定失敗：\(error.localizedDescription)"
        }
    }

    private static func message(for status: SMAppService.Status) -> String {
        switch status {
        case .enabled:
            return "已設定為登入後自動啟動"
        case .requiresApproval:
            return "需要到「系統設定 → 一般 → 登入項目」核准 DeskPet"
        case .notRegistered:
            return "尚未設定登入後自動啟動"
        case .notFound:
            return "macOS 找不到可註冊的 DeskPet App；正式使用時建議把 App 放在「應用程式」資料夾"
        @unknown default:
            return "登入啟動狀態未知"
        }
    }
}
