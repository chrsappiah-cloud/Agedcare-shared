# Submission checklist — Agedcare-shared

Run through this list in order before clicking **Submit for Review** in
App Store Connect. Tick each item.

---

## Pre-submission (you, locally)

- [ ] App Store Connect API key rotated; old key revoked
- [ ] `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_BASE64` saved in
      GitHub repo secrets (production environment)
- [ ] PR #1 reviewed (CodeQL, CodeRabbit) and squash-merged to `main`
- [x] `MARKETING_VERSION` agreed (`1.0.4`)
- [x] `CURRENT_PROJECT_VERSION` higher than the last accepted TestFlight
      build (`117`)

## Build & upload

- [x] Archive + export succeeded locally (clean bundle, system `rsync` PATH)
- [x] **1.0.4 (117)** uploaded to App Store Connect (2026-05-22, Xcode session)
- [ ] `ASC_PRIVATE_KEY` in GitHub (for CI `cd.yml` on future tags)
- [ ] Build **processed** in TestFlight (check App Store Connect — ~15 min)

## TestFlight (you, in App Store Connect)

Use **`08_distribution_review_responses.md`** for every answer below.

- [ ] Build processed (no yellow warning triangle)
- [ ] Export Compliance answered (Section 1 — or auto via `ITSAppUsesNonExemptEncryption`)
- [ ] "What to Test" copied (Section 2 / `02_what_to_test.md`)
- [ ] Beta App Review notes filled if using external testers (Section 3)
- [ ] Internal test group invited (max 100); external group submitted for
      Beta App Review if you need more testers
- [ ] At least one tester confirms install + sign-in + alert creation

## App Store metadata (you, in App Store Connect → App Store tab)

- [ ] App name, subtitle, category, copyright filled per
      `05_appstore_form_fields.md`
- [ ] Promotional text + Description + Keywords filled
- [ ] Support URL, Marketing URL, Privacy Policy URL filled
- [ ] **App Privacy** nutrition label (Section 5 / `03_privacy_nutrition_label.md`)
- [ ] **Age Rating** → **17+** (Section 4 / `06_age_rating_and_export.md`)
- [ ] **App Review Information** (Section 7 / `01_review_notes.md`)
- [ ] Distribution declarations at submit (Section 8 in `08_…`)
- [ ] Demo account email + password filled (`admin@gvcare.com` / `password`)
- [ ] Sign-in required toggled **On**
- [ ] Contact information current

## Screenshots (you, in App Store Connect)

App Store Connect needs 6.7" iPhone screenshots minimum. Generate from the
running build:

```
xcrun simctl io 139FDF4B-D150-403E-B876-51EDEEA589C5 screenshot \
  marketing/out/01_hero.png
```

Recommended set (one of each, 1284 × 2778 portrait):

- [ ] Hero panel router (Resident + Staff cards)
- [ ] Resident shell with weather card + SOS
- [ ] Staff residents list (after admin sign-in)
- [ ] Alert detail view with timeline
- [ ] Settings → Subscription tier selection
- [ ] (Optional) Watch companion dashboard

## Build attachment

- [ ] In App Store Connect → App Store tab → version `1.0.4` → **+ Build**
- [ ] Pick the TestFlight build uploaded above
- [ ] Confirm version + build number match

## Submit

- [ ] **Submit for Review** clicked
- [ ] Phased Release for Automatic Updates — **enable** for monitoring apps
      to limit blast radius of a regression
- [ ] Manual release — **leave off** so the build goes live on Apple's
      approval, unless you have a marketing date

## Post-submission

- [ ] Watch the Resolution Center for messages
- [ ] If rejected, reply using the appropriate template in
      `04_rejection_response_templates.md`
- [ ] On approval, monitor Crashes and Subscriber Reports in App Analytics
- [ ] First-day plan: capture screenshots of the App Store listing for the
      marketing site

---

## What I (the AI agent) can do automatically once you give the green light

- Tag the release (`git tag vX.Y.Z && git push --tags`) → triggers `cd.yml`
- Update `marketing/release_notes/` and `marketing/appstore/` text packs
- Re-run unit + UI tests after each PR change

## What I (the AI agent) cannot do

- Log into App Store Connect (requires your Apple ID + 2FA)
- Click "Submit for Review"
- Answer the Age-Rating, Privacy, or Export-Compliance questionnaires (each
  is saved against your Team ID, not exposed via API)
- Upload screenshots or App Previews
- Respond to Resolution Center messages on your behalf
