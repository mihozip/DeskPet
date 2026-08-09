# Releasing DeskPet

## Local RC build

```bash
./script/build_release.sh
```

Without `CODESIGN_IDENTITY`, the script uses ad-hoc signing. This is suitable for local testing, not public binary distribution.

## Developer ID build

```bash
BUNDLE_ID="io.github.yourname.DeskPet" \
CODESIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
./script/build_release.sh
```

The script enables Hardened Runtime for Developer ID signing.

## Public binary distribution

Before publishing a `.app` / ZIP / DMG:

1. verify bundle contents and entitlements
2. sign with Developer ID Application
3. notarize with Apple
4. staple the notarization ticket
5. validate with `codesign`, `spctl` and `stapler`

Do not describe an ad-hoc signed build as notarized or generally distributable.

## Source releases

Before tagging:

```bash
./script/check_public_repo.sh
swift package dump-package >/dev/null
```

Then run the macOS CI build, update `CHANGELOG.md`, and tag using semantic versioning, for example:

```bash
git tag -a v0.9.2.1 -m "DeskPet 0.9.2.1"
git push origin v0.9.2.1
```
