import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let actionService: CalendarActionService
    private let viewModel: SettingsViewModel

    init(
        hotKeyService: GlobalHotKeyService,
        aiConfiguration: AIConfigurationStore,
        actionService: CalendarActionService,
        gasConfiguration: GASTaskConfigurationStore,
        gasConnector: GASTaskConnector,
        ambientMonitor: GASTaskAmbientMonitor,
        dailyPreferences: DailyUsePreferencesStore,
        launchAtLogin: LaunchAtLoginService,
        softwareUpdate: SoftwareUpdateService,
        diagnostics: SelfDiagnosticsService
    ) {
        self.actionService = actionService

        let viewModel = SettingsViewModel(
            hotKeyService: hotKeyService,
            aiConfiguration: aiConfiguration,
            actionService: actionService,
            gasConfiguration: gasConfiguration,
            gasConnector: gasConnector,
            ambientMonitor: ambientMonitor,
            dailyPreferences: dailyPreferences,
            launchAtLogin: launchAtLogin,
            softwareUpdate: softwareUpdate,
            diagnostics: diagnostics
        )
        self.viewModel = viewModel

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "DeskPet 設定"
        window.minSize = NSSize(width: 700, height: 650)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(model: viewModel))

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showSettings(section: SettingsViewModel.Section = .general) {
        actionService.refreshAuthorizationStatus()
        viewModel.showSection(section)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func showDiagnostics() {
        showSettings(section: .diagnostics)
    }
}
