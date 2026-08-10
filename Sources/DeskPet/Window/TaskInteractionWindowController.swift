import AppKit
import Combine
import SwiftUI

@MainActor
final class TaskInteractionWindowController: NSWindowController, NSWindowDelegate {
    private let connector: GASTaskConnector
    private let gasConfiguration: GASTaskConfigurationStore
    private let monitor: GASTaskAmbientMonitor
    private let workEventStore: WorkEventStore
    private var administrativeTitleCancellable: AnyCancellable?

    init(
        connector: GASTaskConnector,
        gasConfiguration: GASTaskConfigurationStore,
        monitor: GASTaskAmbientMonitor,
        workEventStore: WorkEventStore
    ) {
        self.connector = connector
        self.gasConfiguration = gasConfiguration
        self.monitor = monitor
        self.workEventStore = workEventStore
        super.init(window: nil)
        administrativeTitleCancellable = Publishers.CombineLatest(
            gasConfiguration.$administrativeTitleOverride,
            gasConfiguration.$integrationMetadata
        ).sink { [weak self] localOverride, metadata in
            let title = GASTaskConfigurationStore.resolveAdministrativeTitle(
                override: localOverride,
                dashboardTitle: metadata?.roleName
            )
            self?.window?.title = "DeskPet \(title)任務操作"
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(
        task: GASTaskDigest.Task,
        preselectedAction: GASTaskMutationKind? = nil,
        prefilledNote: String? = nil,
        prefilledDueDate: Date? = nil,
        prefilledNextAction: String? = nil
    ) {
        let model = TaskInteractionViewModel(
            task: task,
            connector: connector,
            gasConfiguration: gasConfiguration,
            workEventStore: workEventStore,
            preselectedAction: preselectedAction,
            prefilledNote: prefilledNote,
            prefilledDueDate: prefilledDueDate,
            prefilledNextAction: prefilledNextAction,
            onUpdated: { [weak self] in
                await self?.monitor.refresh(manual: false)
            }
        )

        let window: NSWindow
        if let existing = self.window {
            window = existing
            window.contentView = NSHostingView(rootView: TaskInteractionView(model: model))
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 650, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DeskPet \(gasConfiguration.taskActionTitle)"
            window.minSize = NSSize(width: 590, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: TaskInteractionView(model: model))
            window.delegate = self
            self.window = window
        }

        window.title = "DeskPet \(gasConfiguration.taskActionTitle)"

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
