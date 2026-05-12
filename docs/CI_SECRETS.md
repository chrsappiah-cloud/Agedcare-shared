# CI/CD Secrets — TestFlight Upload Pipeline

The `.github/workflows/cd.yml` pipeline uses **App Store Connect signing** and
requires **3 repository secrets** to archive and upload Agedcare-shared to
TestFlight on every `vX.Y.Z` tag push. In environments where App Store Connect
cannot create a managed distribution profile automatically, you should also set
the optional fallback profile secret below.

Configure each one at:
**GitHub → repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret | What it is | How to obtain it |
|---|---|---|
| `ASC_KEY_ID` | App Store Connect API Key ID | App Store Connect → Users and Access → Keys (e.g. `ABC1234567`) |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID | Same page, top of the Keys tab |
| `ASC_PRIVATE_KEY_BASE64` | The `.p8` API key file, base64 | `base64 -i AuthKey_ABC1234567.p8 \| pbcopy` |
| `BUILD_PROVISION_PROFILE_BASE64` *(optional fallback)* | App Store provisioning profile, base64 | `base64 -i ~/Downloads/Agedcare-shared.mobileprovision \| pbcopy` |

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

Once the 3 required secrets are set, re-trigger the workflow without re-tagging:
**Actions → CD — TestFlight (Production) → Run workflow** (uses `workflow_dispatch`).

The pre-flight step now prints `✅ All required App Store Connect secrets are present`
or fails fast with a list of which ones are still missing. If cloud-managed
profile creation is not permitted for the API key, also add
`BUILD_PROVISION_PROFILE_BASE64` so the export step can use an existing
App Store profile directly.

## Rotating

The `.p8` artifact can be rotated at any time. When CI starts failing with
`403 Forbidden` or a revoked-key error, repeat step 1 and update the affected
secrets — no other changes needed.
