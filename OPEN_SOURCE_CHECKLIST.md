# Open-source publication checklist

## Completed in this prepared package

- [x] Removed hard-coded private GAS `/exec` URL.
- [x] Removed hard-coded Spreadsheet ID from the current Gateway.
- [x] Removed stale/private legacy GAS copies from the public package.
- [x] Gateway stores Spreadsheet ID and token in Script Properties.
- [x] Client stores Gemini / GAS secrets in macOS Keychain.
- [x] Added secret / private-file ignore patterns.
- [x] Added MIT source-code license.
- [x] Added README, contributing, security, privacy, architecture and release docs.
- [x] Added GitHub CI and Issue / PR templates.
- [x] Added a public-repository secret scan script.
- [x] Excluded prototype cat PNGs whose redistribution rights are not verified.

## Confirm before making the repository public

- [x] Set the public repository target to `https://github.com/mihozip/DeskPet`.
- [x] Publish **source code** under the MIT License.
- [x] Exclude pet artwork until redistribution rights can be verified.
- [x] Run `./script/check_public_repo.sh` immediately before the first push.
- [ ] Review the Git history: do not import earlier commits that contained the private Spreadsheet ID / GAS URL unless the history is scrubbed.
- [ ] Rotate the old GAS token if it was ever pasted into a shared log or repository.
- [ ] Consider replacing the existing private GAS deployment URL with a fresh deployment before public launch.
