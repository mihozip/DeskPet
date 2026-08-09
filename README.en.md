# DeskPet

[![CI](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml/badge.svg)](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Turn every thought on your desktop into trackable work.**

DeskPet is a macOS desktop work agent built with Swift, SwiftUI and AppKit. It connects quick capture, optional Gemini interpretation, human confirmation, Calendar / Reminders / Google Apps Script task actions, ambient monitoring, duplicate detection and a local work-event diary.

Current version: **0.9.1.2 — Duplicate Guard (pre-1.0 / RC)**.

## Quick start

```bash
git clone https://github.com/mihozip/DeskPet.git
cd DeskPet
./script/build_and_run.sh
```

Requirements: macOS 13+, Swift 5.9+ / Xcode or Apple Command Line Tools.

Gemini and Google Apps Script integrations are optional and require users to provide their own credentials. No private API key, Spreadsheet ID, GAS deployment URL or token is included in this repository.

Prototype pet artwork is intentionally excluded until redistribution rights are verified. The app remains buildable and shows a fallback surface without custom artwork.

See the main [Traditional Chinese README](README.md), [privacy notes](PRIVACY.md), [architecture](docs/ARCHITECTURE.md), [security policy](SECURITY.md), and the guide for [connecting the Gateway to an existing GAS / Spreadsheet project](docs/GAS_PROJECT_INTEGRATION.md).

Source code is licensed under the [MIT License](LICENSE). Artwork and other third-party assets are separately licensed.
