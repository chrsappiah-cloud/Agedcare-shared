# CI/CD Secrets — TestFlight Upload Pipeline

The `.github/workflows/cd.yml` pipeline uses **App Store Connect cloud signing**
and requires **3 repository secrets** to archive and upload Agedcare-shared to
TestFlight on every `vX.Y.Z` tag push.

Configure each one at:
**GitHub → repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret | What it is | How to obtain it |
|---|---|---|
| `ASC_KEY_ID` | App Store Connect API Key ID | App Store Connect → Users and Access → Keys (e.g. `ABC1234567`) |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID | Same page, top of the Keys tab |
| `ASC_PRIVATE_KEY_BASE64` | The `.p8` API key file, base64 | `base64 -i AuthKey_ABC1234567.p8 \| pbcopy` |

## One-time setup walkthrough

### 1. App Store Connect API key
1. appstoreconnect.apple.com → Users and Access → **Keys** tab → **+**
2. Name: `Agedcare-shared CI`, access: **App Manager** (or finer-grained
    "Developer" + Apps assignment)
3. **Download** the `.p8` (one shot only — save it somewhere safe)
4. Copy the **Key ID** shown next to the key → `ASC_KEY_ID`
5. Copy the **Issuer ID** at the top of the page → `ASC_ISSUER_ID`
6. Encode: `base64 -i ~/Downloads/AuthKey_*.p8 | pbcopy` → `ASC_PRIVATE_KEY_BASE64`

## Verifying

Once all 3 are set, re-trigger the workflow without re-tagging:
**Actions → CD — TestFlight (Production) → Run workflow** (uses `workflow_dispatch`).

The pre-flight step now prints `✅ All required App Store Connect secrets are present`
or fails fast with a list of which ones are still missing.

## Rotating

The `.p8` artifact can be rotated at any time. When CI starts failing with
`403 Forbidden` or a revoked-key error, repeat step 1 and update the affected
secrets — no other changes needed.
