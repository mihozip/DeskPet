# Contributing to DeskPet

Thanks for helping improve DeskPet.

## Development setup

Requirements:

- macOS 13+
- Swift 5.9+
- Apple Command Line Tools or Xcode

Run:

```bash
./script/build_and_run.sh
```

Before opening a pull request:

```bash
./script/check_public_repo.sh
node --check GAS/DeskPet_GAS_API_Gateway_v3.js
node tests/gateway_contract.test.js
bash -n script/build_and_run.sh
bash -n script/build_release.sh
bash -n script/install_local.sh
bash -n script/install_or_update.sh
./script/install_or_update.sh --help >/dev/null
./tests/updater_cli.test.sh
swift package dump-package >/dev/null
```

A macOS CI build also runs on pull requests.

## Design boundaries

Please preserve these project-level rules:

- External writes require explicit human confirmation.
- Secrets belong in Keychain / Script Properties, never in source code.
- Inbox is the capture layer; GAS is the task execution layer; Work Diary is the history layer.
- Duplicate detection may warn or propose linking, but must not silently delete or merge user data.
- AI output is a proposal, not an authorization.

## Pull requests

Keep PRs focused. Include:

- what changed
- why it changed
- manual test steps
- any privacy / permission / migration impact

If a change touches Calendar, Reminders, microphone, Speech, Gemini, Keychain or GAS, explicitly describe the affected permission or data path.

## Artwork

Default artwork provenance is documented in `ASSETS.md`. Do not submit replacement or additional artwork unless you have the right to redistribute it under terms compatible with this public repository. Include the source and license in the pull request.
