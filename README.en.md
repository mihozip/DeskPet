# DeskPet

[![CI](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml/badge.svg)](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Turn every thought on your desktop into trackable work.**

DeskPet is a macOS desktop work agent built with Swift, SwiftUI and AppKit. It connects quick capture, optional Gemini interpretation, human confirmation, Calendar / Reminders / Google Apps Script task actions, ambient monitoring, duplicate detection and a local work-event diary.

Current version: **0.9.5.0 — Visible Update Progress (pre-1.0 / RC)**.

## Quick start

```bash
git clone https://github.com/mihozip/DeskPet.git
cd DeskPet
./script/build_and_run.sh
```

Requirements: macOS 13+, Swift 5.9+ / Xcode or Apple Command Line Tools.

Installed builds can check and install updates from **Settings → General → Software Update**. The app shows the active stage and percentage while downloading, building and verifying, then closes only when it is ready to replace and relaunch itself. Users of older builds can bootstrap the same rollback-aware updater with the command documented in the main README. Updating preserves Application Support data, preferences and Keychain credentials.

Gemini and Google Apps Script integrations are optional and require users to provide their own credentials. No private API key, Spreadsheet ID, GAS deployment URL or token is included in this repository.

Four default AI-assisted redrawn white-cat illustrations are included for idle, listening, success and sleep states. The project maintainer has approved their public redistribution; see [ASSETS.md](ASSETS.md) for provenance and licensing notes.

The Gateway integrates with [`mihozip/school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) through a separate token-protected Web App. See the main [Traditional Chinese README](README.md), [privacy notes](PRIVACY.md), [architecture](docs/ARCHITECTURE.md), [security policy](SECURITY.md), and the [Dashboard integration guide](docs/GAS_PROJECT_INTEGRATION.md).

DeskPet resolves the administrative title in this order: local override, Dashboard `ROLE_NAME`, then the `總務` fallback. One title now controls the workbench, digest, work reminder, task-action labels, related task messages and the owner of tasks created by DeskPet, without changing Dashboard profile keys. The retired 0.9.3.0 interface-name preference is migrated automatically.

Source code and the maintainer-supplied default artwork are distributed under the [MIT License](LICENSE). Third-party or contributor-supplied assets retain their own terms.
