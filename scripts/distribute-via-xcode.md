# Distribute via Xcode Organizer (no API key file needed)

Use this when `AuthKey_A863K5FF84.p8` is unavailable but you are signed into Xcode with your Apple ID.

## Steps

1. Build an archive (or use the existing one):

```bash
cd /Applications/Agedcare-shared
xcodebuild archive -project Agedcare-shared.xcodeproj -scheme Agedcare-shared \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/Agedcare-release.xcarchive \
  DEVELOPMENT_TEAM=TM2WG7HH96 -allowProvisioningUpdates
```

2. Open **Window → Organizer** in Xcode (or):

```bash
open /tmp/Agedcare-release.xcarchive
```

3. Select the archive → **Distribute App** → **App Store Connect** → **Upload**
4. Follow prompts (sign in with Apple ID if asked)
5. In App Store Connect, attach the build to version **1.0.4** and **Submit for Review** (see `marketing/appstore/SUBMIT_NOW.md`)
