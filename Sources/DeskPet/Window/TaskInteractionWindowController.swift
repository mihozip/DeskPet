import AppKit
import SwiftUI

@MainActor
final class TaskInteractionWindowController: NSWindowController, NSWindowDelegate {
    private let connector: GASTaskConnector
    private let monitor: GASTaskAmbientMonitor
    private let workEventStore: WorkEventStore

    init(connector: GASTaskConnector, monitor: GASTaskAmbientMonitor, workEventStore: WorkEventStore) {
        self.connector = connector
        self.monitor = monitor
        self.workEventStore = workEventStore
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(
        task: GASTaskDigest.Task,
        preselectedAction: GASTaskMutationKind? = nil,
        prefilledNote: String? = nil,
        prefilledDueDate: Date? = nil
    ) {
        let model = TaskInteractionViewModel(
            task: task,
            connector: connector,
            workEventStore: workEventStore,
            preselectedAction: preselectedAction,
            prefilledNote: prefilledNote,
            prefilledDueDate: prefilledDueDate,
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
            window.title = "DeskPet 任務操作"
            window.minSize = NSSize(width: 590, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: TaskInteractionView(model: model))
            window.delegate = self
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
