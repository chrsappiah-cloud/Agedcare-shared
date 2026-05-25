# AgedCare Monitor — Apple App Store Distribution Guide

**Status:** Build 1.0.4 (118) uploaded to TestFlight  
**Team ID:** TM2WG7HH96  
**Bundle ID:** `wcs.Agedcare-shared`  
**Last Updated:** 2026-05-23

---

## 📋 Quick Submission Status

| Item | Status | Notes |
|------|--------|-------|
| Build uploaded | ✅ | 1.0.4 (118) — waiting for TestFlight processing (~15 min) |
| Xcode project ready | ✅ | ExportOptions.plist + Release entitlements configured |
| Review notes | ✅ | Detailed walkthrough, demo credentials, permission explanations |
| Privacy nutrition label | ✅ | App Tracking Transparency, location, contacts, health data |
| Age rating | ✅ | 17+ (mature content disclosure) |
| Screenshots | ⏳ | Use provided generation scripts in `marketing/` |
| Metadata | ⏳ | Paste from `INFLIGHT_PASTE.txt` into App Store Connect |
| Test completion | ⏳ | Internal testers should confirm functionality |

---

## 🚀 Submission Checklist (In Order)

### Phase 1: Pre-Submission (Local Preparation) — **DONE**

- [x] App Store Connect API key generated (ID: `A863K5FF84`)
- [x] `MARKETING_VERSION=1.0.4`, `CURRENT_PROJECT_VERSION=118` set
- [x] Local archive + export succeeded
- [x] Build 1.0.4 (118) uploaded to App Store Connect
- [x] `ExportOptions.plist` configured for App Store Connect distribution
- [x] Release entitlements (`Agedcare_shared_release.entitlements`) signed with team ID `TM2WG7HH96`

### Phase 2: TestFlight Processing — **IN PROGRESS**

**Wait ~15 minutes for the build to process in TestFlight, then:**

- [ ] Open App Store Connect and navigate to **Agedcare-shared** → **TestFlight**
- [ ] Confirm build 1.0.4 (118) appears (may show "Processing…" initially)
- [ ] Internal test group invited (max 100 testers)
- [ ] At least one tester installs, signs in with `admin@gvcare.com` / `password`, and creates an alert

**Copy-paste the following into TestFlight:**

- **Export Compliance Section:** See `08_distribution_review_responses.md` Section 1 or below
- **What to Test:** See `02_what_to_test.md`
- **Beta App Review Notes (if external testers):** See `08_distribution_review_responses.md` Section 3

### Phase 3: App Store Metadata — **READY TO START**

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → version **1.0.4**

| Metadata | Source | Instructions |
|----------|--------|--------------|
| **App Information** | `INFLIGHT_PASTE.txt` lines 159–183 | Copy app name, subtitle, category into "App Information" tab |
| **Description** | `INFLIGHT_PASTE.txt` lines 12–36 | Paste into "Description" field |
| **Promotional Text** | `INFLIGHT_PASTE.txt` lines 7–10 | 170 characters max |
| **Keywords** | `INFLIGHT_PASTE.txt` lines 38–40 | Comma-separated, no spaces |
| **Support / Marketing / Privacy URLs** | `INFLIGHT_PASTE.txt` lines 43–53 | Copy all three URLs |
| **Copyright** | `INFLIGHT_PASTE.txt` line 58 | `© 2026 Worldclass Solutions (WCS)` |
| **What's New in This Version** | `INFLIGHT_PASTE.txt` line 63–65 | Release notes for v1.0.4 |

**Click "Save" after each section.**

### Phase 4: App Privacy & Permissions — **READY TO START**

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → **App Privacy**

See `03_privacy_nutrition_label.md` for the complete nutrition label in iOS app privacy format:
- **Camera** — required only when fall detection is enabled
- **Microphone** — required for distress-sound monitoring
- **Location** — when in use, for facility weather context
- **HealthKit** — vitals trends (read-only)
- **CloudKit** — private incident records
- **Photo Library** — attach photos to incidents
- **Face ID** — staff authentication

