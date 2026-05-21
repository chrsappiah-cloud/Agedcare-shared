#!/usr/bin/env bash
# Configure GitHub Actions secrets for TestFlight CD.
# Usage:
#   ./scripts/setup_asc_secrets.sh [path/to/AuthKey_A863K5FF84.p8]
set -euo pipefail

KEY_ID="${ASC_KEY_ID:-A863K5FF84}"
ISSUER_ID="${ASC_ISSUER_ID:-70c46c69-5d6d-438d-b300-31df2b93163a}"
P8_PATH="${1:-$HOME/Downloads/AuthKey_${KEY_ID}.p8}"

if [[ ! -f "$P8_PATH" ]]; then
  echo "❌ Missing API key file: $P8_PATH"
  echo "Download it once from App Store Connect → Integrations → API → Key $KEY_ID"
  exit 1
fi

echo "Setting ASC_KEY_ID=$KEY_ID"
gh secret set ASC_KEY_ID --body "$KEY_ID"

echo "Setting ASC_ISSUER_ID"
gh secret set ASC_ISSUER_ID --body "$ISSUER_ID"

echo "Setting ASC_PRIVATE_KEY_BASE64 from $P8_PATH"
base64 -i "$P8_PATH" | gh secret set ASC_PRIVATE_KEY_BASE64

echo "✅ ASC secrets configured. Re-run CD:"
echo "   gh workflow run cd.yml --ref ci/agedcare-release-automation -f marketing_version=1.0.4"
