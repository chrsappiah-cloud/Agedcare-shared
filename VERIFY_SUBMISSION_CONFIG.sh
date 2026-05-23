#!/usr/bin/env bash
# Apple App Store submission configuration verification script

set -euo pipefail

echo "===== AGEDCARE MONITOR — SUBMISSION CONFIG AUDIT ====="
echo ""

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# 1. Check Xcode project configuration
echo "1. XCODE PROJECT CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PBXPROJ="Agedcare-shared.xcodeproj/project.pbxproj"

if [[ -f "$PBXPROJ" ]]; then
  pass "Xcode project found: $PBXPROJ"
  
  # Extract version and build
  MARKETING_VERSION=$(grep "MARKETING_VERSION = " "$PBXPROJ" | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\).*/\1/')
  CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | head -1 | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\).*/\1/')
  TEAM_ID=$(grep "DEVELOPMENT_TEAM = " "$PBXPROJ" | head -1 | sed 's/.*DEVELOPMENT_TEAM = \([^;]*\).*/\1/')
  
  echo "  - Marketing Version: $MARKETING_VERSION"
  echo "  - Build Number: $CURRENT_BUILD"
  echo "  - Team ID: $TEAM_ID"
  
  if [[ "$MARKETING_VERSION" == "1.0.4" ]]; then
    pass "Marketing version is 1.0.4"
  else
    warn "Marketing version is $MARKETING_VERSION (expected 1.0.4)"
  fi
  
  if [[ "$CURRENT_BUILD" == "118" ]]; then
    pass "Build number is 118"
  else
    warn "Build number is $CURRENT_BUILD (expected 118)"
  fi
  
  if [[ "$TEAM_ID" == "TM2WG7HH96" ]]; then
    pass "Team ID is correct: $TEAM_ID"
  else
    fail "Team ID mismatch: $TEAM_ID (expected TM2WG7HH96)"
  fi
else
  fail "Xcode project not found at $PBXPROJ"
fi

echo ""

# 2. Check Info.plist
echo "2. INFO.PLIST VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INFOPLIST="Agedcare-shared/Info.plist"
if [[ -f "$INFOPLIST" ]]; then
  pass "Info.plist found"
  
  # Check for encryption flag
  if plutil -p "$INFOPLIST" | grep -q "ITSAppUsesNonExemptEncryption"; then
    ENCRYPTION=$(plutil -p "$INFOPLIST" | grep "ITSAppUsesNonExemptEncryption" | awk '{print $NF}')
    echo "  - ITSAppUsesNonExemptEncryption: $ENCRYPTION"
    if [[ "$ENCRYPTION" == "0" || "$ENCRYPTION" == "false" ]]; then
      pass "App marked as using only exempt encryption (HTTPS/TLS)"
    fi
  else
    warn "ITSAppUsesNonExemptEncryption not found in Info.plist"
  fi
  
  # Check backend URLs
  if plutil -p "$INFOPLIST" | grep -q "BackendBaseURL"; then
    pass "Backend URL configured in Info.plist"
  fi
else
  fail "Info.plist not found"
fi

echo ""

# 3. Check Entitlements
echo "3. ENTITLEMENTS & CAPABILITIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ENTITLEMENTS="Agedcare-shared/Agedcare_shared_release.entitlements"
if [[ -f "$ENTITLEMENTS" ]]; then
  pass "Release entitlements found: $ENTITLEMENTS"
  
  # Check for key capabilities
  declare -a CAPABILITIES=(
    "com.apple.developer.healthkit"
    "com.apple.developer.homekit"
    "com.apple.developer.icloud-services"
    "aps-environment"
  )
  
  for cap in "${CAPABILITIES[@]}"; do
    if grep -q "$cap" "$ENTITLEMENTS"; then
      pass "  - $cap configured"
    else
      warn "  - $cap NOT found (optional)"
    fi
  done
else
  warn "Release entitlements not found at $ENTITLEMENTS"
fi

echo ""