### Phase 5: Age Rating — **READY TO START**

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → **Age Rating**

- **Set to 17+ (Mature Content)**
- See `06_age_rating_and_export.md` for questionnaire responses
- Keywords: dementia, fall risk, medical monitoring (not age-restricted content, but professional/clinical context)

### Phase 6: App Review Information — **READY TO START**

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → **App Review Information**

| Field | Value | Source |
|-------|-------|--------|
| **Sign-In Required** | Yes | `INFLIGHT_PASTE.txt` line 72 |
| **Demo Account Email** | `admin@gvcare.com` | `INFLIGHT_PASTE.txt` line 77 |
| **Demo Account Password** | `password` | `INFLIGHT_PASTE.txt` line 82 |
| **Contact Name** | Christopher Appiah-Thompson | `INFLIGHT_PASTE.txt` lines 87–94 |
| **Contact Email** | christopher.appiahthompson@myworldclass.org | `INFLIGHT_PASTE.txt` line 104 |
| **Review Notes** | Paste entire block | `INFLIGHT_PASTE.txt` lines 109–152 / `01_review_notes.md` |

### Phase 7: Screenshots — **READY TO START**

**Requirements:**
- Minimum 6.7" iPhone (1284 × 2778 pixels, portrait)
- Upload for iOS 17+ and watchOS 10+ if applicable
- Text on screenshots must be readable (size 28pt+ recommended)

**Generate screenshots from your simulator:**

```bash
# List available simulator UUIDs
xcrun simctl list devices

# Take a screenshot for a specific simulator
xcrun simctl io <UUID> screenshot marketing/out/hero_panel.png
```

**Recommended set (upload in order):**

1. **Hero panel router** — Shows "Resident" and "Staff" cards
   - *What it demonstrates:* No sign-in required for first-time users
   
2. **Resident shell** — Weather card, SOS button, demo resident (Dr Maria Hernandez)
   - *What it demonstrates:* Bedside monitoring view
   
3. **Staff residents list** — After signing in with `admin@gvcare.com`
   - *What it demonstrates:* Multi-resident dashboard for carers
   
4. **Alert detail view** — Tap any alert to show timeline
   - *What it demonstrates:* Incident history and metadata
   
5. **Settings → Subscription tier** — Shows Care Team / Care Pro options
   - *What it demonstrates:* In-app purchase / subscription tier selection
   
6. **Watch companion** — Alert summary and SOS button (optional but impressive)
   - *What it demonstrates:* Wrist-based monitoring capabilities

**Upload to App Store Connect:**
1. Go to **Agedcare-shared** → **App Store** tab → **Screenshots**
2. Select the 6.7" iPhone size class
3. Upload your 6 screenshots in order
4. Add preview text below each screenshot (e.g., "Monitor from your Apple Watch")

### Phase 8: Build Attachment — **READY TO START**

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → version **1.0.4**

1. Click **+ Build** (near the top)
2. Select build **1.0.4 (118)** from the dropdown (or latest CI build if different)
3. Confirm the build appears in the version overview
4. Save

### Phase 8b: Pre-Order Setup (Must Be Done BEFORE Submission)

**Important:** For a brand-new app (never released), pre-order must be configured
**before** submitting for App Review — not after.

**Path:** App Store Connect → **Agedcare-shared** → **Pricing and Availability** → **App Availability**

**Correct workflow (use the wizard, not the toggles):**

1. Click **Set Up Availability**
2. Select **Publish as Pre-Order** → **Next**
3. Set **Release Date** → **May 26, 2026** (2–180 days from today)
4. Select **countries or regions** (all territories, or just 27 EU countries) → **Next**
5. Click **Confirm**
6. Return to **Pricing and Availability** → click platform version **1.0.4 (118)**
7. Complete all metadata, then **Submit for App Review**
8. After Apple approves → **Release This Version** → **Confirm**
9. Pre-order appears on App Store (up to 24 hours)

