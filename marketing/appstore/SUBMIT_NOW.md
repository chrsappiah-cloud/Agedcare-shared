# App Store submission — do these steps in order

## BLOCKER: API private key (2 minutes)

`AuthKey_A863K5FF84.p8` is **not on this Mac yet**. Without it, CI cannot upload to TestFlight.

1. Open [App Store Connect → Integrations → API](https://appstoreconnect.apple.com/access/integrations/api)
2. Download **AuthKey_A863K5FF84.p8** (one-time only) → save to `~/Downloads/`
3. Run:

```bash
cd /Applications/Agedcare-shared
./scripts/setup_asc_secrets.sh ~/Downloads/AuthKey_A863K5FF84.p8
gh workflow run cd.yml --ref ci/agedcare-release-automation -f marketing_version=1.0.4
```

**Or** build and upload from this Mac:

```bash
./scripts/local-release.sh
```

Issuer ID (already in GitHub as `ASC_ISSUER_ID`): `70c46c69-5d6d-438d-b300-31df2b93163a`

---

## After TestFlight build processes (~15 min)

### App Store Connect → TestFlight

- Paste **What to Test** from `02_what_to_test.md`
- Answer **Export Compliance** per `06_age_rating_and_export.md` (standard encryption only)

### App Store Connect → App Store → Version 1.0.4

| Field | Source file |
|-------|-------------|
| Name, subtitle, description, keywords | `05_appstore_form_fields.md` |
| Privacy nutrition label | `03_privacy_nutrition_label.md` |
| Age rating (17+) | `06_age_rating_and_export.md` |
| Review notes + demo account | `01_review_notes.md` |
| Screenshots (6.7" iPhone) | Capture from build — see `07_submission_checklist.md` |

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
