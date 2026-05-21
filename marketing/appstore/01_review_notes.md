# App Review Notes — Agedcare-shared (AgedCare Monitor)

Paste the contents of this file into:
**App Store Connect → My Apps → AgedCare Monitor → App Privacy / App Review →
App Review Information → Notes**

---

## What this app does

AgedCare Monitor is a SwiftUI iOS + watchOS companion that helps professional
carers, family carers, and aged-care facility staff monitor residents living
with dementia or with elevated fall risk. It combines on-device CoreML vision
fall detection, audio distress-sound detection, environment monitoring (room
temperature via HomeKit + outdoor weather via Open-Meteo), and CloudKit/Supabase
sync of incident records.

No personal-health data leaves the device unless the user is signed into a Care
Team / Care Pro plan with explicit cloud-sync enabled. The default experience
is a fully local demo facility with seeded synthetic residents.

## How to sign in for review

The app opens on the **Hero Panel Router** (`UnifiedShellView`) which lets the
reviewer choose between **Resident** and **Staff** shells without a network
call. To exercise the staff features tap **"Staff"** then **"Sign in"** and use:

| Profile           | Email                    | Password   |
|-------------------|--------------------------|------------|
| Administrator     | admin@gvcare.com         | password   |
| Nurse             | nurse@gvcare.com         | password   |
| Carer             | carer@gvcare.com         | password   |

These credentials are seeded in the `DemoAccessProfile` list in `AppHost.swift`
and authenticate against the local demo store — no real network round-trip is
required to access the staff dashboard. The reviewer does NOT need iCloud,
HomeKit accessories, an Apple Watch, or live backend credentials.

## Test accounts already accepted for TestFlight beta

(Optional — only fill in if Apple asks for tester-tier coverage.)

| Profile             | Email                       | Tier        |
|---------------------|-----------------------------|-------------|
| Care Team tester    | teamtester@gvcare.com       | Care Team   |
| Care Pro tester     | protester@gvcare.com        | Care Pro    |
| Starter tester      | startertester@gvcare.com    | Starter     |

## What the reviewer can verify in ~5 minutes

1. Launch app → Hero Panel Router appears with **Resident** and **Staff** cards.
2. Tap **Resident** → `ResidentHomeView` shows the seeded "Dr Maria Hernandez"
   demo resident with timeline, weather card, and watch-pairing prompt.
3. Back, tap **Staff** → `StaffShellView` opens.
4. Sign in with `admin@gvcare.com` / `password`.
5. `StaffParticipantBridgeView` lists 3 seeded residents. Tap any → timeline,
   alerts, settings.
6. **Alerts → Add Alert** to confirm `AlertsRepository` round-trips through the
   local Supabase-shaped store.
7. **Settings → About** shows the marketing config and links to
   <https://wcs-full.vercel.app>.

## Why each permission prompt appears (verbatim from Info.plist)

- **Camera** — AI fall detection, room monitoring, photo evidence for incidents.
- **Microphone** — real-time distress-sound detection, keyword alerts.
- **Speech Recognition** — transcribe calls for help / distress phrases.
- **Face ID** — secure staff authentication.
- **HealthKit (read + write)** — heart rate, SpO₂, step count for anomaly
  detection; writing monitoring measurements.
- **HomeKit** — read connected temperature sensors / thermostats to display the
  actual resident room temperature.
- **Local Network** — discover facility monitoring devices and sensors.
- **Location (when in use)** — identify the facility for correct alert
  attribution and display accurate outdoor weather conditions.
- **Photo Library (add + read)** — attach images to incident reports and save
  captured photo/video records.

All prompts trigger only when the staff user opts in to that monitoring
feature — none are blocking on first launch.

## Sign-In with Apple

Not used. Authentication is email/password against the seeded demo store. There
is no third-party login, no Sign in with Apple, and no Google/Facebook SDKs.

## Account deletion

Settings → Account → **Delete Account** invokes
`SessionViewModel.deleteAccountAndPurge()` which removes all local CloudKit
records and Supabase rows associated with the signed-in user, then logs out.
Compliant with Guideline 5.1.1(v).

## Background modes

`audio` (for distress-sound monitoring), `location` (when room sensor is far
from the iPhone), and `fetch` (for periodic CloudKit alert sync). All are
disabled by default and opt-in per-resident in the staff settings panel.

## Networking destinations

- `https://agedcare-api.chrsappiah.cloud` — production API (Cloudflare Worker
  proxy to Supabase). Health probe in `BackendHealthService`.
- `https://api.open-meteo.com` — outdoor weather (no auth, no PII).
- `https://wcs-full.vercel.app` — marketing site (links only, no PII).
- Apple CloudKit container `iCloud.wcs.Agedcare-shared` — private database
  only.

## Contact

- Reviewer support: christopher.appiahthompson@myworldclass.org
- Phone / time zone: provided in App Store Connect contact info