> ⚠️ If you got "An error has occurred. Try again later.", you likely tried to
> set pre-order from the version page toggles instead of the **App Availability**
> wizard. Go to **Pricing and Availability → App Availability → Set Up Availability**
> and follow the wizard instead.

### Phase 9: Submission — **FINAL STEP**

**Open:** App Store Connect → **Agedcare-shared** → **App Store** tab → version **1.0.4**

1. Click the blue **Submit for Review** button (bottom right)
2. Review the **Distribution Declaration** checklist:
   - [ ] **Kids Under 13?** No (audience is carers/staff)
   - [ ] **Third-party SDKs?** No (Supabase is backend, not SDK in app)
   - [ ] **Encryption?** Yes — standard HTTPS/TLS (see below)
   - [ ] **Health data?** Yes — HealthKit vitals (read-only)
   - [ ] **HomeKit?** Yes — temperature sensors (read-only)
3. Check **Phased Release** (recommended for monitoring apps to limit blast radius)
4. Leave **Manual Release** unchecked (auto-release on approval)
5. Click **Submit**

**Encryption Declaration (App Store Connect → Build → Manage → Encryption):**
- **Uses encryption:** Yes
- **Encryption exempt:** Yes (standard HTTPS/TLS and Apple OS encryption only)
- **Proprietary encryption:** No

### Phase 10: Post-Submission — **AFTER APPROVAL**

- [ ] Watch the **Resolution Center** for reviewer messages
- [ ] If **rejected**, review `04_rejection_response_templates.md` for canned responses
- [ ] On **approval**, monitor **App Analytics** for crashes and subscriber reports
- [ ] First-day plan: capture screenshots of the App Store listing for marketing

---

## 📦 What's in the Build

### App Bundle Configuration

| Config | Value | File |
|--------|-------|------|
| **Bundle ID** | `wcs.Agedcare-shared` | project.pbxproj |
| **Marketing Version** | 1.0.4 | project.pbxproj |
| **Build Number** | 118 | project.pbxproj |
| **Team ID** | TM2WG7HH96 | ExportOptions.plist |
| **Signing Certificate** | Apple Distribution | ExportOptions.plist |
| **Entitlements** | Agedcare_shared_release.entitlements | Xcode project |

### Capabilities Enabled (in entitlements)

- ✅ **HealthKit** — vitals trends
- ✅ **HomeKit** — temperature sensors
- ✅ **CloudKit** — incident records (private database: `iCloud.wcs.Agedcare-shared`)
- ✅ **Critical Messaging** — time-sensitive alerts
- ✅ **WeatherKit** — outdoor conditions
- ✅ **Background Modes** — audio, fetch, processing

### Privacy & Permissions Declared

| Permission | Used For | Opt-In | Notes |
|------------|----------|--------|-------|
| **Camera** | Fall detection, room monitoring, incident photos | Yes | Only when monitoring enabled |
| **Microphone** | Distress-sound detection | Yes | Only when monitoring enabled |
| **Speech Recognition** | Transcribe help calls | Yes | On-device only |
| **Face ID** | Staff authentication | Yes | Security |
| **HealthKit (read)** | Heart rate, SpO₂, step trends | Yes | Not required |
| **HomeKit** | Room temperature | Yes | Not required |
| **Location (when in use)** | Facility weather context | Yes | Not required |
| **Photo Library** | Attach images to incidents | Yes | Not required |

**No third-party analytics, no tracking SDKs, no Sign in with Apple.**

---

## 🔐 Security Certificates & Provisioning

### Distribution Certificate Status

- **Signing Style:** Automatic (Xcode manages certificates)
- **Certificate Type:** Apple Distribution (`iOS Distribution`)
- **Team ID:** TM2WG7HH96
- **Expires:** Check App Store Connect → Certificates, Identifiers & Profiles → Certificates

### Provisioning Profile Status

