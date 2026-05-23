# 🚀 App Store Submission — NEXT STEPS (Do These Now)

**Build Status:** ✅ **1.0.4 (118) uploaded, processed, and attached**  
**Status:** iPhone + iPad screenshots prepared; App Privacy, primary category, pricing, and final browser submit remain  
**Time to Complete Submission:** ~10–20 minutes of active App Store Connect work  

---

## ⏱️ What to Do Right Now

### 1. ✅ Confirm the ready state in App Store Connect (2 min)

```bash
# Open App Store Connect in your browser
# Navigate to: Agedcare-shared → TestFlight → Builds
# Confirm build 1.0.4 (118) shows as processed / ready
```

**Expected:** Build **1.0.4 (118)** is ready and attached on the App Store page

---

### 2. 🖼️ Screenshots are prepared

- [x] 6 screenshots uploaded for **6.7" iPhone**
- [x] 3 screenshots uploaded for **12.9" iPad**
- [x] 3 screenshots generated for **13-inch iPad** manual upload fallback
- [x] Review notes copied by `./scripts/submit-for-review.sh`

Local asset folders:

```bash
marketing/out/appstore/
marketing/out/appstore-ipad/
marketing/out/appstore-ipad13/
```

---

### 3. 📋 Complete the browser-only App Store sections

#### Open App Store Connect → Agedcare-shared → App Store tab → Version 1.0.4

**Required fixes from App Store Connect before review can start:**

- [ ] **Primary category** → set to **Medical**
- [ ] **Pricing** → set price tier to **Free**
- [ ] **App Privacy** → must be completed by an **Admin**
- [ ] **13-inch iPad screenshot** → upload from `marketing/out/appstore-ipad13/` if ASC still shows that requirement

**Copy-paste everything from `INFLIGHT_PASTE.txt` into these fields:**

| Field | Source Line | Action |
|-------|-------------|--------|
| App Name | Line 161 | Paste "AgedCare Monitor" into "App Name" field |
| Subtitle | Line 166 | Paste "Dementia & Fall Monitoring" into "Subtitle" |
| Description | Lines 14–35 | Paste into "Description" field |
| Keywords | Line 40 | Paste into "Keywords" field |
| Promotional Text | Line 9 | Paste into "Promotional Text" field |
| Support URL | Line 45 | Paste into "Support URL" field |
| Marketing URL | Line 50 | Paste into "Marketing URL" field |
| Privacy Policy URL | Line 53 | Paste into "Privacy Policy URL" field (on "App Information" tab if separate) |
| Copyright | Line 58 | Paste into "Copyright" field |
| What's New | Line 65 | Paste into "What's New in This Version" field |

**After each paste, click "Save"**

#### Set Release Settings

Go to "Version Release" section:
- [ ] **Phased Release for Automatic Updates:** Toggle **ON** (safer for monitoring apps)
- [ ] **Manually Release This Version:** Leave **OFF**

#### Fill Age Rating

Go to "Ratings" section:
- [ ] Select **17+** (Mature Content)
- [ ] Answer questionnaire (or leave defaults for monitoring app)

#### Add Demo Account

Go to "App Review Information" section:
- [ ] **Sign-In Required:** Select **Yes**
- [ ] **Username:** Paste `admin@gvcare.com`
- [ ] **Password:** Paste `password`
- [ ] **First Name:** `Christopher`
- [ ] **Last Name:** `Appiah-Thompson`
- [ ] **Email Address:** `christopher.appiahthompson@myworldclass.org`
- [ ] **Notes:** Paste entire block from `INFLIGHT_PASTE.txt` lines 109–152 (or from `01_review_notes.md`)

#### Complete App Privacy

Go to "App Privacy" section:
- [ ] Click "Edit" and fill in data categories from `03_privacy_nutrition_label.md`
- [ ] Declare: **Camera** (fall detection), **Microphone** (distress sounds), **Location** (weather), **Health** (HealthKit), **Photos** (incident attachments)
- [ ] Mark all as "Not Tracked" (no third-party tracking)

