# Architecture

Homebew Menubar is intentionally small. The app is a single SwiftPM executable target using AppKit.

## Main Pieces

- `AppDelegate`: owns the menu bar item, menu state, Settings window, timers, and update flow.
- `BrewPackageService`: runs Homebrew commands and parses `brew outdated --json=v2`.
- `BrewUpdateOperation`: performs cancellable update work and reports progress.
- `BeerIcon`: draws the beer glass icon directly with AppKit.
- `TerminalLauncher`: opens Terminal for commands that need an interactive password prompt.

## Update Flow

1. Timer or user action triggers an outdated check.
2. The app runs `brew outdated --json=v2`.
3. If packages are outdated and auto-update is enabled, the update starts.
4. The app runs `brew update`.
5. Each package is upgraded with either `brew upgrade --formula <name>` or `brew upgrade --cask <name>`.
6. If cleanup is enabled, the app runs `brew cleanup`.
7. The app checks outdated packages again.
8. If all packages are current, the beer icon returns to full.

## Password Handling

The app never asks for or stores passwords.

If Homebrew output indicates `sudo` needs a terminal password prompt, the app stops the background flow and exposes **Open Terminal to Finish**. Terminal then runs the exact Homebrew command interactively.

