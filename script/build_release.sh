#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DeskPet"
PRODUCT_NAME="DeskPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${BUNDLE_ID:-tw.mihozip.deskpet}"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="1000"
# File Provider volumes can immediately reattach FinderInfo to a freshly cleaned
# bundle and make codesign reject it. Maintainers may stage a release on a local
# filesystem while keeping the default repository output for normal checkouts.
DIST_DIR="${DESKPET_RELEASE_DIR:-$ROOT_DIR/dist-release}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ZIP_PATH="$DIST_DIR/DeskPet-${VERSION}.zip"

# Compatibility bridge for DeskPet 1.2.1.1–1.4.0.0 in-app updaters. Those
# bundled updater scripts download main.zip and then call build_release.sh.
# When that legacy path is detected, prefer the already-published release asset
# instead of rebuilding Swift locally. If the asset is not available yet, fall
# back to the historical source build path below.
if [[ "${DESKPET_PROGRESS_PROTOCOL:-0}" == "1" && "${DESKPET_FORCE_SOURCE_BUILD:-0}" != "1" ]]; then
    RELEASE_URL="https://github.com/mihozip/DeskPet/releases/download/v${VERSION}/DeskPet-${VERSION}.zip"
    LEGACY_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/deskpet-legacy-release.XXXXXX")"
    LEGACY_ZIP="$LEGACY_TEMP_DIR/DeskPet-${VERSION}.zip"
    LEGACY_EXTRACT="$LEGACY_TEMP_DIR/extracted"

    echo "Legacy updater compatibility: trying published DeskPet ${VERSION} release asset…"
    if /usr/bin/curl \
        --fail --location --silent --show-error \
        --connect-timeout 10 --max-time 180 \
        --retry 3 --retry-delay 2 --retry-all-errors \
        "$RELEASE_URL" \
        --output "$LEGACY_ZIP"; then
        mkdir -p "$LEGACY_EXTRACT"
        /usr/bin/ditto -x -k "$LEGACY_ZIP" "$LEGACY_EXTRACT"
        LEGACY_APP="$(find "$LEGACY_EXTRACT" -maxdepth 3 -type d -name DeskPet.app -print -quit)"

        if [[ -n "$LEGACY_APP" && -x "$LEGACY_APP/Contents/MacOS/DeskPet" ]]; then
            LEGACY_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$LEGACY_APP/Contents/Info.plist" 2>/dev/null || true)"
            if [[ "$LEGACY_VERSION" == "$VERSION" ]] && /usr/bin/codesign --verify --deep --strict --verbose=2 "$LEGACY_APP"; then
                rm -rf "$DIST_DIR"
                mkdir -p "$DIST_DIR"
                /usr/bin/ditto "$LEGACY_APP" "$APP_BUNDLE"
                cp "$LEGACY_ZIP" "$ZIP_PATH"
                /bin/rm -rf "$LEGACY_TEMP_DIR"
                echo "Legacy updater compatibility: using published DeskPet ${VERSION} app; local Swift rebuild skipped."
                printf 'Release App: %s\n' "$APP_BUNDLE"
                printf 'Release ZIP: %s\n' "$ZIP_PATH"
                exit 0
            fi
        fi

        echo "WARN: published release asset failed validation; falling back to local source build" >&2
    else
        echo "WARN: published release asset is not available yet; falling back to local source build" >&2
    fi
    /bin/rm -rf "$LEGACY_TEMP_DIR"
fi

# A stable signing identity is important for macOS TCC permissions. Local builds
# and the source-based updater reuse Developer ID / Apple Development when the
# current Mac has one. CI without a configured identity still falls back to ad-hoc.
# shellcheck source=resolve_codesign_identity.sh
source "$ROOT_DIR/script/resolve_codesign_identity.sh"
CODESIGN_IDENTITY="$(deskpet_resolve_codesign_identity)"

cd "$ROOT_DIR"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "Building DeskPet $VERSION Custom App Icon (release)…"
swift build -c release --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BIN_DIR/$PRODUCT_NAME"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

