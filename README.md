# Homebew Menubar

A native macOS menu bar app for keeping Homebrew packages up to date.

Homebew Menubar sits in the menu bar, checks Homebrew for outdated formulae and casks, and can update everything automatically in the background. The icon is a beer glass: full when everything is current, empty when updates are waiting, and partially filled while checks or updates are running.

## Features

- Native macOS menu bar app built with Swift and AppKit.
- Beer glass status icon for current, outdated, checking, and updating states.
- Background auto-update enabled by default.
- Configurable minimum package age before background auto-update.
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
- Free distribution: unsigned GitHub release zip and Homebrew Cask support.

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

## Minimum Package Age

Homebew Menubar can delay background auto-updates until an available update has been observed for a minimum age. This helps reduce the blast radius of compromised or accidentally broken package releases by avoiding immediate automatic installation.

The default delay is **1 day**. Available options are:

- No delay.
- 1 day.
- 3 days.
- 7 days.

This is based on when Homebew Menubar first sees that specific package/version as outdated, because Homebrew does not expose a reliable upstream release timestamp for every formula and cask in the regular outdated check.

Manual updates are still immediate. If you click **Update All Packages** or choose a specific package, the app treats that as an explicit override.

## Password-Required Casks

Some casks uninstall or replace files with `sudo`, which requires an interactive password prompt. Menu bar apps do not have a terminal attached, so Homebew Menubar does not try to collect passwords itself.

When this happens, the app shows **Open Terminal to Finish**. Clicking it opens Terminal with the exact Homebrew command so macOS and Homebrew can ask for the password normally. After Terminal finishes, return to the app and choose **Refresh**.

## Settings

Open **Settings...** from the menu or press `Command + ,`.

Settings include:

- App version and app update status.
- Auto update in background.
- Launch at login.
- Check frequency.
- Minimum package age before auto-update.
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

Version metadata comes from:

```text
version.env
```

## Run During Development

```bash
swift run HomebewMenubar
```

## Install Locally

Build the app, then move `dist/Homebew Menubar.app` into `/Applications` or `~/Applications`.

## Free Distribution Model

The free launch path does not require the Mac App Store or an Apple Developer Program membership:

- GitHub Releases host an unsigned zip: `Homebew-Menubar-<version>.zip`.
- Homebrew installs use a Cask and update through `brew`.
- Direct zip installs are manual updates from GitHub Releases.
- A DMG can still be built for private/manual distribution.

Unsigned builds can trigger Gatekeeper warnings. Users may need to right-click the app and choose **Open** the first time.

## Free Release

Build the unsigned release zip and print the cask SHA:

```bash
./scripts/release_free.sh
```

The zip is written to:

```text
dist/Homebew-Menubar-<version>.zip
```

Create the GitHub release:

```bash
git tag v0.1.0
gh release create v0.1.0 \
  dist/Homebew-Menubar-0.1.0.zip \
  --title "Homebew Menubar 0.1.0" \
  --notes "Unsigned macOS build. If Gatekeeper blocks first launch, right-click the app and choose Open."
```

## Optional Paid Release Path

Developer ID signing, notarization, and seamless Sparkle updates require the Apple Developer Program.

The optional paid path is still in the repo for later:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
NOTARYTOOL_KEYCHAIN_PROFILE="homebew-menubar-notary" \
SPARKLE_PUBLIC_ED_KEY="YOUR_SPARKLE_PUBLIC_ED_KEY" \
./scripts/sign_and_notarize.sh
```

Then generate the Sparkle appcast:

```bash
SPARKLE_PRIVATE_KEY_FILE="/path/to/sparkle-private-key" \
GENERATE_APPCAST="/path/to/Sparkle/bin/generate_appcast" \
./scripts/make_appcast.sh
```

## App Updates

Free direct installs are updated manually from GitHub Releases. Settings shows the current app version and an **Open Releases** button.

Homebrew Cask installs update through `brew`. Settings shows the current app version and an **Update & Relaunch** button that runs the brew update flow.

Sparkle remains optional for future signed releases.

App update controls live in **Settings**, not in the menu bar menu. Settings shows the current app version, an update status, and one action button:

- **Open Releases** for unsigned direct installs.
- **Update & Relaunch** for Homebrew installs.
- **Check Again** or **Update & Relaunch** for future Sparkle-enabled signed builds.

Release builds enable Sparkle by setting:

```bash
ENABLE_SPARKLE=1
SPARKLE_PUBLIC_ED_KEY="..."
```

The build script writes these Sparkle keys into `Info.plist`:

- `SUFeedURL`: `https://raw.githubusercontent.com/MohitTilwani15/homebrew-update/main/appcast.xml`
- `SUPublicEDKey`: the public EdDSA key from Sparkle.
- `SUEnableAutomaticChecks`: enabled.
- `SUAutomaticallyUpdate`: enabled.

Homebrew Cask installs disable in-app Sparkle updates at runtime.

## Homebrew Cask

Create a separate tap repository, for example:

```text
MohitTilwani15/homebrew-tap
```

Copy `homebrew-cask-template.rb` into that tap as:

```text
Casks/homebew-menubar.rb
```

After each GitHub release:

```bash
shasum -a 256 dist/Homebew-Menubar-0.1.0.zip
```

Update the cask `version`, `sha256`, and `url`, then test:

```bash
brew uninstall --cask homebew-menubar || true
brew untap MohitTilwani15/tap || true
brew tap MohitTilwani15/tap
brew install --cask MohitTilwani15/tap/homebew-menubar
open -a "Homebew Menubar"
```

Users can then install with:

```bash
brew install --cask MohitTilwani15/tap/homebew-menubar
```

## Create a DMG

The DMG path remains available for private/manual distribution:

```bash
./scripts/build_dmg.sh
```

The DMG is written to:

```text
dist/Homebew-Menubar.dmg
```

For the free public flow, prefer the unsigned zip plus Homebrew Cask.

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
- `Sparkle`: enabled only for release builds with `ENABLE_SPARKLE=1`.

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
- Update `version.env`.
- Finalize release notes.
- Build the unsigned release zip with `./scripts/release_free.sh`.
- Tag the release.
- Upload the zip to GitHub Releases.
- Update and test the Homebrew tap cask.
- Confirm direct install opens GitHub Releases from Settings.
- Confirm Homebrew install updates via `brew`.

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
