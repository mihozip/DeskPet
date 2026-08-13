import AppKit
import SwiftUI

@MainActor
final class CalendarQueryWindowController: NSWindowController, NSWindowDelegate {
    private let service: CalendarQueryService

    init(service: CalendarQueryService) {
        self.service = service
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showCalendarQuery() {
        let model = CalendarQueryViewModel(service: service)
        let rootView = CalendarQueryView(model: model)

        let window: NSWindow
        if let existing = self.window {
            window = existing
            window.contentView = NSHostingView(rootView: rootView)
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DeskPet 行事曆智慧查詢"
            window.minSize = NSSize(width: 720, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: rootView)
            window.delegate = self
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
