# Age Rating and Export Compliance answers

Two separate questionnaires inside App Store Connect that you must complete
yourself; reproduce these answers verbatim.

---

## Age Rating questionnaire

**App Store Connect → My Apps → AgedCare Monitor → App Information →
Age Rating → Edit**

Expected rating: **17+** (Frequent / Intense Medical / Treatment Information).

| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature / Suggestive Themes | None |
| Horror / Fear Themes | None |
| Medical / Treatment Information | **Frequent / Intense** |
| Alcohol, Tobacco, or Drug Use or References | Infrequent / Mild (medication-reminder context only) |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Contests | None |
| Unrestricted Web Access | **No** |
| Gambling and Contests | None |

After saving, App Store Connect will compute **17+** automatically.

---

## Export Compliance questionnaire

**App Store Connect → My Apps → AgedCare Monitor → TestFlight or
Distribution → Build → Export Compliance Information**

The app uses HTTPS (URLSession with TLS) and Apple's CloudKit; both are
**exempt** standard system encryption. Answers:

| Question | Answer |
|---|---|
| Is your app designed to use cryptography? | **Yes** |
| Does your app qualify for any of the exemptions in Category 5 Part 2? | **Yes** |
| Which exemption? | (b) The app's encryption is limited to providing authentication or digital signature functionality using HTTPS / TLS, and (d) the app uses only encryption that is provided by the operating system (URLSession, CryptoKit, CloudKit). |
| Does your app implement any proprietary encryption algorithms? | **No** |
| Does your app implement any standard encryption algorithms instead of, or in addition to, accessing or using the encryption in iOS? | **No** |
| Annual self-classification report required? | **No** (qualifies for exemption) |

Once confirmed for the first build, App Store Connect remembers the answer
and you do not have to repeat it for each upload of the same version.

`ITSAppUsesNonExemptEncryption = false` is set in `Agedcare-shared/Info.plist`
so TestFlight export-compliance prompts are pre-answered for standard HTTPS/TLS
only. Confirm the questionnaire answers in Section 1 of
`08_distribution_review_responses.md` on the first build if Apple still asks.

---

## Required device capabilities

Already declared in `INFOPLIST_KEY_UIRequiredDeviceCapabilities = armv7` in
`Agedcare-shared.xcodeproj/project.pbxproj`. No change needed.

---

## Background modes declared

Confirm these are checked in the target's *Signing & Capabilities* tab:

- Audio, AirPlay, and Picture in Picture (for distress-sound monitoring)
- Location updates (when remote room sensor is geographically distant)
- Background fetch (periodic CloudKit alert sync)
- Background processing (incident upload retries)
- Remote notifications (CloudKit subscription wake-up)

If any are missing the App Review team will reject for *Guideline 2.5.4*
("Apps that use background services for purposes other than their intended
and advertised use").
