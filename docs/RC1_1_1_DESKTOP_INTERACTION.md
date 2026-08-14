# DeskPet RC1.1.1 — Desktop Interaction Fix

RC1.1.1 is a compatibility patch for cases where DeskPet launches and renders the white pet correctly, but the pet behaves like a non-interactive floating PNG: left click, right click/context menu, and the quick-capture hotkey do not respond.

## Fixed

- Replaced the desktop pet's `.nonactivatingPanel` window style with a normal borderless floating `NSPanel` so modern macOS releases can deliver mouse events reliably.
- Added a dedicated `NSHostingView` that accepts the first mouse click even when DeskPet is not the foreground application.
- Added an explicit non-zero-opacity hit target behind the SwiftUI pet surface and kept tap, drag, and context-menu gestures on that surface.
- Bound the Carbon global hotkey handler to `GetApplicationEventTarget()` rather than the process-wide dispatcher target.
- Quick capture now explicitly activates and keys the pet window before entering text-input state.
- Added a persistent menu-bar fallback with Quick Capture, Inbox, Today Work, Calendar Intelligence, Settings, and Quit. This keeps DeskPet operable even if a future macOS release regresses floating-window hit testing again.

## Compatibility / Safety

- No Inbox, WorkEvent, Snooze, GAS Dashboard, Calendar, or Reminders data format changed.
- No autonomous write behavior was added; existing human-confirmation boundaries remain unchanged.
- The release remains an RC build using ad-hoc signing unless a Developer ID identity is supplied by the release environment.

## Validation

- Added a desktop-interaction contract test that prevents `.nonactivatingPanel` from returning and verifies the first-mouse view, explicit pet hit target, application hotkey target, and menu-bar fallback remain wired.
- Normal Swift unit tests, public-repository checks, app bundle build, resource verification, and release codesign verification continue to run in GitHub Actions.
