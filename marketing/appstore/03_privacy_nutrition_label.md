# App Privacy ("Nutrition Label") answers

Paste into:
**App Store Connect → App Privacy → Get Started**

These answers map 1-to-1 to the `INFOPLIST_KEY_NS*UsageDescription` entries in
`Agedcare-shared.xcodeproj/project.pbxproj`. All data is processed on-device by
default; cloud sync is opt-in per resident.

---

## Data collection

**Are any data collected?**  → **Yes**

### Data types collected and linked to the user

| Apple category   | Specific data       | Used for                              | Linked to user | Tracking |
|------------------|---------------------|---------------------------------------|----------------|----------|
| Contact Info     | Email address       | Account sign-in (staff)               | Yes            | No       |
| Contact Info     | Name                | Display name on the staff dashboard   | Yes            | No       |
| Health & Fitness | Heart rate, SpO₂, steps | Anomaly detection / vitals trend  | Yes            | No       |
| User Content     | Photos and videos   | Incident evidence attachments         | Yes            | No       |
| User Content     | Audio data          | Distress-sound monitoring (on-device) | No             | No       |
| Identifiers      | User ID (CloudKit)  | Sync incidents across user devices    | Yes            | No       |
| Diagnostics      | Crash logs          | App stability                         | No             | No       |
| Diagnostics      | Performance data    | Test coverage telemetry (BetaAnalytics) | No          | No       |

### Data types NOT collected

- Location (precise or coarse) — used only on-device for facility weather; never
  persisted or transmitted. Answer **No** to "Do you collect Location?".
- Browsing / Search history — none.
- Financial info — none (subscriptions are handled by Apple StoreKit).
- Contacts — none.
- Sensitive Info — none.

### Tracking

**Do you or any third-party SDK use data to track the user?**  → **No**

There are no third-party SDKs in the iOS target. (Backend uses Supabase via a
Cloudflare Worker proxy; data sent there is the user's own account data, not
tracking).

---

## Purpose declarations (each data type)

For every "Yes" row above, select **all** of these purposes that apply:

- **App Functionality** — always tick this for every row.
- **Analytics** — tick for Performance data.
- **Product Personalization** — tick for Heart rate / SpO₂ / steps.

Do NOT tick: Third-Party Advertising, Developer's Advertising or Marketing.

---

## Data linkage and identifiability

- Email + Name + Health metrics + CloudKit User ID → **Linked to the user**
  (account-scoped).
- Audio + Crash logs → **Not linked to the user** (transient, on-device).

---

## Data deletion

App offers **Account Deletion** in Settings → Account → Delete Account
(invokes `SessionViewModel.deleteAccountAndPurge()`). Required answer:
**Yes — the user can request account deletion in-app.**

---

## Children

App is not directed at children. Age rating: **17+** (medical/treatment
information). Do not tick "Made for Kids".