- **Profile Name:** `wcs.Agedcare-shared` (App Store Distribution)
- **Type:** App Store (Production)
- **Team ID:** TM2WG7HH96
- **Auto-managed:** Yes (ExportOptions.plist sets `signingStyle: automatic`)

### API Key Status

- **API Key ID:** `A863K5FF84`
- **Issuer ID:** `70c46c69-5d6d-438d-b300-31df2b93163a`
- **Usage:** Used for `xcrun altool` validation/upload from CLI
- **Note:** Add `AuthKey_A863K5FF84.p8` to GitHub Secrets for CI/CD (`cd.yml` workflow)

---

## 🧪 Pre-Submission Verification

Run these checks before clicking "Submit for Review":

### 1. Local Build Test

```bash
cd /Applications/Agedcare-shared

# Clean build
xcodebuild clean -scheme Agedcare-shared

# Archive
xcodebuild archive \
  -project Agedcare-shared.xcodeproj \
  -scheme Agedcare-shared \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/test-archive.xcarchive

# Validate IPA (after export)
xcrun altool --validate-app --type ios --file /tmp/Agedcare-shared.ipa \
  --apiKey A863K5FF84 --apiIssuer 70c46c69-5d6d-438d-b300-31df2b93163a
```

### 2. TestFlight Verification

- [ ] Internal testers can install without errors
- [ ] Sign-in works with demo account (`admin@gvcare.com` / `password`)
- [ ] Alerts can be created and persist after app restart
- [ ] No crashes in the first 5 minutes of use
- [ ] No privacy/camera/microphone permission crashes

### 3. App Store Metadata Validation

