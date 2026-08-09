import AppKit
import SwiftUI

@MainActor
final class WorkDiaryWindowController: NSWindowController, NSWindowDelegate {
    private let store: WorkEventStore

    init(store: WorkEventStore) {
        self.store = store
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDiary() {
        let model = WorkDiaryViewModel(store: store)
        let rootView = WorkDiaryView(model: model)

        let window: NSWindow
        if let existing = self.window {
            window = existing
            window.contentView = NSHostingView(rootView: rootView)
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DeskPet 每日工作日誌"
            window.minSize = NSSize(width: 720, height: 620)
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: rootView)
            window.delegate = self
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
