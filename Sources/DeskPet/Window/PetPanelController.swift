import AppKit
import SwiftUI

@MainActor
final class PetPanelController: NSWindowController {
    private enum PositionKey {
        static let x = "DeskPet.window.x"
        static let y = "DeskPet.window.y"
    }

    private let model: PetViewModel
    private var previousFrontmostApplication: NSRunningApplication?
    private var dragStartOrigin: NSPoint?

    init(
        store: CaptureStore,
        ambientMonitor: GASTaskAmbientMonitor,
        dailyPreferences: DailyUsePreferencesStore,
        gasConfiguration: GASTaskConfigurationStore,
        onOpenInbox: @escaping () -> Void,
        onOpenTaskDigest: @escaping () -> Void,
        onOpenDiary: @escaping () -> Void,
        onOpenNaturalAction: @escaping () -> Void,
        onOpenVoiceAction: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenDiagnostics: @escaping () -> Void,
        shortcutLabel: @escaping () -> String
    ) {
        let model = PetViewModel(store: store)
        self.model = model

        let panel = PetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        super.init(window: panel)

        model.requestInputFocus = { [weak self] in
            self?.activateForInput()
        }

        model.requestFocusRestore = { [weak self] in
            self?.restorePreviousApplication()
        }

        let rootView = PetRootView(
            model: model,
            ambientMonitor: ambientMonitor,
            dailyPreferences: dailyPreferences,
            gasConfiguration: gasConfiguration,
            onOpenInbox: onOpenInbox,
            onOpenTaskDigest: onOpenTaskDigest,
            onOpenDiary: onOpenDiary,
            onOpenNaturalAction: onOpenNaturalAction,
            onOpenVoiceAction: onOpenVoiceAction,
            onOpenSettings: onOpenSettings,
            onOpenDiagnostics: onOpenDiagnostics,
            shortcutLabel: shortcutLabel,
            onDragChanged: { [weak self] translation in
                self?.movePanel(translation: translation)
            },
            onDragEnded: { [weak self] in
                self?.finishDragging()
            }
        )

        panel.contentView = NSHostingView(rootView: rootView)
        restorePosition()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func showCapture() {
        show()
        model.beginCapture()
    }

    func persistCurrentPosition() {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set(origin.x, forKey: PositionKey.x)
        UserDefaults.standard.set(origin.y, forKey: PositionKey.y)
    }

    private func activateForInput() {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousFrontmostApplication = NSWorkspace.shared.frontmostApplication
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func restorePreviousApplication() {
        window?.resignKey()

        guard let previous = previousFrontmostApplication,
              previous.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            previousFrontmostApplication = nil
            return
        }

        previous.activate(options: [.activateIgnoringOtherApps])
        previousFrontmostApplication = nil
    }

    private func movePanel(translation: CGSize) {
        guard let window else { return }

        if dragStartOrigin == nil {
            dragStartOrigin = window.frame.origin
        }

        guard let start = dragStartOrigin else { return }

        let newOrigin = NSPoint(
            x: start.x + translation.width,
            y: start.y - translation.height
        )
        window.setFrameOrigin(newOrigin)
    }

    private func finishDragging() {
        dragStartOrigin = nil
        persistCurrentPosition()
    }

    private func restorePosition() {
        guard let window else { return }

        let defaults = UserDefaults.standard
        let hasSavedPosition = defaults.object(forKey: PositionKey.x) != nil
            && defaults.object(forKey: PositionKey.y) != nil

        if hasSavedPosition {
            let saved = NSPoint(
                x: defaults.double(forKey: PositionKey.x),
                y: defaults.double(forKey: PositionKey.y)
            )

            if isVisibleOnAnyScreen(origin: saved, size: window.frame.size) {
                window.setFrameOrigin(saved)
                return
            }
        }

        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - window.frame.width - 24,
            y: visible.minY + 24
        )
        window.setFrameOrigin(origin)
    }

    private func isVisibleOnAnyScreen(origin: NSPoint, size: NSSize) -> Bool {
        let candidate = NSRect(origin: origin, size: size)
        return NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(candidate)
        }
    }
}
