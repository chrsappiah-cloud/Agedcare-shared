#!/usr/bin/env bash
# Build, export, and upload Agedcare-shared to TestFlight from this Mac.
# Requires: Xcode, AuthKey_A863K5FF84.p8, and API access.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEY_ID="${ASC_KEY_ID:-A863K5FF84}"
ISSUER_ID="${ASC_ISSUER_ID:-70c46c69-5d6d-438d-b300-31df2b93163a}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.4}"
BUILD_NUMBER="${BUILD_NUMBER:-$(xcrun agvtool what-version -terse 2>/dev/null | tail -n 1 || echo 118)}"
ARCHIVE="/tmp/Agedcare-shared.xcarchive"
EXPORT="/tmp/Agedcare-shared-export"
P8="${ASC_P8_PATH:-$HOME/Downloads/AuthKey_${KEY_ID}.p8}"

if [[ ! -f "$P8" ]]; then
  echo "❌ Download AuthKey_${KEY_ID}.p8 from App Store Connect → Integrations → API"
  exit 1
fi

export API_PRIVATE_KEYS_DIR="$(dirname "$P8")"
mkdir -p "$API_PRIVATE_KEYS_DIR"
if [[ "$(basename "$P8")" != "AuthKey_${KEY_ID}.p8" ]]; then
  cp "$P8" "$API_PRIVATE_KEYS_DIR/AuthKey_${KEY_ID}.p8"
fi

echo "Stamping $MARKETING_VERSION ($BUILD_NUMBER)"
xcrun agvtool new-marketing-version "$MARKETING_VERSION"
xcrun agvtool new-version -all "$BUILD_NUMBER"

echo "Archiving…"
xcodebuild archive \
  -project Agedcare-shared.xcodeproj \
  -scheme Agedcare-shared \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM=TM2WG7HH96 \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_PRIVATE_KEYS_DIR/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

echo "Exporting IPA…"
# MacPorts/Homebrew rsync breaks Xcode export (use Apple rsync in /usr/bin).
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
rm -rf "$EXPORT"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_PRIVATE_KEYS_DIR/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

IPA="$EXPORT/Agedcare-shared.ipa"
echo "Validating $IPA…"
xcrun altool --validate-app --type ios --file "$IPA" \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID" --output-format xml

echo "Uploading to TestFlight…"
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID" --output-format xml

echo "✅ Uploaded $MARKETING_VERSION ($BUILD_NUMBER). Open App Store Connect to attach the build and submit for review."
