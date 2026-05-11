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
- Update history and last checked status.

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

## Distribution

For public distribution, sign and notarize the app with an Apple Developer ID certificate. See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).

## Project Notes

- Requires macOS 13 or newer.
- Requires Homebrew installed at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`.
- The app does not send package data anywhere.
- Auto-update is on by default for new installs.

## Launch Materials

Planning to post about the project? See [docs/LAUNCH_POST.md](docs/LAUNCH_POST.md).
