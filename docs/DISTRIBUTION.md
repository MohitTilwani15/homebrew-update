# Distribution

This app can be shared privately as an unsigned `.app`, but public distribution should use Developer ID signing and notarization so Gatekeeper trusts it.

## Recommended Public Distribution

1. Join the Apple Developer Program.
2. Create a `Developer ID Application` certificate.
3. Build the app:

```bash
./scripts/build_app.sh
```

4. Sign the app with hardened runtime and the Apple Events entitlement:

```bash
codesign --force --deep \
  --options runtime \
  --timestamp \
  --entitlements entitlements.plist \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "dist/Homebew Menubar.app"
```

5. Zip the app:

```bash
ditto -c -k --keepParent \
  "dist/Homebew Menubar.app" \
  "dist/Homebew-Menubar.zip"
```

6. Notarize:

```bash
xcrun notarytool submit "dist/Homebew-Menubar.zip" \
  --keychain-profile "notarytool-password" \
  --wait
```

7. Staple:

```bash
xcrun stapler staple "dist/Homebew Menubar.app"
```

8. Publish the zip or a DMG through GitHub Releases.

## Entitlements

The app opens Terminal when Homebrew needs an interactive password prompt, so signing should include:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.automation.apple-events</key>
  <true/>
</dict>
</plist>
```

## Private Sharing

For a quick private test, zip the unsigned `.app`. Recipients may need to right-click and choose Open because the app is not signed or notarized.

That is acceptable for small private testing, but it is not a good public release experience.

