# App Store submission — do these steps in order

## Build upload status

**Build 1.0.4 (117) was uploaded to App Store Connect** from this Mac (Xcode session auth).
Wait ~15 minutes for processing in TestFlight, then complete metadata and **Submit for Review** below.

For future CI uploads, still add `AuthKey_A863K5FF84.p8`:

```bash
./scripts/setup_asc_secrets.sh ~/Downloads/AuthKey_A863K5FF84.p8
gh workflow run cd.yml --ref ci/agedcare-release-automation -f marketing_version=1.0.4
```

**Local re-upload** (if MacPorts rsync is installed, scripts force Apple `/usr/bin/rsync`):

```bash
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
./scripts/local-release.sh
```

Issuer ID: `70c46c69-5d6d-438d-b300-31df2b93163a`

---

## After TestFlight build processes (~15 min)

**All copy-paste answers:** `08_distribution_review_responses.md`  
**Open every ASC screen:** `./scripts/open-distribution-review.sh`

### App Store Connect → TestFlight

- Paste **What to Test** from `02_what_to_test.md` (or Section 2 in `08_…`)
- **Export Compliance** — Section 1 in `08_…` (`ITSAppUsesNonExemptEncryption` is in Info.plist)
- External testers: **Beta App Review** notes — Section 3 in `08_…`

### App Store Connect → App Store → Version 1.0.4

| Field | Source file |
|-------|-------------|
| **All questionnaires (one doc)** | `08_distribution_review_responses.md` |
| Name, subtitle, description, keywords | `05_appstore_form_fields.md` |
| Privacy nutrition label | `03_privacy_nutrition_label.md` or Section 5 in `08_…` |
| Age rating (17+) | `06_age_rating_and_export.md` or Section 4 in `08_…` |
| Review notes + demo account | `01_review_notes.md` or Section 7 in `08_…` |
| Screenshots (6.7" iPhone) | `marketing/out/appstore_*.png` |

### Attach build and submit

1. **+ Build** → select **1.0.4 (117)** or latest CI build number
2. **Submit for Review**
3. Enable **Phased Release**; leave manual release off

### If rejected

Use templates in `04_rejection_response_templates.md`

---

## GitHub (before or after upload)

- Merge PR #1 when CodeQL is green: https://github.com/chrsappiah-cloud/Agedcare-shared/pull/1
- Revoke old API keys (`TN35FDL978`, `KLH62AX56M`) in App Store Connect after the new key works
