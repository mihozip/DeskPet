# DeskPet RC1.4.0.1 — Release Asset Updater Hotfix

RC1.4.0.1 fixes a systemic weakness in the DeskPet in-app updater used by RC1.2.1.1 through RC1.4.0.0.

## Root cause

The shipped updater detected a newer VERSION correctly, but then downloaded `main.zip` and rebuilt DeskPet locally with Swift before replacing the app. That meant a normal update depended on the local Swift/Xcode toolchain, source-build success, local signing, and the hand-off sequence even though GitHub Releases already contained a verified `DeskPet-<version>.zip` asset.

## New updater path

RC1.4.0.1 changes the normal update path to:

```text
Check VERSION
    ↓
Download published DeskPet-<version>.zip
    ↓
Extract + verify bundle version
    ↓
Verify bundle identifier + codesign
    ↓
Only now close the running DeskPet
    ↓
Backup current app
    ↓
Replace + verify installed version
    ↓
Launch new app
```

The normal updater no longer requires a local Swift/Xcode build.

## Legacy compatibility bridge

Users still running RC1.2.1.1–RC1.4.0.0 already have the old updater embedded in their app bundle. That old updater cannot be replaced before it starts, so RC1.4.0.1 also adds a compatibility bridge in `build_release.sh`.

When the old in-app updater downloads the current main source and invokes `build_release.sh`, the script detects the legacy progress protocol and tries to use the already-published release asset instead of rebuilding Swift locally. If the asset is not available, it falls back to the historical source build behavior.

This bridge allows existing updater generations to benefit from the new release-asset path after RC1.4.0.1 is published, provided the old updater can reach the downloaded project and has the basic tools it already checks for.

## Safer rollback

All download, extraction, version validation, bundle-ID validation, and signature validation now happen before the running app is asked to quit. If replacement fails after hand-off, the previous app is restored and reopened when possible.

## Validation

- updater no longer contains a Swift build requirement;
- release asset URL and version verification are contract-tested;
- hand-off ordering remains guarded;
- legacy updater compatibility is contract-tested;
- existing Swift tests and release build verification remain unchanged.
