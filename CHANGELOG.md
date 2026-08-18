# Changelog

All notable changes to DeskPet are documented here. Release Candidate interfaces and stored-data formats may still evolve between RC milestones.

## [1.2.0.0] - 2026-08

Release Candidate 1.2 — Work Context / Now, Next, Later.

### Added
- Added deterministic `WorkContextEngine` derived from active GAS tasks, Inbox items, WorkEvents, Snooze state, and local Calendar events.
- Added `Now / Next / Later` context cards to the existing Today Work surface.
- Added a deterministic focus headline that can combine an upcoming Calendar event with the highest-ranked actionable task.
- Added a concrete interval-read API to `CalendarQueryService` so Work Context can reuse the local EventKit boundary without invoking natural-language parsing.
- Added Work Context unit tests covering task priority, waiting state, Calendar context, all-day events, Snooze, deduplication, and recent activity.
- Added `docs/RC1_2_WORK_CONTEXT.md` and updated the main architecture documentation.

### Behavior
- Waiting tasks are treated as blocked / deferred context even when task priority is high, so they do not incorrectly take over `Now`.
- Active non-all-day Calendar events can provide immediate context.
- All-day Calendar events remain visible without replacing the active-focus headline for the entire day.
- Calendar read failures degrade gracefully to GAS tasks, Inbox, WorkEvents, and Snooze context.
- Existing Today Brief, Waiting Radar, Daily Wrap, Weekly Review, task interaction, and human-confirmed mutation flows remain intact.

### Privacy / Safety
- Work Context does not create another persistent task or calendar database.
- Calendar event content remains local to EventKit and is not sent to Gemini.
- Work Context prioritization is deterministic and does not require Gemini.
- Calendar, Reminders, and GAS writes retain their existing human-confirmation boundaries.

### Documentation
- Main and English README now describe RC1.2 and the current mainline version.
- Architecture documentation now includes the Context layer and its ownership boundaries.
- Gemini model policy records the 2026-08-18 verification that no first-party Gemini API model ID for Gemini 3.7 Flash is yet available; DeskPet therefore does not guess `gemini-3.7-flash`.

## [1.1.3.4] - 2026-08

RC1.1.3.4 improves Gemini 3 structured-output reliability.

### Fixed
- Gemini response parsing now recognizes `thought` parts and combines only final-answer text before structured JSON decoding.
- DeskPet no longer assumes the first text part in `content.parts` is the final JSON answer.
- Structured output tolerates occasional Markdown JSON code fences before decoding.
- JSON decoding failures report more specific missing-field, type-mismatch, and corrupted-data diagnostics.
- `MAX_TOKENS` truncation now produces an explicit error instead of a generic format failure.

### Changed
- Smart Inbox and natural task extraction use Gemini 3 `thinkingLevel=minimal` because these paths are extraction / classification workloads.
- Structured-output token limits were increased to reduce JSON truncation risk.

### Validation
- Gemini model / response-parser contract.
- Swift tests.
- Public repository checks.
- Release app build and code-sign verification.

## [1.1.3.3] - 2026-08

RC1.1.3.3 refreshes DeskPet's Gemini picker to the current Gemini 3.5+ production lineup.

### Changed
- Removed all Gemini 2.x model options from Settings.
- Changed the default model from `gemini-2.5-flash` to `gemini-3.6-flash`.
- Added `gemini-3.5-flash` alongside the existing `gemini-3.6-flash` and `gemini-3.5-flash-lite` choices.
- Renamed the picker labels to make the recommended, quality-oriented and lower-cost choices clearer.

### Migration
- Existing users whose saved model points to Gemini 2.x or any model no longer present in the supported picker are migrated automatically to `gemini-3.6-flash`.
- DeskPet does not expose a speculative Gemini 3.7 model ID. It will be added only after Google publishes an official API model identifier.

### Validation
- Added a Gemini model contract to CI and Release checks so retired 2.x options or speculative model IDs are not accidentally reintroduced.

## [1.1.3.2] - 2026-08

