# DeskPet

[![CI](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml/badge.svg)](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Turn every thought on your desktop into trackable work.**

DeskPet is a macOS desktop work agent built with Swift, SwiftUI and AppKit. It connects quick capture, optional Gemini interpretation, human-confirmed Calendar / Reminders / Google Apps Script actions, ambient monitoring, and a local Work Diary.

**Current mainline version: 1.2.1.0 — RC1.2.1 / Context Briefing**

Published install packages are available from GitHub Releases. `main` is the latest CI-validated source line.

## RC1.2.1: Context Briefing

RC1.2.1 connects the existing RC1.2 Work Context to the desktop pet. Users no longer need to open Today Work first to discover the current focus. DeskPet can show one low-noise `白帥帥建議` bubble when the context changes enough to matter.

Default triggers:

- first useful context of the day;
- one briefing for a non-all-day Calendar event 10–60 minutes away;
- immediate next-focus briefing after a completed task changes Now;
- other focus changes only after a 30-minute cooldown.

Clicking the bubble opens the full Today Work / Now / Next / Later surface. Context Briefing does not require GAS to be linked: Inbox and local Calendar can provide context by themselves. Today Work is therefore always available from both the pet menu and the macOS menu-bar fallback.

See [`docs/RC1_2_1_CONTEXT_BRIEFING.md`](docs/RC1_2_1_CONTEXT_BRIEFING.md).

## RC1.2: Work Context

RC1.2 adds a deterministic `WorkContextEngine` that combines active GAS tasks, Inbox items, WorkEvents, local snooze state, and local Calendar events into three orientation buckets:

- **Now** — what deserves attention now.
- **Next** — what should follow.
- **Later** — what should remain visible without interrupting current focus.

```text
GAS Tasks ───────┐
Inbox ───────────┤
WorkEvents ──────┤
Snooze ──────────┼─> WorkContextEngine ─> Now / Next / Later
Local Calendar ──┘
```

The context layer does not create a second task database. Calendar data stays local to EventKit and is never sent to Gemini. Calendar read failures degrade gracefully to task / Inbox / WorkEvent context. Waiting tasks do not take over Now even when high-priority, and all-day events do not replace the active-focus headline.

See [`docs/RC1_2_WORK_CONTEXT.md`](docs/RC1_2_WORK_CONTEXT.md) for the design and privacy boundary.

## Core features

- Desktop pet with drag, size and animation controls.
- Low-noise Context Briefing tied to the deterministic Work Context.
- Menu-bar fallback entry point.
- Global quick capture into a local Inbox.
- Smart Inbox with local parsing and optional Gemini interpretation.
- Calendar Intelligence with local natural-language filtering.
- Work Context: Now / Next / Later.
- Today Brief, Waiting Radar, Next Action, Daily Wrap and Weekly Review.
- Append-style local Work Diary built from `WorkEvent` records.
- Optional GAS Gateway for school-administration tasks.
- Ambient task monitoring after GAS is linked.
- Natural-language and voice task proposals with explicit confirmation before writes.
- Inbox → Task provenance and Duplicate Guard.
- Local-only Snooze and derived Pet Work State.
- Rollback-aware software update workflow.

## Safety and privacy

DeskPet keeps read, recommendation and mutation boundaries separate:

- Calendar Intelligence, Work Context and Context Briefing are read-only.
- Calendar event content is not sent to Gemini.
- Context Briefing persists only delivery-control metadata in local `UserDefaults`.
- Calendar / Reminders / GAS writes require explicit human confirmation.
- Gemini API keys and GAS tokens are stored in macOS Keychain.
- Work Context creates no additional persistent task or calendar database.

See [`PRIVACY.md`](PRIVACY.md), [`SECURITY.md`](SECURITY.md), and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Gemini

Current picker:

- `gemini-3.6-flash` — default / recommended
- `gemini-3.5-flash`
- `gemini-3.5-flash-lite`

Gemini 2.x options are retired. As of 2026-08-18, Google has not published a verifiable Gemini 3.7 Flash Gemini API model identifier, so DeskPet does not guess `gemini-3.7-flash`. See [`docs/GEMINI_MODELS.md`](docs/GEMINI_MODELS.md).

## Quick start

```bash
git clone https://github.com/mihozip/DeskPet.git
cd DeskPet
./script/build_and_run.sh
```

Requirements: macOS 13+, Swift 5.9+ / Xcode or Apple Command Line Tools.

Local install:

```bash
./script/install_local.sh
```

Updater, signing, rollback and legacy bootstrap details are documented in [`docs/UPDATING.md`](docs/UPDATING.md).

Gemini and GAS integrations are optional and require user-supplied credentials. No private API key, Spreadsheet ID, deployment URL or token is included in this repository.

The Gateway integrates with [`mihozip/school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) through a separate token-protected Web App. See [`docs/GAS_PROJECT_INTEGRATION.md`](docs/GAS_PROJECT_INTEGRATION.md).

Source code and maintainer-approved default artwork are distributed under the [MIT License](LICENSE). Asset provenance is documented in [ASSETS.md](ASSETS.md).
