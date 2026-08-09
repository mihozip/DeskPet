# Changelog

All notable changes to DeskPet are documented here. The project is pre-1.0, so interfaces and stored-data formats may still evolve.

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