- [ ] All required fields are filled (no empty mandatory fields)
- [ ] App name, keywords, and description match marketing copy
- [ ] URLs are valid and return 200 OK (Support, Marketing, Privacy Policy)
- [ ] Screenshots are correct resolution (1284 × 2778 for 6.7")
- [ ] Contact email matches Apple Developer account

---

## 🛠️ Troubleshooting & Common Issues

### "Build is still processing"

**Issue:** Build doesn't appear in TestFlight after 20 minutes.

**Solution:**
1. Refresh App Store Connect (hard refresh: Cmd+Shift+R)
2. Check the build status in **TestFlight** → **Builds** tab
3. If it shows a yellow warning triangle, click it to see the error
4. Common causes: entitlements mismatch, expired certificate, provisioning profile issue
5. Fallback: Re-run `./scripts/local-release.sh` to re-upload

### "Export Compliance not showing"

**Issue:** Export Compliance section doesn't appear after build processes.

**Solution:**
1. Go to **TestFlight** → **Builds** → **1.0.4 (118)** → **Manage**
2. Click **Export Compliance** (may be a separate section)
3. Fill in: "Uses encryption: Yes, Exempt: Yes, Proprietary: No"
4. If still not showing, the system auto-filled it based on `ITSAppUsesNonExemptEncryption` in Info.plist

### "Screenshot upload fails"

**Issue:** Uploading screenshots returns an error.

**Solution:**
1. Verify resolution: Must be exactly **1284 × 2778** for 6.7" iPhone (portrait)
2. File format: PNG or JPG only
3. File size: Under 5 MB per image
4. If still failing: Try a different size class (5.5" or 6.5") first, then re-add 6.7"
5. Generate with: `xcrun simctl io <UUID> screenshot file.png` for pixel-perfect resolution

### "Rejected for guideline 5.1.1 (Account Deletion)"

**Issue:** Apple rejects due to account deletion not being obvious.

**Solution:**
1. Account deletion is already in **Settings → Account → Delete Account**
2. Reply using template in `04_rejection_response_templates.md` → "Account Deletion"
3. Provide a screenshot showing the delete button and the confirmation prompt
4. Reference: `SessionViewModel.deleteAccountAndPurge()` in code

### "Rejected for Health data without medical claim"

**Issue:** Apple rejects HealthKit integration without medical disclaimers.

**Solution:**
1. Disclaimer is already in the App Store description: *"This app is a monitoring aid, not a medical device..."*
2. Reply using template in `04_rejection_response_templates.md` → "Health Data Claims"
3. Add the disclaimer prominently in **Settings → About** if needed

---

## 📞 Support & Escalation

**Reviewer Support Contact:**
- **Name:** Christopher Appiah-Thompson
- **Email:** christopher.appiahthompson@myworldclass.org
- **Phone:** (See App Store Connect account details)

**Team Development Team:**
- **Team ID:** TM2WG7HH96
- **Coordinator:** Christopher Appiah-Thompson

**In Case of Urgent Rejection:**
1. Check the **Resolution Center** for specific rejection reasons
2. Use the appropriate template in `04_rejection_response_templates.md`
3. Reply with screenshot evidence and/or code references
4. Resubmit with updated build if code changes were required

---

## 📚 Reference Documents

| Document | Purpose | Location |
|----------|---------|----------|
| **01_review_notes.md** | What the app does, demo account, test path | `marketing/appstore/` |
| **02_what_to_test.md** | TestFlight testing instructions | `marketing/appstore/` |
| **03_privacy_nutrition_label.md** | Data collection & tracking disclosures | `marketing/appstore/` |
| **04_rejection_response_templates.md** | Canned replies for common rejections | `marketing/appstore/` |
| **05_appstore_form_fields.md** | App Store metadata (name, subtitle, description) | `marketing/appstore/` |
| **06_age_rating_and_export.md** | ESRB rating + export compliance | `marketing/appstore/` |
| **07_submission_checklist.md** | Step-by-step before clicking Submit | `marketing/appstore/` |
| **08_distribution_review_responses.md** | Complete questionnaire answers | `marketing/appstore/` |
| **INFLIGHT_PASTE.txt** | Ready-to-paste metadata for current build | `marketing/appstore/` |
| **SUBMIT_NOW.md** | Quick reference for this phase | `marketing/appstore/` |
| **ExportOptions.plist** | Xcode export configuration (App Store Connect) | Project root |
| **Agedcare_shared_release.entitlements** | Signed capabilities for production | `Agedcare-shared/` |
| **local-release.sh** | Build & upload script | `scripts/` |

---

## ✅ Final Checklist Before "Submit for Review"

- [ ] Build 1.0.4 (118) processed in TestFlight (no yellow warnings)
- [ ] App name, subtitle, description, and keywords filled
- [ ] Support, Marketing, and Privacy Policy URLs valid
- [ ] Copyright year set to 2026
- [ ] Promotional text filled (170 characters max)
- [ ] What's New in This Version filled
- [ ] App Privacy nutrition label complete (Camera, Microphone, Location, HealthKit)
- [ ] Age rating set to 17+ (Mature Content)
- [ ] Demo account credentials filled (`admin@gvcare.com` / `password`)
- [ ] Contact information up to date
- [ ] App Review notes complete (entire block from `01_review_notes.md`)
- [ ] Screenshots uploaded (6 × 1284 × 2778 portrait)
- [ ] Build attached (version 1.0.4, build 118)
- [ ] Export Compliance answered (Encryption: Yes, Exempt: Yes)
- [ ] Distribution Declaration filled (Health data, HomeKit, no kids content)
- [ ] Internal testers confirmed functionality
- [ ] Phased Release enabled (for monitoring app safety)
- [ ] Manual Release disabled (auto-release on approval)

---

## 🎉 After Approval

1. **Monitor Crashes** — App Analytics → Crashes & Sessions
2. **Check Subscriber Reports** — App Analytics → Subscriber Reports
3. **Update Marketing Site** — Add screenshots to wcs-full.vercel.app
4. **Public Announcement** — Blog post, social media, email list
5. **Tag Release** — `git tag v1.0.4 && git push --tags` (triggers CD workflow)
6. **Future Submissions** — CI/CD via `cd.yml` (requires AuthKey in GitHub Secrets)

---

Generated: 2026-05-23  
Build: 1.0.4 (118)  
Status: Ready for metadata completion & submission
