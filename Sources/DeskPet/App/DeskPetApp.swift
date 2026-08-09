import AppKit

/// DeskPet uses an AppKit-owned application lifecycle so the app can stay
/// windowless at launch. SwiftUI is still used inside NSHostingView for the
/// pet, Inbox, and Settings content, but there is no SwiftUI Settings scene
/// that can create an unwanted blank window.
@main
@MainActor
struct DeskPetMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
