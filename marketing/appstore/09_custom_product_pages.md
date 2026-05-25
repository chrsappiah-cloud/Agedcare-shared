# Custom Product Pages & Ad Campaigns

**App:** AgedCare Monitor · Bundle `wcs.Agedcare-shared` · Version 1.0.4 (118)

**Custom Product Page ID:** `aaaf421f-391d-4683-af72-64dc986c242d`

**App Store Connect:** https://appstoreconnect.apple.com/apps/6767978725/distribution/productpages/aaaf421f-391d-4683-af72-64dc986c242d

---

## Custom Product Page — Setup Overview

A Custom Product Page (CPP) lets you create alternate versions of your App Store
product page with different screenshots and promotional text, targeting specific
audiences. Each CPP has a unique URL you can use in ad campaigns.

**In App Store Connect:**
1. Open the CPP at the URL above
2. For each audience segment below, upload the matching SVG screenshots
3. Copy the **Promotional Text** and **Description** for each variant
4. **Save** each variant
5. Submit the CPP for App Review alongside your main version

---

## Segment 1: Facility Administrators

**Target:** Care home managers, facility operators, clinical directors
**Goal:** Reduce response times, streamline operations, compliance

### Promotional Text (170 char max)

```
Reduce incident response times across your facility. On-device fall detection, multi-role dashboards, and audit-ready logs — all in one secure iOS platform.
```

### Description

```
AgedCare Monitor helps facility leaders streamline operations and improve resident outcomes with a unified iOS platform for professional aged care.

Key benefits for your facility:
• Unified incident dashboard — every alert, fall, and distress signal in one timeline
• Multi-role access control — Admin, Nurse, Carer, and Family views with permission scoping
• Compliance-ready audit trails — automated logging for regulatory reporting
• Reduce response times — on-device AI detects falls and distress sounds instantly
• No additional hardware — uses existing iPhones and Apple Watches
• Private by design — all camera and audio analysis happens on device

This app is a monitoring aid, not a medical device.
```

### Suggested screenshots (from `marketing/src/cpp/`)

| Order | Asset | Caption |
|-------|-------|---------|
| 1 | `cpp_hero_admin.svg` | Streamline your aged care facility |
| 2 | `01_hero.png` | Resident and Staff hub |
| 3 | `02_staff.png` | Multi-role staff dashboard |
| 4 | `03_alerts.png` | Incident timeline |
| 5 | `cpp_feature_privacy.svg` | Private by design |
| 6 | `05_subscription.png` | Care Pro & Care Team plans |

### Unique CPP URL

`https://apps.apple.com/app/id6767978725?pp=aaaf421f-391d-4683-af72-64dc986c242d&ct=admin-campaign`

---

## Segment 2: Family Carers

**Target:** Family members caring for elderly relatives
**Goal:** Peace of mind, remote monitoring, privacy assurance

### Promotional Text (170 char max)

```
Stay connected to your loved one's wellbeing. Real-time updates, fall alerts, and room temperature — all private, all on-device, right from your iPhone.
```

### Description

```
AgedCare Monitor gives family carers peace of mind by keeping you connected to your loved one's wellbeing — without invasive cameras or compromised privacy.

What you can see:
• Heart rate, SpO₂, and step trends via HealthKit (read-only)
• Room temperature via HomeKit-connected sensors
• Live outdoor weather at the facility
• Incident alerts when care staff respond to a fall or distress event

Privacy you can trust:
• All camera and audio analysis stays on the bedside iPhone
• No video feeds are ever streamed to your phone
• No third-party analytics, no tracking, no data sold
• Delete your account and all data in one tap

AgedCare Monitor is a monitoring aid, not a medical device. In an emergency, always call local emergency services.
```

### Suggested screenshots

| Order | Asset | Caption |
|-------|-------|---------|
| 1 | `cpp_hero_family.svg` | Peace of mind, right in your pocket |
| 2 | `01_hero.png` | Simple two-tap launch |
| 3 | `04_participants.png` | Care team at a glance |
| 4 | `03_alerts.png` | Alert timeline |
| 5 | `cpp_feature_privacy.svg` | Private by design |
| 6 | `05_subscription.png` | Choose your plan |

### Unique CPP URL

`https://apps.apple.com/app/id6767978725?pp=aaaf421f-391d-4683-af72-64dc986c242d&ct=family-campaign`

---

## Segment 3: Care Staff / Nurses

**Target:** Nurses, carers, care assistants working in facilities
**Goal:** Faster response, on-device tools, Apple Watch integration

### Promotional Text (170 char max)

