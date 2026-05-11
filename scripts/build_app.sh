#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Homebew Menubar"
EXECUTABLE_NAME="HomebewMenubar"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
BUILD_DIR="$ROOT_DIR/.build/$BUILD_CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.mohittilwani.homebew-menubar}"
ENABLE_SPARKLE="${ENABLE_SPARKLE:-0}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://raw.githubusercontent.com/MohitTilwani15/homebrew-update/main/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/version.env"
fi

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

SPARKLE_PLIST_ENTRIES=""
if [[ "$ENABLE_SPARKLE" == "1" ]]; then
  if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SPARKLE_PUBLIC_ED_KEY is required when ENABLE_SPARKLE=1." >&2
    echo "Generate one with Sparkle's generate_keys tool and keep the private key out of git." >&2
    exit 1
  fi

  SPARKLE_PLIST_ENTRIES="  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUAutomaticallyUpdate</key>
  <true/>"
fi

cd "$ROOT_DIR"
ENABLE_SPARKLE="$ENABLE_SPARKLE" swift build -c "$BUILD_CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"

if [[ "$ENABLE_SPARKLE" == "1" ]]; then
  SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d -not -path "*/dSYMs/*" | head -n 1 || true)"
  if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Could not find Sparkle.framework after build." >&2
    exit 1
  fi

  mkdir -p "$FRAMEWORKS_DIR"
  cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$EXECUTABLE_NAME" 2>/dev/null || true
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_IDENTIFIER</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Homebew Menubar opens Terminal when Homebrew needs your password to finish an update.</string>
$SPARKLE_PLIST_ENTRIES
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
