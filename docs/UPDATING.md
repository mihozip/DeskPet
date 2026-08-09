# Updating DeskPet

DeskPet 0.9.2.0 and later can check for updates from **Settings → General → Software Update**. The app performs at most one quiet automatic version check per day; installation always requires the user to press **Install Update**.

## What the updater does

1. Reads the latest four-part version from the repository `VERSION` file with a 12-second app-side timeout.
2. Starts the updater bundled inside `DeskPet.app` only after validating its expected script marker and size.
3. Keeps DeskPet open and reports a visible stage and percentage while downloading the latest source archive with bounded timeouts and retries.
4. Builds a complete replacement app with the local Apple Swift toolchain while continuing to report progress.
5. Verifies the replacement with `codesign` before touching the installed app.
6. At **Preparing to replace App** (88%), redirects remaining output to the persistent log, closes DeskPet, and starts the replacement transaction.
7. Moves the current app to a temporary backup, installs and verifies the new app, and restores the backup if replacement fails.
8. Relaunches DeskPet after success.

Inbox, Work Diary, preferences and Keychain credentials live outside the app bundle and are not removed during an update.

## Updating versions without the in-app button

DeskPet 0.9.1.x and earlier can bootstrap the current updater from Terminal:

```bash
curl --fail --location --show-error \
  https://raw.githubusercontent.com/mihozip/DeskPet/main/script/install_or_update.sh \
  --output /tmp/DeskPetUpdater.sh
bash /tmp/DeskPetUpdater.sh
```

Review the downloaded script before executing it if required by your environment.

## Requirements and limitations

- macOS 13 or later.
- Xcode or Apple Command Line Tools with Swift available.
- HTTPS access to GitHub.
- Write permission to the current app location. `~/Applications/DeskPet.app` is recommended.
- Source-built updates are ad-hoc signed for local use. Public binary distribution still requires Developer ID signing and notarization.

The updater log is stored at:

```text
~/Library/Logs/DeskPet/update.log
```

If an update fails before replacement, the running app displays the failure and log location. If it fails after replacement begins, launch the restored app again and inspect this log. The replacement step is designed to restore the previous app automatically when a backup exists.
