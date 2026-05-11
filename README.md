# Homebew Menubar

A small native macOS menu bar app that keeps Homebrew packages up to date.

The menu bar icon is a beer glass:

- Full beer glass: all Homebrew packages are current.
- Empty beer glass: one or more packages need updates.
- Partial beer glass: checking or updating.

Click the beer icon and choose **Update Packages**. The refresh item shows an update icon with an estimated percent while the app runs:

```text
brew update
brew upgrade --formula ...
brew upgrade --cask ...
```

When multiple packages are outdated, use **Update One Package** to choose a specific formula or cask. Each item shows the package name and version change in the menu, while the main status still stays count-based.

The update menu also shows a **Stop Update** item while Homebrew is running. Choosing it sends an interrupt to the active `brew` process, then terminates it if it is still running after a short grace period.

Some casks uninstall or replace files with `sudo`, which requires an interactive password prompt. In that case the app shows **Open Terminal to Finish** so Homebrew can ask for your password in Terminal. When Terminal finishes, return to the app and choose **Refresh**.

When the update finishes, the app checks `brew outdated --quiet` again and returns the icon to full when everything is current.

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

## Install

Build the app, then move `dist/Homebew Menubar.app` into `/Applications` or `~/Applications`.
