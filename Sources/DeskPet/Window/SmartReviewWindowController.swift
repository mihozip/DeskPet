import AppKit
import SwiftUI

@MainActor
final class SmartReviewWindowController: NSWindowController, NSWindowDelegate {
    private let store: CaptureStore
    private let localInterpreter: LocalIntentInterpreter
    private let aiInterpreter: GeminiIntentInterpreter
    private let aiConfiguration: AIConfigurationStore
    private let actionService: CalendarActionService
    private let gasConfiguration: GASTaskConfigurationStore
    private let gasConnector: GASTaskConnector
    private let workEventStore: WorkEventStore
    private let onOpenTask: (GASTaskDigest.Task) -> Void

    init(
        store: CaptureStore,
        localInterpreter: LocalIntentInterpreter,
        aiInterpreter: GeminiIntentInterpreter,
        aiConfiguration: AIConfigurationStore,
        actionService: CalendarActionService,
        gasConfiguration: GASTaskConfigurationStore,
        gasConnector: GASTaskConnector,
        workEventStore: WorkEventStore,
        onOpenTask: @escaping (GASTaskDigest.Task) -> Void
    ) {
        self.store = store
        self.localInterpreter = localInterpreter
        self.aiInterpreter = aiInterpreter
        self.aiConfiguration = aiConfiguration
        self.actionService = actionService
        self.gasConfiguration = gasConfiguration
        self.gasConnector = gasConnector
        self.workEventStore = workEventStore
        self.onOpenTask = onOpenTask

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskPet Smart Inbox"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showReview(itemID: UUID) {
        guard let item = store.item(id: itemID), let window else { return }

        let model = SmartReviewViewModel(
            item: item,
            store: store,
            localInterpreter: localInterpreter,
            aiInterpreter: aiInterpreter,
            aiConfiguration: aiConfiguration,
            actionService: actionService,
            gasConfiguration: gasConfiguration,
            gasConnector: gasConnector,
            workEventStore: workEventStore
        )

        window.contentView = NSHostingView(
            rootView: SmartReviewView(
                model: model,
                onSaveAndClose: { [weak self] in self?.close() },
                onClose: { [weak self] in self?.close() },
                onOpenTask: onOpenTask
            )
        )
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