RC1.1.3.2 rebuilds the Apple permission flow around EventKit's real authorization state and makes local signing more stable for macOS TCC.

### Fixed
- Calendar and Reminders permission UI now uses `EKEventStore.authorizationStatus(for:)` as the single source of truth instead of temporarily marking a request as granted before macOS reports the new state.
- Calendar and Reminders retain physically separate `EKEventStore` request paths, while denied permissions now route users to System Settings instead of repeatedly calling an API that macOS will not re-prompt.
- Calendar Intelligence no longer owns a second permission-request path. Queries require Settings to establish readable Calendar access first and create their `EKEventStore` only after access is confirmed.
- Calendar write-only access is distinguished from full event access, so DeskPet no longer presents a write-only grant as sufficient for Calendar Intelligence.
- Permission diagnostics now evaluate typed authorization state rather than inferring success from localized status strings.

### Changed
- Local debug/release builds and source-based in-app updates now prefer an available `Developer ID Application` identity, then `Apple Development`, and use ad-hoc signing only as a fallback.
- Self Diagnostics reports whether the running app uses a stable signing authority or an ad-hoc signature that may cause TCC permissions to be requested again after a rebuild or update.
- Calendar and Reminders usage descriptions were clarified to match the actual full-access behavior.

### Distribution note
- GitHub-hosted RC builds remain ad-hoc signed until a Developer ID certificate is configured in the release workflow. The application logic is now deterministic, but reliable TCC permission persistence across separately built public RC binaries ultimately requires a stable Apple signing identity.

## [1.1.3.1] - 2026-08

RC1.1.3.1 Calendar authorization and development-workflow stability update.

### Fixed
- The Calendar permission button now requests full event access on macOS 14+ because DeskPet includes Calendar Intelligence and must be able to read existing events as well as create new ones.
- Calendar and Reminders remain strictly separate EventKit authorization paths; requesting Calendar never invokes the Reminders permission API, and vice versa.
- EventKit stores are reset after a newly granted permission so stores created before authorization do not retain stale source state.
- Settings refreshes Calendar / Reminders authorization when the view appears and whenever DeskPet becomes active again, so permission state no longer depends on restarting the app.

### Changed
- Removed the experimental Trash cleanup command and its service implementation.
- CI no longer runs on every intermediate feature-branch push. Automatic CI is limited to `main` pushes and pull requests, with concurrency cancellation for superseded runs, reducing failure-notification noise during development.

### Safety
- Calendar, Reminders and GAS writes retain their existing human-confirmation boundaries.
- The release version remains `1.1.3.1`; this refresh replaces the RC asset and release notes rather than introducing another version number.

## [1.1.3.0] - 2026-08

Release Candidate 1.1.3 — Weekly Updates, Contextual GAS Menus and Non-Blocking Desktop Presence.

### Added
- Added automatic update checking with a seven-day network-check interval. While DeskPet remains open, a lightweight local due-check keeps the schedule current without repeatedly contacting GitHub.
- Added an update prompt that appears only when a newer version exists, with `立即更新` and `稍後` choices.

### Changed
- GAS task features now use a verified `isLinked` state: enabled integration, valid HTTPS endpoint, Keychain token, and successful Dashboard integration metadata are all required before task-related menu items appear.
- When the school task system is not linked, DeskPet keeps the integration setup only in Settings and hides task digest, natural task action, voice task action, immediate GAS sync, and related ambient task UI from desktop menus.
- The menu-bar fallback also hides GAS task digest entries until the integration is verified.
- DeskPet's pet panel now uses normal window level rather than a floating always-on-top level, allowing Word, browsers, Finder and other normal application windows to cover the pet during ordinary work.
- The global voice task shortcut is ignored while the school task system is not linked.

### Safety / UX
- Automatic update checks do not install anything without user confirmation.
- Choosing `稍後` does not cause repeated hourly prompts; the next network check remains gated by the seven-day interval.
- DeskPet can still bring itself forward explicitly for quick capture while no longer permanently covering normal work windows.

