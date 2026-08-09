import AppKit
import SwiftUI

@MainActor
final class InboxWindowController: NSWindowController, NSWindowDelegate {
    init(
        store: CaptureStore,
        onReview: @escaping (UUID) -> Void,
        onOpenLinkedTask: @escaping (String) -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "DeskPet Inbox"
        window.minSize = NSSize(width: 660, height: 460)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: InboxView(
                store: store,
                onReview: onReview,
                onOpenLinkedTask: onOpenLinkedTask
            )
        )

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showInbox() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
