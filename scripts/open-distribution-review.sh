#!/usr/bin/env bash
# Open App Store Connect screens for distribution / review questionnaires.
set -euo pipefail
APP_ID="${ASC_APP_ID:-6767978725}"
open "https://appstoreconnect.apple.com/apps/${APP_ID}/testflight/ios"
open "https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/ios/version/inflight"
open "https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/privacy"
open "https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/age-rating"
open "https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/ios/version/deliverable"
echo "Opened TestFlight, version 1.0.4, privacy, age rating, and submission."
echo "Responses: marketing/appstore/08_distribution_review_responses.md"
