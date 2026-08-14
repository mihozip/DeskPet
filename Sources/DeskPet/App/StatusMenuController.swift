import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let onQuickCapture: () -> Void
    private let onOpenInbox: () -> Void
    private let onOpenTaskDigest: () -> Void
    private let onOpenCalendarQuery: () -> Void
    private let onOpenSettings: () -> Void

    init(
        onQuickCapture: @escaping () -> Void,
        onOpenInbox: @escaping () -> Void,
        onOpenTaskDigest: @escaping () -> Void,
        onOpenCalendarQuery: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onQuickCapture = onQuickCapture
        self.onOpenInbox = onOpenInbox
        self.onOpenTaskDigest = onOpenTaskDigest
        self.onOpenCalendarQuery = onOpenCalendarQuery
        self.onOpenSettings = onOpenSettings
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "DeskPet 白帥帥")
            button.toolTip = "DeskPet 白帥帥"
        }

        let menu = NSMenu()
        menu.addItem(makeItem(title: "快速記事", action: #selector(quickCapture)))
        menu.addItem(makeItem(title: "開啟 Inbox", action: #selector(openInbox)))
        menu.addItem(makeItem(title: "今日工作", action: #selector(openTaskDigest)))
        menu.addItem(makeItem(title: "查詢行事曆…", action: #selector(openCalendarQuery)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "設定…", action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "退出 DeskPet", action: #selector(quit)))
        statusItem.menu = menu
    }

    private func makeItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func quickCapture() {
        onQuickCapture()
    }

    @objc private func openInbox() {
        onOpenInbox()
    }

    @objc private func openTaskDigest() {
        onOpenTaskDigest()
    }

    @objc private func openCalendarQuery() {
        onOpenCalendarQuery()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
