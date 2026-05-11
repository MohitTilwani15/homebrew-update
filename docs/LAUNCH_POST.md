# Launch Post Notes

Target post date: May 13, 2026.

## Short Description

Homebew Menubar is a tiny native macOS menu bar app that keeps Homebrew packages up to date. It shows a beer glass in the menu bar: empty when updates are waiting, filling while updates run, and full when everything is current.

## Suggested Launch Post

I built a small macOS menu bar app for keeping Homebrew packages up to date.

It sits in the menu bar as a beer glass:

- empty glass: packages need updates
- filling glass: update in progress
- full glass: everything is current

It can auto-update in the background, lets you update one specific package when needed, shows progress, handles `sudo` casks by opening Terminal, and has a tiny cheers animation when everything is done.

Built with Swift/AppKit.

Repo: https://github.com/MohitTilwani15/homebrew-update

## Short Variant

Made a tiny macOS menu bar app that keeps Homebrew packages updated.

The icon is a beer glass. Empty means updates are waiting. Full means everything is current.

It supports background auto-updates, single-package updates, progress, stop, Terminal handoff for password-required casks, and a small cheers animation.

https://github.com/MohitTilwani15/homebrew-update

## Screenshot Checklist

Capture these before posting:

- Menu bar with empty beer icon and outdated package count.
- Open menu showing `Update All Packages` and `Update One Package`.
- Settings window with auto-update and frequency controls.
- Updating state with percentage.
- Full beer icon after success.

## Demo Flow

1. Open the app.
2. Show the beer icon in the menu bar.
3. Open the menu and show update count.
4. Open `Update One Package`.
5. Open Settings with `Command + ,`.
6. Trigger or show an update progress state.
7. End on the full beer glass.

## Talking Points

- Menu bar apps should be quiet by default, but still visible when action is needed.
- Homebrew casks sometimes require `sudo`, so the app hands that work to Terminal instead of trying to collect passwords.
- Auto-update is on by default, but users can switch to manual-only or choose a frequency.
- It is native Swift/AppKit, not Electron.

