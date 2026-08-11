import AppKit
import Combine
import SwiftUI

@MainActor
final class TaskDigestWindowController: NSWindowController, NSWindowDelegate {
    private let monitor: GASTaskAmbientMonitor
    private let gasConfiguration: GASTaskConfigurationStore
    private let onOpenTask: (GASTaskDigest.Task) -> Void
    private let viewState = DailyWorkViewState()
    private var administrativeTitleCancellable: AnyCancellable?

    init(
        monitor: GASTaskAmbientMonitor,
        gasConfiguration: GASTaskConfigurationStore,
        captureStore: CaptureStore,
        workEventStore: WorkEventStore,
        snoozeStore: SnoozeStore,
        onOpenTaskAction: @escaping (GASTaskDigest.Task, GASTaskMutationKind) -> Void,
        onOpenTask: @escaping (GASTaskDigest.Task) -> Void
    ) {
        self.monitor = monitor
        self.gasConfiguration = gasConfiguration
        self.onOpenTask = onOpenTask

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskPet 今日工作"
        window.minSize = NSSize(width: 760, height: 580)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: TaskDigestView(
                monitor: monitor,
                gasConfiguration: gasConfiguration,
                captureStore: captureStore,
                workEventStore: workEventStore,
                snoozeStore: snoozeStore,
                viewState: viewState,
                onOpenTask: onOpenTask,
                onOpenTaskAction: onOpenTaskAction
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
            window?.title = "DeskPet \(title)今日工作"
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDigest() {
        window?.title = "DeskPet \(gasConfiguration.administrativeTitle)今日工作"
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        Task { await monitor.refresh(manual: false) }
    }
}