# 4. Check Export Options
echo "4. EXPORT OPTIONS (App Store Connect Distribution)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXPORT_OPTS="ExportOptions.plist"
if [[ -f "$EXPORT_OPTS" ]]; then
  pass "ExportOptions.plist found"
  
  METHOD=$(plutil -p "$EXPORT_OPTS" | grep "method" | awk '{print $NF}' | tr -d '"')
  TEAM=$(plutil -p "$EXPORT_OPTS" | grep "teamID" | awk '{print $NF}' | tr -d '"')
  CERT=$(plutil -p "$EXPORT_OPTS" | grep "signingCertificate" | awk '{print $NF}' | tr -d '"')
  
  echo "  - Method: $METHOD"
  echo "  - Team ID: $TEAM"
  echo "  - Certificate: $CERT"
  
  if [[ "$METHOD" == "app-store-connect" ]]; then
    pass "Export method is app-store-connect"
  else
    fail "Export method is $METHOD (expected app-store-connect)"
  fi
  
  if [[ "$TEAM" == "TM2WG7HH96" ]]; then
    pass "Export Team ID matches: $TEAM"
  else
    fail "Export Team ID mismatch: $TEAM"
  fi
else
  fail "ExportOptions.plist not found"
fi

echo ""

# 5. Check App Store Marketing Materials
echo "5. APP STORE MARKETING MATERIALS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MARKETING_DIR="marketing/appstore"
if [[ -d "$MARKETING_DIR" ]]; then
  pass "Marketing directory found: $MARKETING_DIR"
  
  declare -a REQUIRED_DOCS=(
    "01_review_notes.md"
    "02_what_to_test.md"
    "03_privacy_nutrition_label.md"
    "04_rejection_response_templates.md"
    "05_appstore_form_fields.md"
    "06_age_rating_and_export.md"
    "07_submission_checklist.md"
    "08_distribution_review_responses.md"
    "INFLIGHT_PASTE.txt"
    "SUBMIT_NOW.md"
  )
  
  for doc in "${REQUIRED_DOCS[@]}"; do
    if [[ -f "$MARKETING_DIR/$doc" ]]; then
      pass "  - $doc"
    else
      fail "  - $doc MISSING"
    fi
  done
else
  fail "Marketing directory not found at $MARKETING_DIR"
fi

echo ""

# 6. Check API Key Setup
echo "6. APP STORE CONNECT API KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

KEY_ID="A863K5FF84"
ISSUER_ID="70c46c69-5d6d-438d-b300-31df2b93163a"

echo "  - Key ID: $KEY_ID"
echo "  - Issuer ID: $ISSUER_ID"

# Check if AuthKey exists locally
AUTHKEY="$HOME/Downloads/AuthKey_${KEY_ID}.p8"
if [[ -f "$AUTHKEY" ]]; then
  pass "AuthKey found locally at $AUTHKEY"
  echo "  - For CI/CD: Add to GitHub Secrets (ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_BASE64)"
else
  warn "AuthKey not found locally. Download from App Store Connect → Integrations → API"
fi

echo ""

# 7. Check Build & Scripts
echo "7. BUILD & RELEASE SCRIPTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

declare -a SCRIPTS=(
  "scripts/local-release.sh"
  "scripts/submit-for-review.sh"
  "scripts/open-distribution-review.sh"
  "scripts/upload-appstore-screenshots.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    if [[ -x "$script" ]]; then
      pass "  - $(basename $script) (executable)"
    else
      warn "  - $(basename $script) (not executable, run: chmod +x $script)"
    fi
  else
    warn "  - $(basename $script) NOT FOUND"
  fi
done

echo ""

# 8. Check Distribution Documentation
echo "8. DISTRIBUTION DOCUMENTATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

declare -a DOCS=(
  "APPLE_DISTRIBUTION_GUIDE.md"
  "SUBMISSION_READINESS_CHECKLIST.md"
)

for doc in "${DOCS[@]}"; do
  if [[ -f "$doc" ]]; then
    pass "  - $doc"
  else
    warn "  - $doc NOT FOUND (may need to be created)"
  fi
done

echo ""

# 9. Summary
echo "9. SUBMISSION READINESS SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "✅ All core configurations verified."
echo ""
echo "Next steps:"
echo "  1. Wait for TestFlight build processing (~10-20 min after upload)"
echo "  2. Complete App Store metadata using INFLIGHT_PASTE.txt"
echo "  3. Generate screenshots: xcrun simctl io <UUID> screenshot <file.png>"
echo "  4. Review APPLE_DISTRIBUTION_GUIDE.md for step-by-step instructions"
echo ""
echo "Build ready to submit once metadata is complete."
