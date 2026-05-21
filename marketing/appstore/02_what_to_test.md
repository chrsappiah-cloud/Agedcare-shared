# What to Test — TestFlight release notes

Paste into:
**App Store Connect → TestFlight → iOS Builds → [build] → Test Details →
What to Test (en-US)**

Keep under 4 000 characters.

---

**Build 1.0.4 (117)**

Thank you for joining the AgedCare Monitor beta on the **WCS Care** track. This
build is the App Store submission candidate: Xcode 26.5, hardened production
TestFlight signing (skips stale provisioning profiles), App Store metadata pack,
and XCUITest fixes for iOS 26 permission alerts.

Please test:

1. **Hero Panel Router** — verify both the Resident and Staff cards appear on
   first launch and route to the correct shell.
2. **Staff sign-in** — use admin@gvcare.com / password, then nurse@ and carer@
   to confirm role-based dashboards differ.
3. **Resident timeline + alerts** — create a manual alert via *Alerts → Add
   Alert*; confirm it persists across app relaunch.
4. **Live weather card** — on the resident home view, confirm the outdoor
   weather card shows your local temperature within about 10 seconds.
5. **HomeKit room temperature** — if you have a HomeKit temperature sensor,
   pair it in Settings → Room sensors and confirm the room reading appears
   alongside the outdoor reading.
6. **Watch companion** — on a paired Apple Watch, launch AgedcareWatchApp and
   confirm the dashboard shows the same resident summary as the phone.
7. **Account deletion** — Settings → Account → Delete Account; confirm full
   purge and that re-signing in starts from a fresh demo facility.

Known limits in this build:

- CloudKit live-sync tests are skipped in CI; if you are signed out of iCloud
  the sync indicator will stay grey — this is expected.
- The "Promotional Materials" view is staff-preview only and will not show for
  Resident-shell sessions.

Feedback: christopher.appiahthompson@myworldclass.org
