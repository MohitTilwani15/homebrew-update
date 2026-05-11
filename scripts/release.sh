#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/version.env"
fi

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
TAG="v$MARKETING_VERSION"
ZIP_PATH="$ROOT_DIR/dist/Homebew-Menubar-$MARKETING_VERSION.zip"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit or stash changes before releasing." >&2
  exit 1
fi

./scripts/sign_and_notarize.sh
./scripts/make_appcast.sh "$ZIP_PATH"

echo
echo "Release artifacts are ready:"
echo "  $ZIP_PATH"
echo "  $ROOT_DIR/appcast.xml"
echo
echo "Next steps, matching the CodexBar flow:"
echo "  1. Commit appcast.xml if it changed."
echo "  2. git tag $TAG"
echo "  3. gh release create $TAG '$ZIP_PATH' appcast.xml --title 'Homebew Menubar $MARKETING_VERSION'"
echo "  4. Update your Homebrew tap cask sha256 and url."
