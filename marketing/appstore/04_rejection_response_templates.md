# Rejection-response templates

If App Review rejects the submission, paste the appropriate response into:
**App Store Connect → Resolution Center → Reply**

Tone: courteous, factual, point to concrete file paths / line numbers. Never
argue the guideline — explain how the app already complies or attach a fixed
build number.

---

## Guideline 2.1 — App Completeness (missing demo account / blank screen)

> Hello Review Team,
>
> Thank you for the feedback. AgedCare Monitor opens directly on a Hero Panel
> Router (no sign-in required) and exposes a full demo facility with three
> seeded residents.
>
> To exercise the staff features, please tap **Staff → Sign in** and use:
>
> - Email: admin@gvcare.com
> - Password: password
>
> These credentials authenticate against the embedded demo store
> (`DemoAccessProfile` in `AppHost.swift`) so no live backend is required.
> Additional roles (nurse@gvcare.com, carer@gvcare.com — same password) expose
> role-specific dashboards.
>
> We have re-verified on iPhone 17 Pro Max (iOS 26.5) that the first screen is
> the Hero Panel Router with both Resident and Staff cards visible.

---

## Guideline 2.3.10 — Inaccurate metadata / mention of other platforms

> Hello Review Team,
>
> We have removed the references to {Android / web / other platform} from the
> App Store description and screenshots. Build {X} has been resubmitted with
> updated metadata that mentions only iOS, iPadOS and watchOS.

---

## Guideline 4.0 — Design / minimum functionality (perceived "thin app")

> Hello Review Team,
>
> AgedCare Monitor provides substantial on-device functionality:
>
> 1. On-device Vision-based fall detection (see `VisionFallDetector.swift`)
>    using Apple's Vision and CoreMotion frameworks — fully functional without
>    a network connection.
> 2. Real-time audio distress-sound detection (`AVCaptureService.swift`,
>    `SpeechRecognitionService.swift`) using SoundAnalysis.
> 3. HomeKit room-temperature monitoring with Open-Meteo outdoor weather
>    fallback for facilities without sensors.
> 4. Apple Watch companion (AgedcareWatchApp target) with live alert summary.
> 5. CloudKit private-database sync of incident records.
>
> The seeded demo facility lets the reviewer exercise the dashboard, alerts,
> timeline, weather and account-deletion flows in under five minutes without
> creating an account or pairing any hardware.

---

## Guideline 5.1.1 — Data Collection and Storage (privacy)

> Hello Review Team,
>
> AgedCare Monitor's privacy posture:
>
> - Camera, Microphone, HealthKit, HomeKit, Speech Recognition, Photos,
>   Location, and Local Network usage strings are declared in `Info.plist`
>   with plain-language descriptions of the medical-monitoring purpose.
> - All audio and video for distress / fall detection is processed **on
>   device** by `AIMonitoringService.swift` — no media is uploaded.
> - Only the user's own account record and incident metadata are synced to
>   our backend (Cloudflare Worker proxy to Supabase at
>   `https://agedcare-api.chrsappiah.cloud`) and to the user's private
>   CloudKit database (`iCloud.wcs.Agedcare-shared`).
> - Settings → Account → **Delete Account** invokes
>   `SessionViewModel.deleteAccountAndPurge()` which removes all server-side
>   records and local data — meeting guideline 5.1.1(v).
> - There are no third-party SDKs, no advertising IDs, no tracking.

---

## Guideline 5.1.1(v) — Account deletion

> Hello Review Team,
>
> The in-app account-deletion flow is at **Settings → Account → Delete
> Account**. It triggers `SessionViewModel.deleteAccountAndPurge()` which:
>
> 1. Deletes the user record and all linked rows from Supabase via the
>    backend `delete_account` RPC.
> 2. Removes the user's CloudKit zone in the private database.
> 3. Clears Keychain entries and on-device caches.
> 4. Signs the user out and returns them to the Hero Panel Router.
>
> No retention of personally-identifiable data after deletion.

---

## Guideline 1.4.1 — Safety / medical claims

> Hello Review Team,
>
> AgedCare Monitor is a **monitoring aid** for professional and family carers.
> It does not diagnose, treat, prevent or cure any disease. The app description
> and on-boarding screens explicitly state:
>
> *"AgedCare Monitor is a non-clinical monitoring aid. It does not replace
> professional medical advice or emergency services. In an emergency, call
> 000 (Australia) or your local emergency number."*
>
> The Stakeholder model (`StakeholderModel.swift`) classifies every contact
> as clinical or non-clinical and the app surfaces emergency call prompts
> before any monitoring alert that suggests possible harm.

---

## Tone reminders

- Always thank the reviewer.
- Quote the exact guideline number once, then explain compliance.
- Give one runnable path / file reference per claim.
- Never promise a feature you have not already built into the resubmitted
  build.
