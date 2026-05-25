# App Store Submission — Readiness Checklist

**App:** AgedCare Monitor  
**Version:** 1.0.4  
**Build:** 118  
**Status:** Build uploaded, waiting for TestFlight processing  
**Last Updated:** 2026-05-23

---

## ✅ Pre-Upload Tasks (Completed)

- [x] **Xcode Project Configuration**
  - Marketing version: `1.0.4`
  - Build number: `118`
  - Team ID: `TM2WG7HH96`
  - Swift version: 5.0+

- [x] **Entitlements & Capabilities**
  - HealthKit (read + write)
  - HomeKit
  - CloudKit (private database)
  - Critical Messaging
  - WeatherKit
  - Background Modes (audio, processing, fetch)

- [x] **Build & Export**
  - Archive succeeded with Release configuration
  - ExportOptions.plist configured for App Store Connect
  - Code signing: Automatic (Apple Distribution certificate)
  - Symbols: Stripped and uploaded
  - Bitcode: Disabled (modern iOS doesn't require it)

- [x] **API Key Setup**
  - Key ID: `A863K5FF84`
  - Issuer: `70c46c69-5d6d-438d-b300-31df2b93163a`
  - Used for validation & upload via `xcrun altool`

- [x] **IPA Upload**
  - Validation passed (no errors)
  - Upload succeeded to App Store Connect
  - Build 1.0.4 (118) now in TestFlight (may still be processing)

---

## ⏳ Current Phase: TestFlight Processing

**Estimated Time:** 10–20 minutes after upload

- [ ] Refresh App Store Connect (hard refresh: Cmd+Shift+R)
- [ ] Navigate to **Agedcare-shared** → **TestFlight** → **Builds**
- [ ] Verify build 1.0.4 (118) appears
- [ ] Confirm no yellow warning triangles (if any, click to see error)
- [ ] Internal test group members notified (email auto-sent by Apple)

**If build doesn't appear after 20 min:**
1. Check build status in **Builds** tab → build number → **Details**
2. Look for error messages or "Waiting for App Store Connect"
3. If stuck, re-upload using `./scripts/local-release.sh`

---

## 🚀 Next Phase: Metadata Completion

Once TestFlight build is ready, complete these in order:

### Phase A: TestFlight Configuration

**Open:** App Store Connect → **Agedcare-shared** → **TestFlight** tab

| Task | Source | Status |
|------|--------|--------|
| **Export Compliance** | `08_distribution_review_responses.md` Section 1 | ⏳ |
| **What to Test** | `02_what_to_test.md` | ⏳ |
| **Beta App Review Notes** | `08_distribution_review_responses.md` Section 3 (if external testers) | ⏳ |

**Quick Paste:** All answers pre-written in `08_distribution_review_responses.md` (just copy & paste)

### Phase B: App Store Tab — Version 1.0.4

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → version **1.0.4**

#### Section 1: App Information

| Field | Value | Source |
|-------|-------|--------|
| **App Name** | AgedCare Monitor | `INFLIGHT_PASTE.txt` line 161 |
| **Subtitle** | Dementia & Fall Monitoring | `INFLIGHT_PASTE.txt` line 166 |
| **Primary Category** | Medical | `INFLIGHT_PASTE.txt` line 171 |
| **Secondary Category** | Health & Fitness | `INFLIGHT_PASTE.txt` line 176 |
| **Copyright** | © 2026 Worldclass Solutions (WCS) | `INFLIGHT_PASTE.txt` line 58 |
| **Content Rights** | No (no third-party content) | `INFLIGHT_PASTE.txt` line 181 |

**Status:** ⏳ Ready to paste

#### Section 2: Pricing and Availability

| Field | Value | Note |
|-------|-------|------|
| **Price Tier** | Free | Set to **Free** (monetize via in-app subscriptions: Care Pro / Care Team) |
| **Availability** | All territories (or select 27 EU countries) | You can choose specific territories for pre-order |
| **EU Compliance** | GDPR, DSA, VAT handled | Privacy policy covers EU rights; account deletion in-app; trader info on Apple Developer account |

**Action in App Store Connect (correct flow for a new app):**
1. Go to **Pricing and Availability** → **App Availability** → **Set Up Availability**
2. Select **Publish as Pre-Order** → **Next**
3. Set **Release Date** → **May 26, 2026** → **Next**
4. Select **countries or regions** (all territories, or just the 27 EU countries) → **Next**
5. Click **Confirm**
6. Return to **Pricing and Availability** → click platform version **1.0.4 (118)**
7. Fill all metadata then **Submit for App Review**
8. After approval → **Release This Version**

> ⚠️ For a brand-new app, pre-order MUST be configured via **App Availability** wizard BEFORE submitting for review — not from the version page.

**Status:** ⏳ Ready

#### Section 3: Version Release

| Field | Value | Note |
|-------|-------|------|
| **Release Type** | Automatic (on app approval) | Default |
| **Phased Release** | ON (for monitoring apps) | Safer rollout |
| **Manual Release** | OFF | Let Apple approve → auto-release |

**Status:** ⏳ Ready

#### Section 4: Description & Marketing

| Field | Value | Source | Length |
|-------|-------|--------|--------|
| **Promotional Text** | Track resident wellbeing... | `INFLIGHT_PASTE.txt` line 9 | 170 chars max ✅ |
| **Description** | AgedCare Monitor is a non-clinical... | `INFLIGHT_PASTE.txt` lines 14–35 | ~800 words ✅ |
| **Keywords** | aged,care,dementia,monitor... | `INFLIGHT_PASTE.txt` line 40 | ~100 chars max ✅ |
| **Support URL** | https://wcs-full.vercel.app/support | `INFLIGHT_PASTE.txt` line 45 | MUST be valid ⚠️ |
| **Marketing URL** | https://wcs-full.vercel.app/apps/agedcare-shared | `INFLIGHT_PASTE.txt` line 50 | MUST be valid ⚠️ |
| **Privacy Policy URL** | https://wcs-full.vercel.app/privacy | `INFLIGHT_PASTE.txt` line 53 | MUST be valid ⚠️ |

**Status:** ⏳ Ready to paste (URLs must be live)

#### Section 5: App Preview and Screenshots

| Item | Resolution | Count | Status |
|------|-----------|-------|--------|
| **Screenshots (6.7" iPhone)** | 1284 × 2778 (portrait) | 6 required | ⏳ Need to generate |
| **App Preview (optional)** | 1284 × 720 (portrait) or 1920 × 1080 (landscape) | 1 optional | ⏳ Optional |

**Generation Command:**

```bash
# Run simulator and capture screenshots
xcrun simctl list devices available | grep "iPhone 15 Pro Max"
# Use the UUID for commands below

# Hero Panel
xcrun simctl io <UUID> screenshot marketing/out/01_hero.png

# Resident Shell
xcrun simctl io <UUID> screenshot marketing/out/02_resident.png

# Staff Dashboard
xcrun simctl io <UUID> screenshot marketing/out/03_staff.png

# Alert Detail
xcrun simctl io <UUID> screenshot marketing/out/04_alert.png

# Subscription Tier
xcrun simctl io <UUID> screenshot marketing/out/05_subscription.png

# Watch Companion (if available)
xcrun simctl io <UUID> screenshot marketing/out/06_watch.png
```

**Status:** ⏳ Need to generate & upload

#### Section 6: Rating & Questionnaires

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → **Rating** section

| Questionnaire | Answer | Source |
|--------------|--------|--------|
| **Age Rating** | 17+ (Mature Content) | `06_age_rating_and_export.md` |
| **Entertainment Values** | N/A (monitoring app) | N/A |
| **Frequent/Intense Violence** | No | N/A |
| **Profanity or Crude Humor** | No | N/A |
| **Sexual Content or Nudity** | No | N/A |
| **Alcohol, Tobacco, Drugs** | No | N/A |

**Note:** 17+ is appropriate for a medical/monitoring app targeting professionals.

**Status:** ⏳ Ready to select

#### Section 7: App Privacy

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → **App Privacy**

| Data Category | Collected | Tracked | Purpose |
|---------------|-----------|---------|---------|
| **Camera** | Yes | No | Fall detection, incident photos |
| **Microphone** | Yes | No | Distress-sound detection |
| **Location** | Conditionally | No | Weather context (when in use) |
| **Contacts** | No | No | N/A |
| **Health** | Yes (HealthKit) | No | Vitals trends |
| **Financial Info** | No | No | N/A |
| **Search History** | No | No | N/A |

See `03_privacy_nutrition_label.md` for complete data collection matrix.

**Status:** ⏳ Ready to fill

#### Section 8: App Review Information

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → **App Review Information**

| Field | Value | Source |
|-------|-------|--------|
| **Sign-In Required** | Yes | `INFLIGHT_PASTE.txt` line 72 |
| **Demo Account Email** | admin@gvcare.com | `INFLIGHT_PASTE.txt` line 77 |
| **Demo Account Password** | password | `INFLIGHT_PASTE.txt` line 82 |
| **First Name** | Christopher | `INFLIGHT_PASTE.txt` line 87 |
| **Last Name** | Appiah-Thompson | `INFLIGHT_PASTE.txt` line 94 |
| **Phone Number** | (on file) | Use existing developer account |
| **Email** | christopher.appiahthompson@myworldclass.org | `INFLIGHT_PASTE.txt` line 104 |
| **Review Notes** | (entire block below) | `01_review_notes.md` |

**Review Notes to Paste:**
```
WHAT THIS APP DOES

AgedCare Monitor is a SwiftUI iOS and watchOS companion for professional carers, 
family carers, and aged-care facility staff monitoring residents with dementia or 
elevated fall risk. It combines on-device fall detection, audio distress monitoring, 
HomeKit room temperature, outdoor weather, and optional CloudKit sync.

HOW TO SIGN IN FOR REVIEW

The app opens on the Hero Panel Router (Resident and Staff cards, no network required).

Tap Staff, then Sign in:
  Administrator: admin@gvcare.com / password
  Nurse: nurse@gvcare.com / password
  Carer: carer@gvcare.com / password

Credentials are in DemoAccessProfile in AppHost.swift (local demo store). 
No iCloud, HomeKit hardware, Apple Watch, or live backend is required for review.

5-MINUTE REVIEW PATH

1. Launch — Hero Panel Router with Resident and Staff cards.
2. Resident — seeded demo resident (Dr Maria Hernandez), timeline, weather card.
3. Staff — sign in admin@gvcare.com / password.
4. Open any resident — timeline, alerts, settings.
5. Alerts — Add Alert — confirm it persists after relaunch.
6. Settings — About — marketing links.

PERMISSIONS (opt-in only, not on first launch)

Camera: fall detection and incident photos.
Microphone: distress-sound monitoring.
Speech Recognition: help-call keyword detection.
Face ID: staff authentication.
HealthKit: vitals trends.
HomeKit: room temperature sensors.
Location when in use: facility weather context.
Photo Library: incident attachments.

Sign in with Apple: not used.

Account deletion: Settings → Account → Delete Account (SessionViewModel.deleteAccountAndPurge).

Background modes: audio, location, fetch — opt-in per resident in staff settings.

Networking: 
  - https://agedcare-api.chrsappiah.cloud (API)
  - https://api.open-meteo.com (weather, no PII)
  - https://wcs-full.vercel.app (links)
  - iCloud.wcs.Agedcare-shared (private CloudKit)

Contact: christopher.appiahthompson@myworldclass.org
```

**Status:** ⏳ Ready to paste

#### Section 9: Build

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → version **1.0.4** → **+ Build**

| Item | Value | Status |
|------|-------|--------|
| **Build Version** | 1.0.4 (118) | ⏳ Wait for TestFlight processing, then select |
| **Include Watch App?** | Yes (if applicable) | ⏳ Select watchOS build if available |

**Action:**
1. Click **+ Build** button
2. Select **1.0.4 (118)** from dropdown
3. Click **Done**

**Status:** ⏳ Ready after TestFlight processing

#### Section 10: Export Compliance (Encryption)

**Open:** App Store Connect → **Agedcare-shared** → **TestFlight** tab → **Builds** → **1.0.4 (118)** → **Manage**

| Question | Answer | Justification |
|----------|--------|----------------|
| **Does this app use encryption?** | Yes | HTTPS/TLS for API calls |
| **Is it exempt?** | Yes | Standard HTTPS/TLS + Apple OS encryption |
| **Proprietary encryption?** | No | No custom encryption algorithms |

**Note:** `ITSAppUsesNonExemptEncryption = false` in Info.plist auto-fills this.

**Status:** ⏳ Ready to submit (auto-filled likely)

---

## 📋 Pre-"Submit for Review" Verification

Before clicking the final "Submit for Review" button:

### ✅ Metadata Audit

- [ ] App name: "AgedCare Monitor" (exactly as in App Store Connect)
- [ ] Subtitle: "Dementia & Fall Monitoring"
- [ ] Description: Starts with "AgedCare Monitor is a non-clinical monitoring aid..."
- [ ] Keywords: Contains "aged,care,dementia,monitor,fall,detection,..." (no spaces)
- [ ] Promotional text: Starts with "Track resident wellbeing in real time..." (170 chars max)
- [ ] Support URL: `https://wcs-full.vercel.app/support` (returns 200 OK)
- [ ] Marketing URL: `https://wcs-full.vercel.app/apps/agedcare-shared` (returns 200 OK)
- [ ] Privacy Policy URL: `https://wcs-full.vercel.app/privacy` (returns 200 OK)
- [ ] Copyright: "© 2026 Worldclass Solutions (WCS)"

### ✅ Build Verification

- [ ] Build 1.0.4 (118) appears in TestFlight (no yellow warnings)
- [ ] Build status: "Ready to Submit" or similar (not "Processing")
- [ ] IPA size reasonable (~100–300 MB typical for iOS apps)
- [ ] All frameworks linked (CoreML for vision, etc.)

### ✅ Capability Verification

- [ ] App Privacy: Data disclosures filled (Camera, Microphone, Location, Health)
- [ ] Age Rating: 17+ selected
- [ ] App Review Information: Demo account, contact, review notes all present
- [ ] Export Compliance: Encryption answers filled (TestFlight → Manage)

### ✅ Screenshots & Preview

- [ ] 6 screenshots uploaded for 6.7" iPhone (1284 × 2778 each)
- [ ] Screenshots are labeled/captioned (optional but recommended)
- [ ] App Preview uploaded (optional)
- [ ] All images are crisp and readable

### ✅ Contact & Legal

- [ ] Contact name: Christopher Appiah-Thompson
- [ ] Contact email: christopher.appiahthompson@myworldclass.org
- [ ] Phone number: Present (from developer account)
- [ ] Privacy Policy live and accessible
- [ ] Support page live and accessible

### ✅ Release Settings

- [ ] Phased Release: **Enabled** (safe rollout for monitoring app)
- [ ] Manual Release: **Disabled** (auto-release on approval)
- [ ] Release Notes (What's New): Filled in (`INFLIGHT_PASTE.txt` line 65)

---

## 🚨 Common Blockers (Check Before Submit)

| Blocker | Impact | Fix |
|---------|--------|-----|
| URLs return 404 | **REJECTION** | Fix URLs on marketing site before submit |
| No build attached | **CANNOT SUBMIT** | Click **+ Build** and select 1.0.4 (118) |
| Age rating missing | **CANNOT SUBMIT** | Select 17+ in Rating section |
| Privacy nutrition empty | **CANNOT SUBMIT** | Fill in App Privacy with all data categories |
| Review notes empty | **LIKELY REJECTION** | Paste from `01_review_notes.md` |
| Demo account doesn't work | **REJECTION** | Test locally: sign in with admin@gvcare.com / password |
| Screenshots wrong size | **REJECTION** | Regenerate at exactly 1284 × 2778 |

---

## 📞 Submission Timeline

| Phase | Estimated Time | Notes |
|-------|-----------------|-------|
| **1. TestFlight Processing** | 10–20 min | After build upload |
| **2. Metadata Completion** | 30–60 min | Paste all text, fill dropdowns |
| **3. Screenshot Generation** | 15–30 min | Run simulator, capture images |
| **4. Final Audit** | 10–15 min | Verify all sections |
| **5. Submit for Review** | 1 min | Click button (irreversible) |
| **6. Apple Review Queue** | 24–48 hours typical | May be longer during holidays |
| **7. Decision** | Email notification | Approve, reject, or ask for info |

**Total Elapsed (from now):** ~2–3 hours active work + 1–2 days Apple review

---

## ✨ Success Criteria

App is approved when:
- ✅ No rejection emails in Resolution Center
- ✅ Status changes to "Ready for Sale" or "Pending Release"
- ✅ Build appears in App Store → All Versions
- ✅ App is downloadable by the public (or phased rollout begins)

**Next Actions After Approval:**
1. Monitor crashes in App Analytics
2. Publish App Store screenshots to marketing site
3. Tag the release: `git tag v1.0.4 && git push --tags`
4. Announce on social media / email list
5. Monitor user feedback and ratings

---

Generated: 2026-05-23  
Version: 1.0.4 (118)  
Next Step: Wait for TestFlight processing, then complete metadata
