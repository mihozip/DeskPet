#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DeskPet"
PRODUCT_NAME="DeskPet"
BUNDLE_ID="${BUNDLE_ID:-tw.mihozip.deskpet}"
VERSION="0.9.1.2"
BUILD_NUMBER="912"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist-release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ZIP_PATH="$DIST_DIR/DeskPet-${VERSION}.zip"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

cd "$ROOT_DIR"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "Building DeskPet $VERSION Duplicate Guard (release)…"
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
    if [[ -s "$src" ]]; then
        cp "$src" "$dst"
    else
        echo "WARN: optional pet asset missing: $asset (fallback UI will be used)"
        continue
    fi
done

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSCalendarsUsageDescription</key><string>DeskPet 需要在你確認後建立行事曆事件。</string>
    <key>NSCalendarsWriteOnlyAccessUsageDescription</key><string>DeskPet 只會在你按下建立按鈕後新增行事曆事件。</string>
    <key>NSRemindersUsageDescription</key><string>DeskPet 需要在你確認後建立提醒事項。</string>
    <key>NSRemindersFullAccessUsageDescription</key><string>DeskPet 只會在你按下建立按鈕後新增提醒事項。</string>
    <key>NSMicrophoneUsageDescription</key><string>DeskPet 需要使用麥克風，將你說的任務操作轉成文字。</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>DeskPet 需要使用 macOS 語音辨識，將語音命令轉成文字後交給任務理解流程。</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$CONTENTS/Info.plist" >/dev/null

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "Signing: ad-hoc (local/RC testing only)"
    /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
else
    echo "Signing: $CODESIGN_IDENTITY"
    /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

for asset in "${PET_ASSETS[@]}"; do
    if [[ -s "$PET_RESOURCE_SRC/$asset" && ! -s "$RESOURCES_DIR/$asset" ]]; then
        echo "ERROR: release asset failed to package: $asset" >&2
        exit 1
    fi
done

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo
printf 'Release App: %s\n' "$APP_BUNDLE"
printf 'Release ZIP: %s\n' "$ZIP_PATH"
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "NOTE: This build is ad-hoc signed. It is suitable for local RC testing, not public distribution/notarization."
else
    echo "NOTE: Developer ID signed. Run Apple notarization before public distribution."
fi
