#!/usr/bin/env bash
# Copy one App Store Connect field to the clipboard.
# Usage: ./scripts/copy-inflight-field.sh promo|description|keywords|support|marketing|privacy|copyright|whatsnew|review|demo-user|demo-pass|all
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${1:-}" == "all" ]]; then
  open "$ROOT/marketing/appstore/INFLIGHT_PASTE.txt"
  echo "Opened INFLIGHT_PASTE.txt"
  exit 0
fi

python3 - "$1" <<'PY' | pbcopy
import sys
fields = {
"promo": "Track resident wellbeing in real time — Vision-based fall detection, distress-sound monitoring, HomeKit room temperature and live local weather, all on device.",
"keywords": "aged,care,dementia,monitor,fall,detection,HomeKit,SOS,carer,nurse,facility,family,resident,alert",
"support": "https://wcs-full.vercel.app/support",
"marketing": "https://wcs-full.vercel.app/apps/agedcare-shared",
"privacy": "https://wcs-full.vercel.app/privacy",
"copyright": "© 2026 Worldclass Solutions (WCS)",
"whatsnew": "Version 1.0.4 improves App Store readiness: cleaner app bundle, critical messaging privacy text, production TestFlight signing, and reviewer-friendly demo sign-in (admin@gvcare.com). Includes fall detection, distress audio monitoring, HomeKit room temperature, live weather, HealthKit vitals trends, CloudKit sync, and Apple Watch companion alerts.",
"demo-user": "admin@gvcare.com",
"demo-pass": "password",
"description": """AgedCare Monitor is a non-clinical monitoring aid for professional carers, family carers, and aged-care facility staff supporting residents living with dementia, increased fall risk, or other care-intensive conditions.

Core capabilities
• On-device Vision fall detection using Apple Vision and CoreMotion — no video ever leaves the iPhone.
• Real-time audio distress-sound and keyword detection using SoundAnalysis and on-device Speech Recognition.
• Live resident room temperature via HomeKit-connected sensors and outdoor weather context via Open-Meteo.
• HealthKit integration for heart rate, blood oxygen and step-count trend observation (read-only).
• CloudKit private-database sync of incident records and an Apple Watch companion that surfaces alerts and SOS controls on the wrist.
• Multi-role dashboards: Administrator, Nurse, Carer and Family — each with a permission-scoped view.

How it is used
1. A bedside iPhone is placed in a resident's room and tapped into the Resident shell. It silently watches for falls and distress sounds.
2. Care staff and family use the Staff shell from their own iPhone to view the dashboard, respond to alerts, and review the resident timeline.
3. The Apple Watch companion mirrors the alert summary and the SOS button so carers can act without unlocking a phone.

Privacy by design
• Cameras and microphones are only opened when monitoring is explicitly enabled by a care worker.
• Audio and video analysis happens on device — clips are only persisted when an incident is detected and the care team chooses to retain them.
• Account deletion is one tap in Settings → Account → Delete Account.
• No third-party analytics, no advertising SDKs, no tracking.

This app is a monitoring aid, not a medical device. It does not diagnose, treat or prevent any condition and is not a substitute for professional medical advice or emergency services. In an emergency dial 000 (Australia) or your local emergency number.""",
"review": """WHAT THIS APP DOES

AgedCare Monitor is a SwiftUI iOS and watchOS companion for professional carers, family carers, and aged-care facility staff monitoring residents with dementia or elevated fall risk. It combines on-device fall detection, audio distress monitoring, HomeKit room temperature, outdoor weather, and optional CloudKit sync. The default experience is a fully local demo facility with seeded residents; cloud sync is opt-in.

HOW TO SIGN IN FOR REVIEW

The app opens on the Hero Panel Router (Resident and Staff cards, no network required).

Tap Staff, then Sign in:
  Administrator: admin@gvcare.com / password
  Nurse: nurse@gvcare.com / password
  Carer: carer@gvcare.com / password

Credentials are in DemoAccessProfile in AppHost.swift (local demo store). No iCloud, HomeKit hardware, Apple Watch, or live backend is required for review.

5-MINUTE REVIEW PATH

1. Launch — Hero Panel Router with Resident and Staff cards.
2. Resident — seeded demo resident (Dr Maria Hernandez), timeline, weather card.
3. Staff — sign in admin@gvcare.com / password.
4. Open any resident — timeline, alerts, settings.
5. Alerts — Add Alert — confirm it persists after relaunch.
6. Settings — About — marketing links.

PERMISSIONS (opt-in only, not on first launch)

Camera: fall detection and incident photos. Microphone: distress-sound monitoring. Speech Recognition: help-call keywords. Face ID: staff auth. HealthKit: vitals trends. HomeKit: room temperature. Location: weather context. Photo Library: incident attachments.

Sign in with Apple: not used.

Account deletion: Settings → Account → Delete Account.

Background modes: audio, location, fetch — opt-in in staff settings.

Networking: https://agedcare-api.chrsappiah.cloud, https://api.open-meteo.com, https://wcs-full.vercel.app, iCloud.wcs.Agedcare-shared (private CloudKit).

Contact: christopher.appiahthompson@myworldclass.org""",
}
key = sys.argv[1] if len(sys.argv) > 1 else "help"
if key not in fields:
    print("Usage: promo|description|keywords|support|marketing|privacy|copyright|whatsnew|review|demo-user|demo-pass", file=sys.stderr)
    sys.exit(1)
sys.stdout.write(fields[key])
PY

n=$(pbpaste | wc -c | tr -d ' ')
echo "Copied '${1}' to clipboard (${n} chars). Paste with ⌘V."
