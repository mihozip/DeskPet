import AppKit
import Combine
import SwiftUI

@MainActor
final class TaskDigestWindowController: NSWindowController, NSWindowDelegate {
    private let monitor: GASTaskAmbientMonitor
    private let gasConfiguration: GASTaskConfigurationStore
    private let onOpenTask: (GASTaskDigest.Task) -> Void
    private var administrativeTitleCancellable: AnyCancellable?

    init(
        monitor: GASTaskAmbientMonitor,
        gasConfiguration: GASTaskConfigurationStore,
        onOpenTask: @escaping (GASTaskDigest.Task) -> Void
    ) {
        self.monitor = monitor
        self.gasConfiguration = gasConfiguration
        self.onOpenTask = onOpenTask

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskPet \(gasConfiguration.taskDigestTitle)"
        window.minSize = NSSize(width: 660, height: 500)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: TaskDigestView(
                monitor: monitor,
                gasConfiguration: gasConfiguration,
                onOpenTask: onOpenTask
            )
        )

        super.init(window: window)
        window.delegate = self
        administrativeTitleCancellable = Publishers.CombineLatest(
            gasConfiguration.$administrativeTitleOverride,
            gasConfiguration.$integrationMetadata
        ).sink { [weak window] localOverride, metadata in
            let title = GASTaskConfigurationStore.resolveAdministrativeTitle(
                override: localOverride,
                dashboardTitle: metadata?.roleName
            )
            window?.title = "DeskPet \(title)工作摘要"
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDigest() {
        window?.title = "DeskPet \(gasConfiguration.taskDigestTitle)"
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        Task { await monitor.refresh(manual: false) }
    }
}
