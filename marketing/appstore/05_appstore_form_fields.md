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
- **Availability**: **All territories (not just 27 EU countries)**.
  - In App Store Connect → **Pricing and Availability** → set **Available in all territories**.
  - Do NOT select only 27 countries — there is no benefit to limiting. Select **all 175+ regions**.
  - No region-specific exclusions. The app is made available worldwide with no territorial restrictions.
- **EU-specific compliance**:
  - **GDPR**: Privacy policy at `https://wcs-full.vercel.app/privacy` covers EU data subject rights (access, erasure, portability, objection). Account deletion is available in-app at Settings → Account → Delete Account.
  - **Digital Services Act (DSA)**: Trader information (name, address, contact) is on file in the Apple Developer account under Christopher Appiah-Thompson, christopher.appiahthompson@myworldclass.org.
  - **VAT**: Pricing is set to **Free** (no charge for download). In-app subscription prices are managed through Apple's StoreKit and follow standard App Store EU VAT handling.
  - **EU Consumer Rights**: 14-day cooling-off period and right of withdrawal are handled by Apple's standard App Store refund process for paid subscriptions.
- **In-app purchases / subscriptions**:
  - `wcs.agedcare.carePro.monthly`  → Care Pro plan
  - `wcs.agedcare.careTeam.monthly` → Care Team plan
  - (Defined in `SubscriptionService.swift` and `SubscriptionTier`.)

## Pre-order setup (before submitting for App Review)

**Goal:** Enable pre-order for release on **May 26, 2026** in **all territories (or the 27 EU countries if preferred).**

**Important:** For a brand-new app (never released on any App Store), you must
configure pre-order **before** submitting for App Review, not after.

### Correct App Store Connect workflow

**Path:** App Store Connect → **Apps** → **AgedCare Monitor** → **Pricing and Availability** → **App Availability**

1. Click **Set Up Availability**
2. Select **Publish as Pre-Order** → **Next**
3. Set **Release Date** → **May 26, 2026** (must be 2–180 days from today)
4. Select **countries or regions** → you can choose **specific countries** (e.g. the 27 EU member states) or **all territories** → **Next**
5. Click **Confirm**
6. Return to **Pricing and Availability** → click the platform version **1.0.4 (118)**
7. Fill all required metadata, screenshots, age rating, app privacy
8. **Submit for App Review** (pre-order is attached to the submission)
9. After Apple approves → click **Release This Version** → **Confirm**
10. Pre-order appears on the App Store within 24 hours

### Why "An error has occurred. Try again later."

Possible causes:
- You tried to set pre-order from the version page instead of **Pricing and Availability → App Availability → Set Up Availability** (the correct entry point for a new app)
- You selected **Available in all territories** AND tried to set pre-order simultaneously — the correct flow is to use the **Set Up Availability** wizard which handles both at once
- Missing prerequisites: screenshots not uploaded, build not processed, or metadata incomplete
- Release date is less than 2 days away (today is May 24; May 26 is exactly 2 days — this should be fine)

**Fix:** Go to **Pricing and Availability → App Availability → Set Up Availability** and follow the wizard step by step. Do NOT use the "Available in all territories" toggle — use the **Publish as Pre-Order** wizard instead.

### After pre-order is live:
- Customers see "Pre-order" on the App Store listing
- Paid customers are **not charged** until May 26, 2026
- On release day, the app auto-downloads to pre-orderers' devices
- If you later release in additional territories, you cannot set up pre-order for those territories (once released, pre-order is unavailable there)

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