## [1.1.2.0] - 2026-08

Release Candidate 1.1.2 — Permission Isolation, Safe Update Handoff and Compact Menu.

### Changed
- Consolidated the white DeskPet context menu into compact top-level groups: Quick Capture, Work, Query & Input, Tools, Sleep/Wake and Quit.
- Consolidated the menu-bar fallback into Work, Query and Tools submenus instead of exposing every action at the top level.
- Calendar and Reminders authorization use separate `EKEventStore` instances and only refresh the entity that was requested.
- Settings serialize Apple permission requests so Calendar and Reminders authorization cannot be started concurrently.
- The in-app updater passes the current DeskPet PID to the updater. After the new build is ready, DeskPet terminates normally; the updater waits for that exact PID to disappear before replacing the bundle and launching one new instance.
- Standalone updater mode also waits until all existing DeskPet processes are gone before launching the replacement.

### Safety
- Calendar, Reminders and GAS write operations retain their existing human-confirmation boundaries.
- The updater preserves the existing rollback backup and code-sign verification flow.

## [1.1.1.1] - 2026-08

RC1.1.1 permission-status refresh patch.

### Fixed
- Calendar and Reminders permission rows now update immediately when the EventKit request API returns success instead of requiring an app restart.
- Added a delayed EventKit/TCC reconciliation pass so the displayed state catches up with the system authorization status without overwriting a confirmed grant with a transient `notDetermined` value.
- Existing permission scope is unchanged: Calendar Action Layer requests write-only event access on macOS 14+ and Reminders requests full access.

## [1.1.0.0] - 2026-08

Release Candidate 1.1 — Calendar Intelligence.

### Added
- Added an on-demand Calendar Intelligence window that reads macOS Calendar events and returns a date-sorted list with time, title, location, and calendar source.
- Added local natural-language calendar query parsing for current/next year, current/next month, numeric or Chinese month names, location constraints, and lecturer/training/meeting categories.
- Added deterministic lecturer matching with explicit presenter signals such as `講師`, `主講`, `授課`, and `演講`, while excluding attendee signals such as `參加`, `報名`, `學員`, and `受訓`.
- Added Swift unit tests for calendar query interval parsing, Chinese month/location parsing, lecturer filtering, and general keyword matching.

### Changed
- Added `查詢行事曆…` to the DeskPet context menu without changing the existing Inbox, Daily Work, GAS task, or Work Diary flows.
- Calendar write actions keep their existing write-only permission path; full event access is requested only when the user actively performs a Calendar Intelligence query.

### Privacy / Safety
- RC1.1 calendar query parsing and filtering run locally and do not send Calendar event content to Gemini.
- Calendar, Reminders, and GAS write operations remain confirmation-gated; Calendar Intelligence is read-only.
- No GAS Dashboard schema or local Inbox / WorkEvent persistence format was changed.

## [1.0.0.0] - 2026-08

Release Candidate 1 — Daily Work Loop.

### Added
- Added deterministic Today Brief, Waiting Radar, Daily Wrap, and Monday-based Weekly Review derived from GAS tasks, Inbox items, and WorkEvents.
- Added confirmed recent-progress / next-action updates without changing the Dashboard 19-column schema.
- Added centralized derived Pet Work State and local-only task snoozes.
- Added a SwiftPM unit-test target covering priority, review boundaries, waiting, snooze, persistence, pet state, and confirmation safety.

### Changed
- Reused the existing task digest window as the primary Daily Work surface and expanded Ambient digest reads to 30 candidates.
- Added `nextAction` to the Gateway `updateTask` allow-list and aligned Gateway digest ordering with RC1 priority tiers.

### Safety
- Task mutations still require the existing confirmation view and only append WorkEvents after successful writes.
- Snooze never modifies GAS deadlines; Gemini remains optional; Inbox and WorkEvent persistence formats remain backward compatible.

## [0.9.5.1] - 2026-08

### Added
- Added the maintainer-supplied white DeskPet assistant artwork as the macOS application icon.
- Added deterministic multi-resolution ICNS packaging and CI verification for the source image, bundle resource and `CFBundleIconFile` metadata.

