#!/usr/bin/env bash
# Build and reinstall AgedCare Monitor on a connected physical iPhone.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-Agedcare-shared.xcodeproj}"
SCHEME="${SCHEME:-Agedcare-shared}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUNDLE_ID="${BUNDLE_ID:-wcs.Agedcare-shared}"

resolve_device() {
  if [[ -n "${DEVICE_ID:-}" ]]; then
    echo "$DEVICE_ID"
    return
  fi
  # Prefer a connected iPhone 17 Pro Max, else first connected iPhone.
  xcrun devicectl list devices 2>/dev/null | awk '
    /iPhone/ && /connected/ {
      if ($0 ~ /iPhone 17 Pro Max/) { found=$4; model=$0 }
      else if (!any) { any=$4 }
    }
    END {
      if (found) print found
      else if (any) print any
    }
  ' | head -1
}

DEVICE_ID="$(resolve_device)"
if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "No connected iPhone found. Plug in the device and trust this Mac." >&2
  exit 1
fi

echo "Using device: $DEVICE_ID"
echo "Uninstalling previous install (if present)..."
xcrun devicectl device uninstall app --device "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

echo "Building $SCHEME ($CONFIGURATION) for device..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  clean build

APP_PATH="$(xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -showBuildSettings 2>/dev/null \
  | awk -F ' = ' '/TARGET_BUILD_DIR/ {dir=$2} /FULL_PRODUCT_NAME/ {name=$2} END {print dir "/" name}')"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built .app not found at: $APP_PATH" >&2
  exit 1
fi

echo "Installing: $APP_PATH"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
echo "Done. AgedCare Monitor reinstalled on device $DEVICE_ID."
