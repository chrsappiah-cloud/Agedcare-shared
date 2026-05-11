# CI/CD Secrets — TestFlight Upload Pipeline

The `.github/workflows/cd.yml` pipeline requires **7 repository secrets** to sign
and upload Agedcare-shared to TestFlight on every `vX.Y.Z` tag push.

Configure each one at:
**GitHub → repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret | What it is | How to obtain it |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | Distribution signing cert (`.p12`), base64 | Export from Keychain Access → `base64 -i Cert.p12 \| pbcopy` |
| `P12_PASSWORD` | Password set during `.p12` export | The password you chose when exporting |
| `BUILD_PROVISION_PROFILE_BASE64` | App Store provisioning profile, base64 | Download from developer.apple.com → `base64 -i Profile.mobileprovision \| pbcopy` |
| `KEYCHAIN_PASSWORD` | Arbitrary password for the temp CI keychain | Any strong random string (e.g. `openssl rand -base64 24`) |
| `ASC_KEY_ID` | App Store Connect API Key ID | App Store Connect → Users and Access → Keys (e.g. `ABC1234567`) |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID | Same page, top of the Keys tab |
| `ASC_PRIVATE_KEY_BASE64` | The `.p8` API key file, base64 | `base64 -i AuthKey_ABC1234567.p8 \| pbcopy` |

## One-time setup walkthrough

### 1. Distribution certificate (`.p12`)
1. Xcode → Settings → Accounts → Manage Certificates
2. `+` → **Apple Distribution** (if you don't already have one)
3. Open **Keychain Access**, right-click the cert, **Export…** as `.p12`,
   set a strong password — this becomes `P12_PASSWORD`
4. Encode: `base64 -i ~/Desktop/Agedcare-Dist.p12 | pbcopy`
5. Paste into the `BUILD_CERTIFICATE_BASE64` secret

### 2. Provisioning profile
1. developer.apple.com → Certificates, Identifiers & Profiles → Profiles
2. `+` → **App Store** distribution → select app id `wcs.Agedcare-shared` →
   the cert from step 1 → name it `Agedcare-shared App Store` → Generate
3. Download the `.mobileprovision`
4. Encode: `base64 -i ~/Downloads/*.mobileprovision | pbcopy`
5. Paste into `BUILD_PROVISION_PROFILE_BASE64`

### 3. App Store Connect API key
1. appstoreconnect.apple.com → Users and Access → **Keys** tab → **+**
2. Name: `Agedcare-shared CI`, access: **App Manager** (or finer-grained
   "Developer" + Apps assignment)
3. **Download** the `.p8` (one shot only — save it somewhere safe)
4. Copy the **Key ID** shown next to the key → `ASC_KEY_ID`
5. Copy the **Issuer ID** at the top of the page → `ASC_ISSUER_ID`
6. Encode: `base64 -i ~/Downloads/AuthKey_*.p8 | pbcopy` → `ASC_PRIVATE_KEY_BASE64`

### 4. Keychain password
```bash
openssl rand -base64 24 | pbcopy
```
Paste into `KEYCHAIN_PASSWORD`. It just unlocks the throwaway keychain
the CI runner creates — not used anywhere else.

## Verifying

Once all 7 are set, re-trigger the workflow without re-tagging:
**Actions → CD — TestFlight (Production) → Run workflow** (uses `workflow_dispatch`).

The pre-flight step now prints `✅ All 7 required signing secrets are present`
or fails fast with a list of which ones are still missing.

## Rotating

The `.p8` and `.p12` artifacts expire (typically 1 year). When CI starts failing
with `403 Forbidden` or `certificate has expired`, repeat steps 1 and 3 and update
the affected secrets — no other changes needed.
