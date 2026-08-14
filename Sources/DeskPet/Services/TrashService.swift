import AppKit
import Foundation

@MainActor
enum TrashService {
    static func confirmAndEmptyTrash() {
        let alert = NSAlert()
        alert.messageText = "清理垃圾桶？"
        alert.informativeText = "垃圾桶內的項目會被永久刪除，無法復原。第一次使用時，macOS 可能會詢問是否允許 DeskPet 控制 Finder。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清理垃圾桶")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: "tell application \"Finder\" to empty trash")
        let result = script?.executeAndReturnError(&errorInfo)

        if result == nil {
            let errorAlert = NSAlert()
            errorAlert.messageText = "無法清理垃圾桶"
            if let errorInfo,
               let message = errorInfo[NSAppleScript.errorMessage] as? String,
               !message.isEmpty {
                errorAlert.informativeText = message
            } else {
                errorAlert.informativeText = "請確認 DeskPet 已獲准控制 Finder，再重試。"
            }
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: "好")
            errorAlert.runModal()
            return
        }

        let successAlert = NSAlert()
        successAlert.messageText = "垃圾桶已清理"
        successAlert.informativeText = "Finder 垃圾桶中的項目已永久刪除。"
        successAlert.addButton(withTitle: "好")
        successAlert.runModal()
    }
}
