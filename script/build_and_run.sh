#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DeskPet"
PRODUCT_NAME="DeskPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${BUNDLE_ID:-tw.mihozip.deskpet}"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="950"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

cd "$ROOT_DIR"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "DeskPet build toolchain:"
/usr/bin/xcrun --find swift 2>/dev/null || command -v swift
swift --version

if [[ "${DESKPET_SKIP_LAUNCH:-0}" != "1" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
fi

swift build -c debug --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c debug --show-bin-path)"
BINARY="$BIN_DIR/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
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

cp "$ROOT_DIR/VERSION" "$RESOURCES_DIR/VERSION"
cp "$ROOT_DIR/script/install_or_update.sh" "$RESOURCES_DIR/DeskPetUpdater.sh"
chmod +x "$RESOURCES_DIR/DeskPetUpdater.sh"

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
/usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "DeskPet pet assets:"
for asset in "${PET_ASSETS[@]}"; do
    if [[ -s "$RESOURCES_DIR/$asset" ]]; then
        echo "  ✓ $RESOURCES_DIR/$asset"
    else
        echo "  - $asset not bundled (fallback UI)"
    fi
done

if [[ "${DESKPET_SKIP_LAUNCH:-0}" == "1" ]]; then
    echo "Packaged without launching: $APP_BUNDLE"
else
    /usr/bin/open -n "$APP_BUNDLE"
    echo "Launched: $APP_BUNDLE"
fi
