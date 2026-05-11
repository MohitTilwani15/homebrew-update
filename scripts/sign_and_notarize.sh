#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Homebew Menubar"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
ENTITLEMENTS="$ROOT_DIR/entitlements.plist"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/version.env"
fi

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ZIP_PATH="$DIST_DIR/Homebew-Menubar-$MARKETING_VERSION.zip"
NOTARY_ZIP_PATH="$DIST_DIR/Homebew-Menubar-$MARKETING_VERSION-notary.zip"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
  echo "CODE_SIGN_IDENTITY is required." >&2
  echo "Example: CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAM_ID)' ./scripts/sign_and_notarize.sh" >&2
  echo "For local ad-hoc testing: CODE_SIGN_IDENTITY='-' SKIP_NOTARIZE=1 ./scripts/sign_and_notarize.sh" >&2
  exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  ENABLE_SPARKLE="${ENABLE_SPARKLE:-1}" "$ROOT_DIR/scripts/build_app.sh"
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

SIGN_ARGS=(
  --force
  --deep
  --options runtime
  --entitlements "$ENTITLEMENTS"
  --sign "$CODE_SIGN_IDENTITY"
)

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--timestamp)
fi

codesign "${SIGN_ARGS[@]}" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$NOTARY_ZIP_PATH" "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$NOTARY_ZIP_PATH"

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
  NOTARY_ARGS=()
  if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
    NOTARY_ARGS+=(--keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE")
  elif [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
    NOTARY_ARGS+=(--key "$APP_STORE_CONNECT_API_KEY_PATH" --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID")
  else
    echo "Notarization credentials are required." >&2
    echo "Set NOTARYTOOL_KEYCHAIN_PROFILE, or APP_STORE_CONNECT_API_KEY_PATH/APP_STORE_CONNECT_KEY_ID/APP_STORE_CONNECT_ISSUER_ID." >&2
    exit 1
  fi

  xcrun notarytool submit "$NOTARY_ZIP_PATH" "${NOTARY_ARGS[@]}" --wait
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  spctl --assess --type execute --verbose "$APP_DIR"
fi

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
rm -f "$NOTARY_ZIP_PATH"

echo "Built signed release zip $ZIP_PATH"
echo "Version $MARKETING_VERSION build $BUILD_NUMBER"
