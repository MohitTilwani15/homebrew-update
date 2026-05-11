#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATES_DIR="$ROOT_DIR/dist/sparkle-updates"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/version.env"
fi

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
ARCHIVE_PATH="${1:-$ROOT_DIR/dist/Homebew-Menubar-$MARKETING_VERSION.zip}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/MohitTilwani15/homebrew-update/releases/download/v$MARKETING_VERSION/}"
GENERATE_APPCAST="${GENERATE_APPCAST:-$(command -v generate_appcast || true)}"

if [[ -z "$GENERATE_APPCAST" ]]; then
  echo "Could not find Sparkle generate_appcast." >&2
  echo "Set GENERATE_APPCAST=/path/to/generate_appcast from a Sparkle distribution." >&2
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Missing release archive: $ARCHIVE_PATH" >&2
  exit 1
fi

rm -rf "$UPDATES_DIR"
mkdir -p "$UPDATES_DIR"
cp "$ARCHIVE_PATH" "$UPDATES_DIR/"

ARGS=()
if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  ARGS+=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
fi
ARGS+=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")
ARGS+=("$UPDATES_DIR")

"$GENERATE_APPCAST" "${ARGS[@]}"

if [[ ! -f "$UPDATES_DIR/appcast.xml" ]]; then
  echo "generate_appcast did not create $UPDATES_DIR/appcast.xml" >&2
  exit 1
fi

cp "$UPDATES_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"

echo "Updated $ROOT_DIR/appcast.xml"
