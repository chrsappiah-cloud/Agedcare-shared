# Distribution & App Review — copy-paste responses

Use this file when completing **TestFlight distribution**, **export compliance**,
**age rating**, **App Privacy**, and **App Store / Beta App Review** in
[App Store Connect](https://appstoreconnect.apple.com/apps/6767978725).

App: **AgedCare Monitor** · Bundle `wcs.Agedcare-shared` · Version **1.0.4** · Build **117**

Open the right screens:

```bash
./scripts/open-distribution-review.sh
```

---

## 1. TestFlight — Export compliance (build 117)

**Path:** TestFlight → iOS → Build **117** → Manage → Export Compliance

| Question | Answer |
|----------|--------|
| Is your app designed to use cryptography or does it contain cryptography? | **Yes** |
| Is your app exempt? | **Yes** |
| Exemption type | Standard encryption only (HTTPS/TLS, Apple OS crypto) |
| Uses proprietary encryption? | **No** |
| Implements encryption beyond OS-provided? | **No** |
| Annual self-classification report required? | **No** |

**Short justification (if free-text):**

> The app uses only Apple-provided encryption (URLSession TLS, CloudKit,
> Keychain, CryptoKit). No proprietary algorithms. Qualifies for Category 5 Part 2
> exemption (b) authentication over HTTPS and (d) OS-provided encryption only.

**Info.plist:** `ITSAppUsesNonExemptEncryption = false` is set so future uploads
may skip this prompt after the first confirmation.

---

## 2. TestFlight — What to Test (en-US)

Paste from `02_what_to_test.md` (build **1.0.4 (117)** section).

---

## 3. TestFlight — Beta App Review (external testers)

**Path:** TestFlight → External Testing → Group → Submit for Beta App Review

**Beta App Review contact:** same as App Review (Christopher Appiah-Thompson,
christopher.appiahthompson@myworldclass.org).

**Beta App Review notes:**

```
AgedCare Monitor is a carer monitoring app (iOS + watchOS). No sign-in is
required on first launch — the Hero Panel Router offers Resident and Staff paths.

Staff demo (no live backend required):
  Email: admin@gvcare.com
  Password: password
  (Also: nurse@gvcare.com, carer@gvcare.com — same password)

Resident path shows a seeded demo resident with timeline, weather, and SOS.

Monitoring (camera, mic, HealthKit, HomeKit, location) is opt-in per feature in
staff settings — not requested on first launch.

This build (1.0.4 / 117) is the App Store submission candidate. Export
compliance: standard HTTPS/TLS only, exempt encryption.
```

**Sign-in required for review:** **Yes** (demo account above).

**Encryption:** Same as Section 1 — exempt, standard HTTPS only.

---

## 4. Age Rating questionnaire

**Path:** App Information → Age Rating → Edit

| Question | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature / Suggestive Themes | None |
| Horror / Fear Themes | None |
| **Medical / Treatment Information** | **Frequent / Intense** |
| Alcohol, Tobacco, or Drug Use or References | Infrequent / Mild (medication-reminder context only) |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Contests | None |
| Unrestricted Web Access | **No** |
| Gambling and Contests | None |

**Expected computed rating:** **17+**

**Made for Kids:** **No**

---

## 5. App Privacy (nutrition label)

**Path:** App Privacy → Get Started / Edit

**Collect data?** **Yes**

### Data types (linked / not linked)

| Category | Data | Purposes | Linked | Tracking |
|----------|------|----------|--------|----------|
| Contact Info | Email | App Functionality | Yes | No |
| Contact Info | Name | App Functionality | Yes | No |
| Health & Fitness | Heart rate, SpO₂, steps | App Functionality, Product Personalization | Yes | No |
| User Content | Photos, videos | App Functionality | Yes | No |
| User Content | Audio | App Functionality | **No** | No |
| Identifiers | User ID (CloudKit) | App Functionality | Yes | No |
| Diagnostics | Crash logs | App Functionality | No | No |
| Diagnostics | Performance data | App Functionality, Analytics | No | No |

**Do NOT collect:** Location (persisted/transmitted), browsing history, financial
info, contacts, sensitive info.

**Tracking:** **No** (no third-party SDKs, no ad IDs).

**Account deletion in-app:** **Yes** — Settings → Account → Delete Account.

---

## 6. App Store version 1.0.4 — metadata

Paste from `05_appstore_form_fields.md`:

- Name, subtitle, description, keywords, URLs, copyright
- Primary category: **Medical** · Secondary: **Health & Fitness**
- Price: **Free** (subscriptions via StoreKit)

**Content rights — third-party content:** **No**

**Phased release:** **On** (automatic updates after approval)

**Manual release:** **Off** (unless you have a fixed marketing date)

---

## 7. App Review Information

**Path:** App Store → Version 1.0.4 → App Review Information

| Field | Value |
|-------|-------|
| Sign-in required | **Yes** |
| Demo account username | `admin@gvcare.com` |
| Demo account password | `password` |
| Contact email | `christopher.appiahthompson@myworldclass.org` |
| Notes | Paste full text from `01_review_notes.md` |

**Attachment (optional):** none required — demo works offline.

---

## 8. Distribution — Content & compliance declarations

When App Store Connect asks during **Submit for Review**:

| Declaration | Answer |
|---------------|--------|
| Export compliance (US encryption) | Uses encryption, **exempt** (standard HTTPS / Apple frameworks only) |
| IDFA / tracking | **No** — app does not track users |
| Third-party content | **No** |
| Government app | **No** |
| Gambling | **No** |
| VPN / proxy | **No** |

**Medical / health positioning (if asked):**

> Non-clinical monitoring aid. Does not diagnose, treat, or cure disease. Not a
> medical device. Users must call emergency services (000 in Australia) in an
> emergency.

---

## 9. Attach build & submit for App Store Review

**Path:** App Store → iOS App → Version **1.0.4** → Build

1. **+** → select build **117** (processing must be complete).
2. Confirm screenshots (6.7" iPhone minimum) — see `marketing/out/`.
3. Complete all yellow warnings (export, privacy, age rating, review info).
4. **Add for Review** → **Submit to App Review**.
5. **Phased Release for Automatic Updates:** **Enable**.

---

## 10. Resolution Center — first response (if rejected)

Use the matching template in `04_rejection_response_templates.md` by guideline
number. Default for “can’t sign in / blank screen”:

```
Hello Review Team,

Thank you for the feedback. AgedCare Monitor opens on the Hero Panel Router
(no network required). Tap Staff → Sign in:

  Email: admin@gvcare.com
  Password: password

Seeded demo facility in AppHost.swift — no live backend required.

Re-verified on iPhone 17 Pro Max, iOS 26.5, build 1.0.4 (117).

Best regards,
Christopher Appiah-Thompson
```

---

## 11. Checklist before you click Submit

- [ ] Build **117** processed in TestFlight (no “Processing” badge)
- [ ] Export compliance saved (Section 1)
- [ ] Age rating **17+** saved (Section 4)
- [ ] App Privacy published (Section 5)
- [ ] Screenshots uploaded for 6.7" display
- [ ] Build **117** attached to version **1.0.4**
- [ ] App Review notes + demo account filled (Section 7)
- [ ] Phased release enabled (Section 6)

---

## Quick reference — entitlements driving review questions

| Capability | Why declared |
|------------|----------------|
| HealthKit + health-records | Vitals trend / anomaly detection |
| HomeKit | Room temperature sensors |
| WeatherKit | Outdoor weather context |
| CloudKit | Private incident sync |
| Critical Messaging | Time-sensitive SOS / fall alerts to carers |
| Push (production) | CloudKit subscription wake-up |
| Background: audio, processing, remote-notification | Distress monitoring, sync retries |
