import AppKit
import Combine

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let gasConfiguration: GASTaskConfigurationStore
    private let onQuickCapture: () -> Void
    private let onOpenInbox: () -> Void
    private let onOpenTaskDigest: () -> Void
    private let onOpenCalendarQuery: () -> Void
    private let onOpenSettings: () -> Void
    private var gasConfigurationCancellable: AnyCancellable?

    init(
        gasConfiguration: GASTaskConfigurationStore,
        onQuickCapture: @escaping () -> Void,
        onOpenInbox: @escaping () -> Void,
        onOpenTaskDigest: @escaping () -> Void,
        onOpenCalendarQuery: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.gasConfiguration = gasConfiguration
        self.onQuickCapture = onQuickCapture
        self.onOpenInbox = onOpenInbox
        self.onOpenTaskDigest = onOpenTaskDigest
        self.onOpenCalendarQuery = onOpenCalendarQuery
        self.onOpenSettings = onOpenSettings
        super.init()
        configureStatusItem()

        gasConfigurationCancellable = gasConfiguration.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.configureStatusItem()
            }
        }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "DeskPet 白帥帥")
            button.toolTip = "DeskPet 白帥帥"
        }

        let menu = NSMenu()
        menu.addItem(makeItem(title: "快速記事", action: #selector(quickCapture)))

        let workItem = NSMenuItem(title: "工作", action: nil, keyEquivalent: "")
        let workMenu = NSMenu(title: "工作")
        workMenu.addItem(makeItem(title: "開啟 Inbox", action: #selector(openInbox)))
        if gasConfiguration.isLinked {
            workMenu.addItem(makeItem(title: "今日工作", action: #selector(openTaskDigest)))
        }
        workItem.submenu = workMenu
        menu.addItem(workItem)

        let queryItem = NSMenuItem(title: "查詢", action: nil, keyEquivalent: "")
        let queryMenu = NSMenu(title: "查詢")
        queryMenu.addItem(makeItem(title: "查詢行事曆…", action: #selector(openCalendarQuery)))
        queryItem.submenu = queryMenu
        menu.addItem(queryItem)

        let toolsItem = NSMenuItem(title: "工具", action: nil, keyEquivalent: "")
        let toolsMenu = NSMenu(title: "工具")
        toolsMenu.addItem(makeItem(title: "清理垃圾桶…", action: #selector(emptyTrash)))
        toolsMenu.addItem(.separator())
        toolsMenu.addItem(makeItem(title: "設定…", action: #selector(openSettings)))
        toolsItem.submenu = toolsMenu
        menu.addItem(toolsItem)

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
        guard gasConfiguration.isLinked else { return }
        onOpenTaskDigest()
    }

    @objc private func openCalendarQuery() {
        onOpenCalendarQuery()
    }

    @objc private func emptyTrash() {
        TrashService.confirmAndEmptyTrash()
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