PET_RESOURCE_SRC="$ROOT_DIR/Sources/DeskPet/Resources"
PET_ASSETS=(pet_idle.png pet_listening.png pet_success.png pet_sleep.png)
for asset in "${PET_ASSETS[@]}"; do
    src="$PET_RESOURCE_SRC/$asset"
    dst="$RESOURCES_DIR/$asset"
    [[ -s "$src" ]] || {
        echo "ERROR: required default pet asset is missing or empty: $src" >&2
        exit 1
    }
    cp "$src" "$dst"
    /usr/bin/xattr -c "$dst" 2>/dev/null || true
done

APP_ICON_SRC="$PET_RESOURCE_SRC/AppIcon.icns"
[[ -s "$APP_ICON_SRC" ]] || {
    echo "ERROR: required app icon is missing or empty: $APP_ICON_SRC" >&2
    exit 1
}
cp "$APP_ICON_SRC" "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/xattr -c "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true

cp "$ROOT_DIR/VERSION" "$RESOURCES_DIR/VERSION"
cp "$ROOT_DIR/script/install_or_update.sh" "$RESOURCES_DIR/DeskPetUpdater.sh"
chmod +x "$RESOURCES_DIR/DeskPetUpdater.sh"

if [[ ! -x "$RESOURCES_DIR/DeskPetUpdater.sh" || "$(tr -d '[:space:]' < "$RESOURCES_DIR/VERSION")" != "$VERSION" ]]; then
    echo "ERROR: updater resources failed to package" >&2
    exit 1
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleIconFile</key><string>AppIcon.icns</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSCalendarsUsageDescription</key><string>DeskPet 需要存取行事曆，以建立你確認的事件並在你主動查詢時整理既有行程。</string>
    <key>NSCalendarsWriteOnlyAccessUsageDescription</key><string>DeskPet 只會在你按下建立按鈕後新增行事曆事件。</string>
    <key>NSCalendarsFullAccessUsageDescription</key><string>DeskPet 需要完整行事曆存取，以在你主動查詢時讀取既有行程，並在你確認後建立事件。</string>
    <key>NSRemindersUsageDescription</key><string>DeskPet 需要在你確認後建立提醒事項。</string>
    <key>NSRemindersFullAccessUsageDescription</key><string>DeskPet 需要提醒事項完整存取，以在你確認後建立提醒事項。</string>
    <key>NSMicrophoneUsageDescription</key><string>DeskPet 需要使用麥克風，將你說的任務操作轉成文字。</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>DeskPet 需要使用 macOS 語音辨識，將語音命令轉成文字後交給任務理解流程。</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$CONTENTS/Info.plist" >/dev/null
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "Signing: ad-hoc (TCC permissions may need re-authorization after rebuild/update)"
    CODESIGN_ARGS=(--force --deep --sign -)
else
    echo "Signing: $CODESIGN_IDENTITY"
    CODESIGN_ARGS=(--force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY")
fi

SIGN_SUCCEEDED=0
for attempt in 1 2 3; do
    /usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true
    if /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"; then
        SIGN_SUCCEEDED=1
        break
    fi
    echo "WARN: codesign attempt $attempt failed; retrying after bundle metadata cleanup" >&2
    /bin/sleep 1
done
if [[ "$SIGN_SUCCEEDED" -ne 1 ]]; then
    echo "ERROR: codesign failed after 3 attempts" >&2
    exit 1
fi

/usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

for asset in "${PET_ASSETS[@]}"; do
    if [[ -s "$PET_RESOURCE_SRC/$asset" && ! -s "$RESOURCES_DIR/$asset" ]]; then
        echo "ERROR: release asset failed to package: $asset" >&2
        exit 1
    fi
done
if [[ ! -s "$RESOURCES_DIR/AppIcon.icns" ]]; then
    echo "ERROR: release app icon failed to package" >&2
    exit 1
fi

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo
printf 'Release App: %s\n' "$APP_BUNDLE"
printf 'Release ZIP: %s\n' "$ZIP_PATH"
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "NOTE: This build is ad-hoc signed. TCC permission persistence across different builds is not guaranteed."
else
    echo "NOTE: Signed with stable identity: $CODESIGN_IDENTITY"
fi
