import AppKit
import SwiftUI

@MainActor
final class TaskDigestWindowController: NSWindowController, NSWindowDelegate {
    private let monitor: GASTaskAmbientMonitor
    private let onOpenTask: (GASTaskDigest.Task) -> Void

    init(monitor: GASTaskAmbientMonitor, onOpenTask: @escaping (GASTaskDigest.Task) -> Void) {
        self.monitor = monitor
        self.onOpenTask = onOpenTask

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskPet 總務摘要"
        window.minSize = NSSize(width: 660, height: 500)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: TaskDigestView(monitor: monitor, onOpenTask: onOpenTask))

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDigest() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        Task { await monitor.refresh(manual: false) }
    }
}
