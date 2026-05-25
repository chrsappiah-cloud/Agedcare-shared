#!/usr/bin/env bash
# Submit AgedCare Monitor for App Store Review via API, or open ASC + clipboard.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="${ASC_APP_ID:-6767978725}"
BUNDLE_ID="${ASC_BUNDLE_ID:-wcs.Agedcare-shared}"
VERSION="${MARKETING_VERSION:-1.0.4}"
BUILD="${BUILD_NUMBER:-$(cd "$ROOT" && xcrun agvtool what-version -terse 2>/dev/null | tail -n 1 || echo 118)}"
KEY_ID="${ASC_KEY_ID:-A863K5FF84}"
ISSUER_ID="${ASC_ISSUER_ID:-70c46c69-5d6d-438d-b300-31df2b93163a}"

find_p8() {
  for candidate in \
    "${ASC_P8_PATH:-}" \
    "$ROOT/scripts/.auth/AuthKey_${KEY_ID}.p8" \
    "$HOME/Downloads/AuthKey_${KEY_ID}.p8" \
    "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"; do
    [[ -n "$candidate" && -f "$candidate" ]] && { echo "$candidate"; return 0; }
  done
  return 1
}

copy_review_notes() {
  python3 <<'PY'
from pathlib import Path
text = Path("marketing/appstore/01_review_notes.md").read_text()
lines = text.splitlines()
out = []
skip = True
for line in lines:
    if line.startswith("## What this app does"):
        skip = False
    if skip:
        continue
    if line.startswith("# ") and not line.startswith("## "):
        continue
    if line.startswith("Paste the contents"):
        continue
    if line.startswith("**App Store Connect"):
        continue
    if line == "---":
        continue
    out.append(line)
print("\n".join(out).strip())
PY
}

api_submit() {
  local p8="$1"
  python3 <<PY
import json, ssl, sys, time, urllib.error, urllib.request
from pathlib import Path

try:
    import jwt
except ImportError:
    raise SystemExit("pip3 install PyJWT cryptography required for API submit")

key_id = "${KEY_ID}"
issuer = "${ISSUER_ID}"
bundle = "${BUNDLE_ID}"
version = "${VERSION}"
build_num = "${BUILD}"
p8 = Path("${p8}").read_text()
now = int(time.time())
token = jwt.encode(
    {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
    p8,
    algorithm="ES256",
    headers={"kid": key_id},
)

def api(method, path, body=None):
    url = "https://api.appstoreconnect.apple.com/v1" + path
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=60) as r:
            return json.loads(r.read().decode()), r.status
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        raise SystemExit(f"API {method} {path} -> {e.code}: {err[:2000]}")

# App
apps, _ = api("GET", f"/apps?filter[bundleId]={bundle}&limit=1")
if not apps.get("data"):
    raise SystemExit(f"App not found for bundle {bundle}")
app_id = apps["data"][0]["id"]
print(f"App id: {app_id}")

# iOS app store versions
vers, _ = api(
    "GET",
    f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=50",
)
target = None
editable_candidate = None
for v in vers.get("data", []):
    attrs = v.get("attributes", {})
    state = attrs.get("appStoreState")
    version_string = attrs.get("versionString")
    if version_string == version:
        target = v["id"]
        print(f"Version {version} id={target} state={state}")
        break
    if state == "PREPARE_FOR_SUBMISSION" and editable_candidate is None:
        editable_candidate = v
if not target:
    if editable_candidate is not None:
        target = editable_candidate["id"]
        current_version = editable_candidate.get("attributes", {}).get("versionString")
        api(
            "PATCH",
            f"/appStoreVersions/{target}",
            {
                "data": {
                    "type": "appStoreVersions",
                    "id": target,
                    "attributes": {"versionString": version},
                }
            },
        )
        print(
            f"Updated editable version {current_version} -> {version} "
            f"(id={target})."
        )
    else:
        created, _ = api(
            "POST",
            "/appStoreVersions",
            {
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {
                        "platform": "IOS",
                        "versionString": version,
                    },
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}}
                    },
                }
            },
        )
        target = created["data"]["id"]
        print(f"Created version {version} id={target}")

# Builds for this app
builds, _ = api(
    "GET",
    f"/builds?filter[app]={app_id}&limit=200&sort=-uploadedDate",
)
build_id = None
for b in builds.get("data", []):
    attrs = b.get("attributes", {})
    if str(attrs.get("version")) == build_num:
        build_id = b["id"]
        proc = attrs.get("processingState")
        print(f"Build {build_num} id={build_id} processing={proc}")
        break
if not build_id:
    raise SystemExit(f"Build {build_num} not found. Wait for TestFlight processing.")

if proc != "VALID":
    print(f"Warning: build processing state is {proc!r}, not VALID")

# Attach build to version
api(
    "PATCH",
    f"/appStoreVersions/{target}",
    {
        "data": {
            "type": "appStoreVersions",
            "id": target,
            "relationships": {
                "build": {"data": {"type": "builds", "id": build_id}}
            },
        }
    },
)
print("Attached build to version.")

# Submit for review
try:
    sub, status = api(
        "POST",
        "/appStoreVersionSubmissions",
        {
            "data": {
                "type": "appStoreVersionSubmissions",
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": target}
                    }
                },
            }
        },
    )
    print(f"Submitted for review (HTTP {status}).")
    print(json.dumps(sub, indent=2)[:1500])
except SystemExit as e:
    msg = str(e)
    if (
        "409" in msg
        or "STATE" in msg.upper()
        or "READY" in msg.upper()
        or "FORBIDDEN_ERROR" in msg
        or "does not allow 'CREATE'" in msg
    ):
        print("API submit blocked — complete metadata/export/privacy in ASC, then click Submit.")
        sys.exit(2)
    raise
PY
}

open_asc_manual() {
  echo "Opening App Store Connect submission screens…"
  open "https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/ios/version/inflight"
  open "https://appstoreconnect.apple.com/apps/${APP_ID}/testflight/ios"
  open "https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/ios/version/deliverable"
  echo ""
  echo "=== SUBMIT CHECKLIST (do in browser) ==="
  echo "1. TestFlight → Build ${BUILD} → Export Compliance → Yes, exempt (see 08_distribution_review_responses.md §1)"
  echo "2. App Store → Version ${VERSION} → attach build ${BUILD}"
  echo "3. Fill yellow warnings (privacy, age 17+, screenshots, review info)"
  echo "4. App Review: admin@gvcare.com / password — notes are on your clipboard"
  echo "5. Click Submit for Review → Phased release ON"
  echo ""
  echo "Responses: marketing/appstore/08_distribution_review_responses.md"
}

cd "$ROOT"
if P8="$(find_p8)"; then
  echo "Using API key ${KEY_ID} from ${P8}"
  set +e
  api_submit "$P8"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    exit 0
  fi
  if [[ "$status" -eq 2 ]]; then
    copy_review_notes | pbcopy
    echo "App Review notes copied to clipboard."
    open_asc_manual
    exit 0
  fi
  exit "$status"
else
  echo "No AuthKey_${KEY_ID}.p8 — manual submit in App Store Connect."
  echo "Add key: ./scripts/setup_asc_secrets.sh ~/Downloads/AuthKey_${KEY_ID}.p8"
  copy_review_notes | pbcopy
  echo "App Review notes copied to clipboard."
  open_asc_manual
fi