## [0.9.5.0] - 2026-08

### Added
- Added a determinate software-update progress bar with the current stage and percentage in General settings.
- Added a bounded, validated progress protocol between the bundled updater and the running app.

### Changed
- Kept DeskPet open while downloading, building and verifying an update, and close it only immediately before app replacement.
- Redirected updater output to the persistent update log before replacing the running app so post-close installation is not interrupted by a broken output pipe.

### Safety
- Update failures before replacement remain visible in the app and point to `~/Library/Logs/DeskPet/update.log`; the existing rollback behavior remains in place after replacement begins.

## [0.9.4.0] - 2026-08

### Changed
- Unified role-specific UI labels and GAS task ownership under the administrative title, resolved as local override → Dashboard `ROLE_NAME` → `總務` fallback.
- Workbench, work digest, reminder, task-action, natural-language and duplicate-check UI now use the same administrative title.
- Moved administrative-title editing to General settings and removed the separate work-interface-name control.

### Migration
- Existing `0.9.3.0` work-interface-name preferences are migrated once into the administrative-title override when no override already exists, then the retired key is removed.

## [0.9.3.0] - 2026-08

### Added
- Added a persistent interface work-role name under General settings, with a default of `總務` and validation for custom values.
- Workbench, work digest, reminder, task-action and related task messages now use the configured role name.

### Changed
- Kept the interface role name separate from the GAS administrative-title override so display customization never changes task ownership or Dashboard profile keys.

## [0.9.2.1] - 2026-08

### Fixed
- Braced the updater version variable so the macOS system Bash does not treat adjacent Unicode punctuation as part of the variable name under `set -u`.
- Made the four bundled pet images required build inputs instead of silently falling back when packaging is incomplete.
- Extended CI to build the `.app` bundle and verify all four default images are present.

## [0.9.2.0] - 2026-08

### Changed
- Reworked the GAS Gateway as a non-destructive companion API for `mihozip/school-admin-daily-dashboard`.
- Dashboard school, office, role, categories and priorities now flow into DeskPet as integration metadata.
- Replaced general-affairs-only labels with profile-neutral school administration wording.

### Added
- Included the four maintainer-approved default white-cat state illustrations.
- Added `ASSETS.md` with artwork provenance and licensing notes.
- Added an in-app update checker and rollback-aware source updater.
- Added a standalone update command for users of previously installed versions.
- Added an administrative-title override for DeskPet-created task owners.

### Safety
- Gateway attachment validates the Dashboard sheet contract without creating, migrating or rewriting sheets.
- Added a CI contract test for the Dashboard schema and dynamic option mapping.

## [0.9.1.2] - 2026-08

### Added
- Duplicate Guard before creating a GAS task.
- Candidate matching against pending Inbox items and active GAS tasks.
- Explicit choices to inspect, link to an existing task, or create a new task.

### Safety
- Duplicate Guard never silently deletes or merges data.

## [0.9.1.1] - 2026-08

### Added
- Inbox → GAS Task links.
- Converted Inbox state and linked-task navigation.

## [0.9.1] - 2026-08

### Added
- Local `WorkEvent` stream.
- Daily Work Diary timeline and manual notes.
- Diary text export to clipboard.

## [0.9.0 RC] - 2026-08

### Added
- Launch at login.
- Pet size and animation intensity preferences.
- Reorganized settings and self diagnostics.
- Release and local-install scripts.

## [0.8.x]

### Added
- Voice action, Gemini natural task actions and animated pet states.
- PNG pet asset loading with runtime diagnostics.

## [0.5–0.7]

### Added
- GAS task connector and Gateway v3.
- Ambient task monitoring.
- Task interaction and natural-language task actions.

## [0.1–0.4]

### Added
- Desktop capture pet, Inbox, local intent parsing and Smart Inbox.
- Gemini interpretation.
- Calendar / Reminders action layer with confirmation and idempotent receipts.