```
On-device fall detection, distress-sound monitoring, and Apple Watch alerts. Respond faster with AgedCare Monitor — your pocket-sized care companion.
```

### Description

```
AgedCare Monitor equips care staff with on-device AI that detects falls and distress sounds in real time — no server uploads, no privacy concerns.

Tools for every shift:
• Vision fall detection using CoreML — no video ever leaves the iPhone
• Distress-sound monitoring via SoundAnalysis
• Apple Watch companion with alert summary and SOS button
• Multi-resident dashboard with timeline, alerts, and settings
• HealthKit vitals trends at a glance
• HomeKit room temperature and outdoor weather context

Works offline with a local demo store. CloudKit sync is opt-in per resident.

This app is a monitoring aid, not a medical device.
```

### Suggested screenshots

| Order | Asset | Caption |
|-------|-------|---------|
| 1 | `cpp_hero_staff.svg` | Respond faster. Care smarter. |
| 2 | `02_staff.png` | Multi-resident dashboard |
| 3 | `03_alerts.png` | Incident timeline |
| 4 | `06_watch.png` | Apple Watch companion |
| 5 | `cpp_feature_privacy.svg` | On-device & private |
| 6 | `05_subscription.png` | Care Pro & Care Team |

### Unique CPP URL

`https://apps.apple.com/app/id6767978725?pp=aaaf421f-391d-4683-af72-64dc986c242d&ct=staff-campaign`

---

## Apple Search Ads — Creative Sets

For each **Apple Search Ads** campaign, create a Creative Set using the
corresponding CPP URL, promotional text, and screenshots.

### Campaign 1: "Aged Care Software" / "Facility Management"

| Field | Value |
|-------|-------|
| **CPP URL** | `https://apps.apple.com/app/id6767978725?pp=aaaf421f-391d-4683-af72-64dc986c242d&ct=searchads-admin` |
| **Promotional Text** | Reduce incident response times across your facility. On-device fall detection, multi-role dashboards, audit-ready logs — all in one secure iOS platform. |
| **Screenshots** | Use Segment 1 set |
| **Keywords** | aged care software, senior care management, dementia care app, assisted living software, aged care compliance |
| **Tap-through URL** | (CPP URL above) |

### Campaign 2: "Fall Detection App" / "Senior Safety"

| Field | Value |
|-------|-------|
| **CPP URL** | `https://apps.apple.com/app/id6767978725?pp=aaaf421f-391d-4683-af72-64dc986c242d&ct=searchads-fall` |
| **Promotional Text** | On-device AI fall detection that respects privacy. Instant alerts to care staff and family — no camera feeds leave the iPhone. |
| **Screenshots** | Use Segment 3 set (lead with fall detection messaging) |
| **Keywords** | fall detection app, senior safety, elderly monitoring, fall alert, dementia wandering |
| **Tap-through URL** | (CPP URL above) |

### Campaign 3: "Family Caregiver" / "Elderly Parent Monitor"

| Field | Value |
|-------|-------|
| **CPP URL** | `https://apps.apple.com/app/id6767978725?pp=aaaf421f-391d-4683-af72-64dc986c242d&ct=searchads-family` |
| **Promotional Text** | Stay connected to your loved one's wellbeing. Real-time updates, fall alerts, room temperature — all private, all on-device. |
| **Screenshots** | Use Segment 2 set |
| **Keywords** | family caregiver app, elderly parent monitoring, senior care app, aging parent, dementia support |
| **Tap-through URL** | (CPP URL above) |

---

## Custom Product Page Ad Responses (for App Review)

When submitting the CPP, App Store Connect may ask about the custom product
page content. Use these responses:

### Does this custom product page contain different app metadata?

```
Yes. Each variant targets a distinct audience (facility administrators, family carers, and care staff) with tailored promotional text and screenshot captions. The app's core functionality and screenshots are the same across all variants; only the accompanying text and image order differ to match each audience's priorities.
```

### Does the app appear differently than described in the custom page?

```
No. All custom product pages accurately represent the app's features and functionality. The screenshots show real app screens (hero panel, staff dashboard, alerts, watch companion, subscription screen). No misleading or fictitious content is used.
```

### Are the promotional text claims substantiated?

```
Yes. All claims are supported by implemented features:
- "On-device fall detection" → CoreML Vision + CoreMotion integration
- "Distress-sound monitoring" → SoundAnalysis framework
- "Apple Watch companion" → watchOS target with alert mirroring
- "Private by design" → no third-party SDKs, on-device processing, no tracking
- "Account deletion in one tap" → Settings → Account → Delete Account
- "Multi-role dashboards" → Admin, Nurse, Carer, Family roles in SessionViewModel
```
