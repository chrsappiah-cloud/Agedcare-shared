# App Store Connect — App Information form fields

Paste each block into the matching field at:
**App Store Connect → My Apps → AgedCare Monitor →
App Information / Pricing and Availability / Version Information**

All character counts assume the App Store Connect 2026 layout limits.

---

## Primary identity

| Field | Value |
|---|---|
| App name (30 char max) | **AgedCare Monitor** |
| Subtitle (30 char max) | **Dementia & Fall Monitoring** |
| Bundle ID | `wcs.Agedcare-shared` |
| SKU | `WCS-AGED-001` |
| Primary language | English (Australia) |
| Primary category | Medical |
| Secondary category | Health & Fitness |
| Content rights — third-party content? | **No** |

**App Store Connect blocker fixes:**

- **Primary category:** select **Medical**
- **Price tier:** select **Free**
- These fields are managed in the **App Information / Pricing and Availability**
  screens and must be saved in the browser by an account with the required App
  Store Connect role.

## Pricing & availability

- **Price tier**: Free (with in-app subscriptions for Care Pro / Care Team).
- **Availability**: All territories; **Australia first** for the pilot wave.
- **In-app purchases / subscriptions**:
  - `wcs.agedcare.carePro.monthly`  → Care Pro plan
  - `wcs.agedcare.careTeam.monthly` → Care Team plan
  - (Defined in `SubscriptionService.swift` and `SubscriptionTier`.)

## Promotional text (170 char max, can be updated without resubmission)

```
Track resident wellbeing in real time — Vision-based fall detection, distress-
sound monitoring, HomeKit room temperature and live local weather, all on
device, with optional cloud sync for care teams.
```

## App description (4 000 char max)

```
AgedCare Monitor is a non-clinical monitoring aid for professional carers,
family carers, and aged-care facility staff supporting residents living with
dementia, increased fall risk, or other care-intensive conditions.

Core capabilities
• On-device Vision fall detection using Apple Vision and CoreMotion — no
  video ever leaves the iPhone.
• Real-time audio distress-sound and keyword detection using SoundAnalysis
  and on-device Speech Recognition.
• Live resident room temperature via HomeKit-connected sensors and outdoor
  weather context via Open-Meteo.
• HealthKit integration for heart rate, blood oxygen and step-count trend
  observation (read-only).
• CloudKit private-database sync of incident records and an Apple Watch
  companion that surfaces alerts and SOS controls on the wrist.
• Multi-role dashboards: Administrator, Nurse, Carer and Family — each with
  a permission-scoped view.

How it is used
1. A bedside iPhone is placed in a resident's room and tapped into the
  Resident shell. It silently watches for falls and distress sounds.
2. Care staff and family use the Staff shell from their own iPhone to view
  the dashboard, respond to alerts, and review the resident timeline.
3. The Apple Watch companion mirrors the alert summary and the SOS button so
  carers can act without unlocking a phone.

Privacy by design
• Cameras and microphones are only opened when monitoring is explicitly
  enabled by a care worker.
• Audio and video analysis happens on device — clips are only persisted when
  an incident is detected and the care team chooses to retain them.
• Account deletion is one tap in Settings → Account → Delete Account.
• No third-party analytics, no advertising SDKs, no tracking.

This app is a monitoring aid, not a medical device. It does not diagnose,
treat or prevent any condition and is not a substitute for professional
medical advice or emergency services. In an emergency dial 000 (Australia)
or your local emergency number.
```

## Keywords (100 char max, comma separated, no spaces)

```
aged,care,dementia,monitor,fall,detection,HomeKit,SOS,carer,nurse,facility,family,resident,alert
```

## Support, marketing and privacy URLs

| Field | Value |
|---|---|
| Support URL | https://wcs-full.vercel.app/support |
| Marketing URL | https://wcs-full.vercel.app/apps/agedcare-shared |
| Privacy Policy URL | https://wcs-full.vercel.app/privacy |
| Copyright | © 2026 Worldclass Solutions (WCS) |

## Contact information (App Review only — not public)

| Field | Value |
|---|---|
| First name | Christopher |
| Last name | Appiah-Thompson |
| Phone | (provided in App Store Connect account; do not paste here) |
| Email | christopher.appiahthompson@myworldclass.org |
| Demo account email | admin@gvcare.com |
| Demo account password | password |
| Notes | See `marketing/appstore/01_review_notes.md` for the full reviewer walkthrough. |
