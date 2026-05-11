# Release Checklist

Use this before publishing a GitHub Release or posting publicly.

## Preflight

- Confirm `README.md` reflects the current behavior.
- Build release app:

```bash
./scripts/build_app.sh
```

- Launch the app locally.
- Confirm the menu opens.
- Confirm Settings opens with `Command + ,`.
- Confirm `brew outdated --json=v2` works locally.
- Confirm update-all starts and can be stopped.
- Confirm `Update One Package` appears when outdated packages exist.
- Confirm Terminal handoff works for password-required casks.

## Packaging

- Sign the app.
- Notarize the zip.
- Staple the app.
- Re-zip the stapled app.
- Upload to GitHub Releases.

## Release Notes Template

```markdown
## Homebew Menubar v0.1.0

Initial public release.

### Highlights

- Native macOS menu bar app for Homebrew updates.
- Background auto-update.
- Update all or one specific package.
- Progress, stop update, and update history.
- Terminal handoff for password-required casks.
- Settings window with launch-at-login and frequency controls.

### Requirements

- macOS 13+
- Homebrew
```

