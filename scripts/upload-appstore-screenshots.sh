#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="${ASC_APP_ID:-6767978725}"
BUNDLE_ID="${ASC_BUNDLE_ID:-wcs.Agedcare-shared}"
VERSION="${MARKETING_VERSION:-1.0.4}"
KEY_ID="${ASC_KEY_ID:-A863K5FF84}"
ISSUER_ID="${ASC_ISSUER_ID:-70c46c69-5d6d-438d-b300-31df2b93163a}"
IPHONE_DIR="${IPHONE_SCREENSHOT_DIR:-$ROOT/marketing/out/appstore}"
IPAD_DIR="${IPAD_SCREENSHOT_DIR:-$ROOT/marketing/out/appstore-ipad}"
IPHONE_DISPLAY_TYPE="${ASC_IPHONE_DISPLAY_TYPE:-APP_IPHONE_67}"
IPAD_DISPLAY_TYPE="${ASC_IPAD_DISPLAY_TYPE:-APP_IPAD_PRO_129}"
LOCALE_PRIORITY="${ASC_LOCALE_PRIORITY:-en-AU,en-US}"

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

if ! P8_PATH="$(find_p8)"; then
  echo "Missing AuthKey_${KEY_ID}.p8. Set ASC_P8_PATH or place the key in ~/Downloads."
  exit 1
fi

python3 <<PY
import hashlib
import json
import mimetypes
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import jwt
except ImportError:
    raise SystemExit("pip3 install PyJWT cryptography required for screenshot upload")

APP_ID = "${APP_ID}"
BUNDLE_ID = "${BUNDLE_ID}"
VERSION = "${VERSION}"
KEY_ID = "${KEY_ID}"
ISSUER_ID = "${ISSUER_ID}"
P8_PATH = Path("${P8_PATH}")
IPHONE_DIR = Path("${IPHONE_DIR}")
IPAD_DIR = Path("${IPAD_DIR}")
IPHONE_DISPLAY_TYPE = "${IPHONE_DISPLAY_TYPE}"
IPAD_DISPLAY_TYPE = "${IPAD_DISPLAY_TYPE}"
LOCALE_PRIORITY = [item.strip() for item in "${LOCALE_PRIORITY}".split(",") if item.strip()]


def auth_token():
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        P8_PATH.read_text(),
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


TOKEN = auth_token()


def api(method, path, body=None, raw=False, url=None, headers=None):
    request_headers = {"Authorization": f"Bearer {TOKEN}"}
    if headers:
        request_headers.update(headers)
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        request_headers.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(
        url or f"https://api.appstoreconnect.apple.com/v1{path}",
        data=data,
        method=method,
        headers=request_headers,
    )
    try:
        with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=120) as response:
            payload = response.read()
            if raw:
                return payload, response.status
            if not payload:
                return {}, response.status
            return json.loads(payload.decode()), response.status
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise SystemExit(f"API {method} {path or url} -> {error.code}: {detail[:4000]}")


def api_get_collection(path):
    payload, _ = api("GET", path)
    return payload.get("data", [])


def choose_localization(version_id):
    items = api_get_collection(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    if not items:
        raise SystemExit(f"No localizations found for version {VERSION}")
    by_locale = {item.get("attributes", {}).get("locale"): item for item in items}
    for locale in LOCALE_PRIORITY:
        if locale in by_locale:
            return by_locale[locale]
    return items[0]


def get_app_id():
    items = api_get_collection(f"/apps?filter[bundleId]={urllib.parse.quote(BUNDLE_ID)}&limit=1")
    if not items:
        raise SystemExit(f"App not found for bundle {BUNDLE_ID}")
    return items[0]["id"]


def get_version_id(app_id):
    items = api_get_collection(
        f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=50"
    )
    for item in items:
        if item.get("attributes", {}).get("versionString") == VERSION:
            return item["id"]
    raise SystemExit(f"App Store version {VERSION} not found")


def get_or_create_set(localization_id, display_type):
    items = api_get_collection(
        f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=50"
    )
    items = [
        item for item in items
        if item.get("attributes", {}).get("screenshotDisplayType") == display_type
    ]
    if items:
        screenshot_set_id = items[0]["id"]
    else:
        payload, _ = api(
            "POST",
            "/appScreenshotSets",
            {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {
                        "appStoreVersionLocalization": {
                            "data": {
                                "type": "appStoreVersionLocalizations",
                                "id": localization_id,
                            }
                        }
                    },
                }
            },
        )
        screenshot_set_id = payload["data"]["id"]

    existing = api_get_collection(f"/appScreenshotSets/{screenshot_set_id}/appScreenshots?limit=200")
    for item in existing:
        api("DELETE", f"/appScreenshots/{item['id']}")
    return screenshot_set_id


