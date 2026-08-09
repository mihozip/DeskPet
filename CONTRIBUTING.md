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
bash -n script/build_and_run.sh
bash -n script/build_release.sh
bash -n script/install_local.sh
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

Do not commit artwork unless you have the right to redistribute it under terms compatible with a public repository. Source-code licensing does not grant rights to third-party images.
