#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/version.env"
fi

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
TAG="v$MARKETING_VERSION"
ZIP_PATH="$ROOT_DIR/dist/Homebew-Menubar-$MARKETING_VERSION.zip"

"$ROOT_DIR/scripts/package_release_zip.sh"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

cat <<EOF
Free release artifact ready:
  $ZIP_PATH

SHA256:
  $SHA256

Create the GitHub release:
  gh release create $TAG "$ZIP_PATH" \\
    --title "Homebew Menubar $MARKETING_VERSION" \\
    --notes "Unsigned macOS build. If Gatekeeper blocks first launch, right-click the app and choose Open."

Update the Homebrew cask:
  version "$MARKETING_VERSION"
  sha256 "$SHA256"

Then commit the cask in your tap repository.
EOF
