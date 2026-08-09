#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

status=0

echo "DeskPet public-repository checks"

VERSION="$(tr -d '[:space:]' < VERSION)"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: VERSION must use four numeric components"
  status=1
else
  echo "  ✓ VERSION format: $VERSION"
fi

if ! bash -n script/install_or_update.sh || ! grep -q 'DESKPET_STANDALONE_UPDATER=1' script/install_or_update.sh; then
  echo "ERROR: standalone updater syntax or marker is invalid"
  status=1
else
  echo "  ✓ Standalone updater syntax and marker"
fi

check_pattern() {
  local label="$1"
  local regex="$2"
  if grep -RInE \
      --exclude='*.png' \
      --exclude-dir='.git' \
      --exclude-dir='.build' \
      --exclude-dir='dist' \
      --exclude-dir='dist-release' \
      --exclude='check_public_repo.sh' \
      "$regex" .; then
    echo "ERROR: $label"
    status=1
  else
    echo "  ✓ $label"
  fi
}

check_pattern "No deployed Google Apps Script /exec URL" 'https://script\.google\.com/macros/s/[A-Za-z0-9_-]{20,}/exec'
check_pattern "No Google API-key-shaped literal" 'AIza[0-9A-Za-z_-]{20,}'
check_pattern "No hard-coded Spreadsheet ID config" "SPREADSHEET_ID[[:space:]]*[:=][[:space:]]*[\"\x27][A-Za-z0-9_-]{20,}"
check_pattern "No private-key PEM blocks" 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
check_pattern "No hard-coded DESKPET_API_TOKEN assignment" "DESKPET_API_TOKEN[[:space:]]*=[[:space:]]*[\"\x27][A-Za-z0-9_-]{16,}"

if find . -type f \( -name '*.p12' -o -name '*.pem' -o -name '*.key' -o -name '*.cer' \) -print | grep -q .; then
  echo "ERROR: signing/key material found"
  status=1
else
  echo "  ✓ No signing/private key files"
fi

PET_ASSETS=(pet_idle.png pet_listening.png pet_success.png pet_sleep.png)
for asset in "${PET_ASSETS[@]}"; do
  path="Sources/DeskPet/Resources/$asset"
  if [[ ! -s "$path" ]]; then
    echo "ERROR: default pet asset is missing or empty: $asset"
    status=1
    continue
  fi
  if command -v sips >/dev/null 2>&1; then
    width="$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
    if [[ "$width" != "512" || "$height" != "512" ]]; then
      echo "ERROR: $asset must be 512x512 (found ${width:-?}x${height:-?})"
      status=1
    fi
  fi
done

if [[ ! -s "ASSETS.md" ]]; then
  echo "ERROR: ASSETS.md is required when default artwork is distributed"
  status=1
else
  echo "  ✓ Default pet assets and provenance notes"
fi

if [[ "$status" -ne 0 ]]; then
  echo "Public-repository check FAILED"
  exit 1
fi

echo "Public-repository check passed"
