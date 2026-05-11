#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Homebew Menubar"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/version.env"
fi

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
ZIP_NAME="${ZIP_NAME:-Homebew-Menubar-$MARKETING_VERSION.zip}"
ZIP_PATH="$ROOT_DIR/dist/$ZIP_NAME"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/build_app.sh"
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Built $ZIP_PATH"