#### Attach Build

Go to the "Build" section (top of version page):
- [ ] Click **+ Build**
- [ ] Select **1.0.4 (118)** from dropdown
- [ ] Click **Done**

---

### 4. ✅ Final Audit (5–10 min)

Before clicking "Submit for Review":

```bash
# Quick checklist:
# ☐ App name: AgedCare Monitor
# ☐ Primary category: Medical
# ☐ Price tier: Free
# ☐ All URLs return 200 OK (test in browser)
# ☑ 6 screenshots uploaded for 6.7" iPhone
# ☑ 3 screenshots uploaded for 12.9" iPad
# ☐ 13-inch iPad screenshots uploaded if ASC still requires that display
# ☐ App Privacy completed (Camera, Microphone, Location, Health)
# ☐ Age rating: 17+
# ☐ Demo account: admin@gvcare.com / password
# ☐ Review notes filled (entire block from 01_review_notes.md)
# ☐ Build attached: 1.0.4 (118)
# ☐ Phased Release: ON
# ☐ Manual Release: OFF
```

---

### 5. 🎉 Submit for Review (1 min)

**Go to App Store Connect → Agedcare-shared → App Store → Version 1.0.4**

1. Scroll to the bottom
2. Click blue **Submit for Review** button
3. Confirm the distribution declaration:
   - [ ] Uses encryption: **Yes**
   - [ ] Exempt: **Yes**
   - [ ] Proprietary encryption: **No**
4. Click **Submit** (irreversible — app is now in the review queue)

**Approval Timeline:** 24–48 hours typical (may be longer during holidays)

---

## 📞 If Anything Goes Wrong

| Problem | Solution |
|---------|----------|
| "Build still processing" | Refresh TestFlight and App Store tabs; build 118 should be VALID |
| "URLs not loading" | Fix URLs on https://wcs-full.vercel.app, verify they return 200 OK |
| "Screenshots missing" | Re-run `./scripts/upload-appstore-screenshots.sh` |
| "Demo account doesn't work" | Test locally: run app, tap "Staff", sign in with admin@gvcare.com / password |
| "Export Compliance field missing" | Go to TestFlight → Builds → 1.0.4 (118) → Manage → Export Compliance |
| "Rejected after submit" | Check Resolution Center, use templates in `04_rejection_response_templates.md` |

---

## 📚 Full Documentation

- **`APPLE_DISTRIBUTION_GUIDE.md`** — Complete step-by-step guide (17+ KB)
- **`SUBMISSION_READINESS_CHECKLIST.md`** — Detailed checklist (15+ KB)
- **`marketing/appstore/INFLIGHT_PASTE.txt`** — Ready-to-paste copy (all sections)
- **`marketing/appstore/01_review_notes.md`** — What the app does & demo account
- **`marketing/appstore/03_privacy_nutrition_label.md`** — Privacy label matrix
- **`marketing/appstore/06_age_rating_and_export.md`** — Rating & export compliance

---

## ⏰ Timeline Summary

| When | What |
|------|------|
| **Now** | ✅ Build attached, screenshots uploaded, review notes ready |
| **In 10–20 min** | 📋 Finish App Privacy / export / rating answers in ASC |
| **Right after that** | 🚀 Click "Submit for Review" |
| **+1–2 days** | 📧 Apple approves or asks for changes |
| **After approval** | 🎊 App goes live! (or phased rollout begins) |

---

## 🏁 You Are Here

```
[Build uploaded] → [TestFlight processing] ← YOU ARE HERE
                            ↓
                  [Screenshots ready]
                            ↓
                  [Metadata complete]
                            ↓
                  [Submit for Review]
                            ↓
                  [Apple Reviews (24–48h)]
                            ↓
                  [Approved! 🎉]
                            ↓
                  [Live on App Store]
```

---

**Good luck! You're ready to ship.** 🚀

Next: Wait ~15 min for TestFlight, then follow steps 3–6 above.
