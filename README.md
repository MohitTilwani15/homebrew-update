# Homebew Menubar

A native macOS menu bar app for keeping Homebrew packages up to date.

Homebew Menubar sits in the menu bar, checks Homebrew for outdated formulae and casks, and can update everything automatically in the background. The icon is a beer glass: full when everything is current, empty when updates are waiting, and partially filled while checks or updates are running.

## Features

- Native macOS menu bar app built with Swift and AppKit.
- Beer glass status icon for current, outdated, checking, and updating states.
- Background auto-update enabled by default.
- Update all packages or choose one outdated package from the menu.
- Count-based progress for update-all, package-name progress for single-package updates.
- Stop an active update from the menu.
- Terminal handoff when Homebrew needs a password for `sudo` cask work.
- Settings window with `Command + ,`.
- Launch at login support.
- Configurable check frequency: hourly, every 6 hours, daily, or manual only.
- Optional `brew cleanup` after successful updates.
- Optional macOS notifications.
- Quick cheers animation and success sound when everything is caught up.
- Update history.

## How It Works

The app checks Homebrew with:

```text
brew outdated --json=v2
```

Updates run as explicit formula or cask upgrades:

```text
brew update
brew upgrade --formula ...
brew upgrade --cask ...
```

After an update finishes, the app checks Homebrew again and returns the beer glass to full when no updates remain.

## Password-Required Casks

Some casks uninstall or replace files with `sudo`, which requires an interactive password prompt. Menu bar apps do not have a terminal attached, so Homebew Menubar does not try to collect passwords itself.

When this happens, the app shows **Open Terminal to Finish**. Clicking it opens Terminal with the exact Homebrew command so macOS and Homebrew can ask for the password normally. After Terminal finishes, return to the app and choose **Refresh**.

## Settings

Open **Settings...** from the menu or press `Command + ,`.

Settings include:

- Auto update in background.
- Launch at login.
- Check frequency.
- Run cleanup after updates.
- Notifications.
- Cheers sound.

## Build

```bash
./scripts/build_app.sh
```

The app bundle is written to:

```text
dist/Homebew Menubar.app
```

## Run During Development

```bash
swift run HomebewMenubar
```

## Install Locally

Build the app, then move `dist/Homebew Menubar.app` into `/Applications` or `~/Applications`.

## Create a DMG

You can package the app as a DMG without using the Mac App Store.

For local/private testing:

```bash
./scripts/build_dmg.sh
```

The DMG is written to:

```text
dist/Homebew-Menubar.dmg
```

That private DMG is not signed or notarized, so other people may see Gatekeeper warnings. For public distribution, use Developer ID signing and notarization before sharing the DMG.

## Public Distribution Without the Mac App Store

Yes, this app can be distributed outside the Mac App Store as a DMG. The public-friendly path is:

1. Join the Apple Developer Program.
2. Create a `Developer ID Application` certificate.
3. Build the app:

```bash
./scripts/build_app.sh
```

4. Sign the app with hardened runtime and Apple Events entitlement:

```bash
codesign --force --deep \
  --options runtime \
  --timestamp \
  --entitlements entitlements.plist \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "dist/Homebew Menubar.app"
```

5. Create the DMG from the signed app:

```bash
SKIP_BUILD=1 ./scripts/build_dmg.sh
```

6. Submit the DMG to Apple notarization:

```bash
xcrun notarytool submit "dist/Homebew-Menubar.dmg" \
  --keychain-profile "notarytool-password" \
  --wait
```

7. Staple the notarization ticket:

```bash
xcrun stapler staple "dist/Homebew-Menubar.dmg"
```

8. Verify Gatekeeper accepts the DMG:

```bash
spctl -a -vvv -t open --context context:primary-signature \
  "dist/Homebew-Menubar.dmg"
```

9. Upload `dist/Homebew-Menubar.dmg` to GitHub Releases.

### Entitlements

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

This repo includes that file as `entitlements.plist`.

## Architecture

Homebew Menubar is intentionally small. It is a single SwiftPM executable target using AppKit.

Main pieces:

- `AppDelegate`: owns the menu bar item, menu state, Settings window, timers, and update flow.
- `BrewPackageService`: runs Homebrew commands and parses `brew outdated --json=v2`.
- `BrewUpdateOperation`: performs cancellable update work and reports progress.
- `BeerIcon`: draws the beer glass icon directly with AppKit.
- `TerminalLauncher`: opens Terminal for commands that need an interactive password prompt.

Update flow:

1. Timer or user action triggers an outdated check.
2. The app runs `brew outdated --json=v2`.
3. If packages are outdated and auto-update is enabled, the update starts.
4. The app runs `brew update`.
5. Each package is upgraded with either `brew upgrade --formula <name>` or `brew upgrade --cask <name>`.
6. If cleanup is enabled, the app runs `brew cleanup`.
7. The app checks outdated packages again.
8. If all packages are current, the beer icon returns to full.

## Release Checklist

- Confirm `README.md` reflects the current behavior.
- Build release app with `./scripts/build_app.sh`.
- Launch the app locally.
- Confirm the menu opens.
- Confirm Settings opens with `Command + ,`.
- Confirm `brew outdated --json=v2` works locally.
- Confirm update-all starts and can be stopped.
- Confirm `Update One Package` appears when outdated packages exist.
- Confirm Terminal handoff works for password-required casks.
- Sign the app.
- Notarize the app.
- Staple the app.
- Build the DMG.
- Upload the DMG to GitHub Releases.

## Launch Post Notes

Short description:

> Homebew Menubar is a tiny native macOS menu bar app that keeps Homebrew packages up to date. It shows a beer glass in the menu bar: empty when updates are waiting, filling while updates run, and full when everything is current.

Suggested post:

```text
I built a small macOS menu bar app for keeping Homebrew packages up to date.

It sits in the menu bar as a beer glass:

- empty glass: packages need updates
- filling glass: update in progress
- full glass: everything is current

It can auto-update in the background, lets you update one specific package when needed, shows progress, handles sudo casks by opening Terminal, and has a tiny cheers animation when everything is done.

Built with Swift/AppKit.

Repo: https://github.com/MohitTilwani15/homebrew-update
```

Screenshot checklist:

- Menu bar with empty beer icon and outdated package count.
- Open menu showing `Update All Packages` and `Update One Package`.
- Settings window with auto-update and frequency controls.
- Updating state with percentage.
- Full beer icon after success.

## Project Notes

- Requires macOS 13 or newer.
- Requires Homebrew installed at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`.
- The app does not send package data anywhere.
- Auto-update is on by default for new installs.