def upload_operation(upload, file_bytes):
    headers = {header["name"]: header["value"] for header in upload.get("requestHeaders", [])}
    offset = upload.get("offset", 0)
    length = upload.get("length", len(file_bytes) - offset)
    chunk = file_bytes[offset : offset + length]
    req = urllib.request.Request(
        upload["url"],
        data=chunk,
        method=upload["method"],
        headers=headers,
    )
    with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=300) as response:
        if not (200 <= response.status < 300):
            raise SystemExit(f"Upload failed with HTTP {response.status}")


def create_screenshot(screenshot_set_id, path):
    file_bytes = path.read_bytes()
    md5_checksum = hashlib.md5(file_bytes).hexdigest()
    payload, _ = api(
        "POST",
        "/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileSize": len(file_bytes),
                    "fileName": path.name,
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": {
                            "type": "appScreenshotSets",
                            "id": screenshot_set_id,
                        }
                    }
                },
            }
        },
    )
    data = payload["data"]
    screenshot_id = data["id"]
    attributes = data.get("attributes", {})
    upload_operations = attributes.get("uploadOperations") or []
    if not upload_operations:
        raise SystemExit(f"No upload operations returned for {path.name}: {json.dumps(payload)[:2000]}")
    for upload in upload_operations:
        upload_operation(upload, file_bytes)
    api(
        "PATCH",
        f"/appScreenshots/{screenshot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": md5_checksum,
                },
            }
        },
    )
    wait_for_completion(screenshot_id, path.name)


def wait_for_completion(screenshot_id, file_name):
    deadline = time.time() + 600
    while True:
        payload, _ = api("GET", f"/appScreenshots/{screenshot_id}")
        state = payload.get("data", {}).get("attributes", {}).get("assetDeliveryState", {})
        status = state.get("state")
        if status == "COMPLETE":
            print(f"Uploaded {file_name}")
            return
        if status == "FAILED":
            errors = state.get("errors", [])
            formatted = "; ".join(
                filter(None, [f"{item.get('code')}: {item.get('description')}" for item in errors])
            )
            raise SystemExit(f"Screenshot processing failed for {file_name}: {formatted or state}")
        if time.time() > deadline:
            raise SystemExit(f"Timed out waiting for screenshot processing: {file_name} ({status})")
        time.sleep(2)


def sorted_pngs(directory):
    files = sorted(directory.glob("*.png"))
    if not files:
        raise SystemExit(f"No PNG files found in {directory}")
    return files


app_id = get_app_id()
version_id = get_version_id(app_id)
localization = choose_localization(version_id)
localization_id = localization["id"]
locale = localization.get("attributes", {}).get("locale", "unknown")
print(f"Uploading screenshots for App Store version {VERSION} localization {locale} ({localization_id})")

uploads = [
    (IPHONE_DISPLAY_TYPE, sorted_pngs(IPHONE_DIR)),
    (IPAD_DISPLAY_TYPE, sorted_pngs(IPAD_DIR)),
]

for display_type, files in uploads:
    screenshot_set_id = get_or_create_set(localization_id, display_type)
    print(f"Uploading {len(files)} screenshot(s) to {display_type} set {screenshot_set_id}")
    for path in files:
        create_screenshot(screenshot_set_id, path)

print("All screenshot uploads completed.")
PY
