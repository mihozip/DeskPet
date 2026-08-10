import AppKit
import SwiftUI

@MainActor
final class NaturalTaskCommandWindowController: NSWindowController, NSWindowDelegate {
    private let monitor: GASTaskAmbientMonitor
    private let connector: GASTaskConnector
    private let aiConfiguration: AIConfigurationStore
    private let onOpenInteraction: (GASTaskDigest.Task, GASTaskMutationKind, String, Date?, String?) -> Void
    private var voiceService: VoiceCommandService?

    init(
        monitor: GASTaskAmbientMonitor,
        connector: GASTaskConnector,
        aiConfiguration: AIConfigurationStore,
        onOpenInteraction: @escaping (GASTaskDigest.Task, GASTaskMutationKind, String, Date?, String?) -> Void
    ) {
        self.monitor = monitor
        self.connector = connector
        self.aiConfiguration = aiConfiguration
        self.onOpenInteraction = onOpenInteraction
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showCommandWindow(autoStartVoice: Bool = false) {
        voiceService?.reset()
        let voiceContext = (monitor.digest?.tasks ?? []).flatMap { task in
            [task.name, task.category ?? "", task.waitingFor ?? "", task.nextAction ?? ""]
        }
        let voiceService = VoiceCommandService(contextualStrings: voiceContext)
        self.voiceService = voiceService

        let model = NaturalTaskCommandViewModel(
            monitor: monitor,
            connector: connector,
            aiConfiguration: aiConfiguration,
            onOpenInteraction: onOpenInteraction
        )
        let rootView = NaturalTaskCommandView(model: model, voiceService: voiceService)

        let window: NSWindow
        if let existing = self.window {
            window = existing
            window.contentView = NSHostingView(rootView: rootView)
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DeskPet 自然語句操作"
            window.minSize = NSSize(width: 700, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: rootView)
            window.delegate = self
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        if autoStartVoice {
            Task { @MainActor [weak voiceService] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                await voiceService?.startListening()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        voiceService?.reset()
    }
}
