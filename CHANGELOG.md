# Changelog

All notable changes to DeskPet are documented here. The project is pre-1.0, so interfaces and stored-data formats may still evolve.

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
- Workbench, work digest, work reminder, task-action, natural-language and duplicate-check UI now use the same administrative title.
- Moved administrative-title editing to General settings and removed the separate work-interface-name control.

### Migration
- Existing `0.9.3.0` work-interface-name preferences are migrated once into the administrative-title override when no override already exists, then the retired key is removed.

## [0.9.3.0] - 2026-08

### Added
- Added a persistent interface work-role name under General settings, with a default of `總務` and validation for custom values.
- Workbench, task digest, reminder, task-action and related task messages now use the configured role name.

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
