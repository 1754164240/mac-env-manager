#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Mac Env Manager.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release
ICON_PATH="$(swift "$ROOT_DIR/scripts/generate-icon.swift")"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/MacEnvManager" "$MACOS_DIR/MacEnvManager"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MacEnvManager</string>
  <key>CFBundleIdentifier</key>
  <string>local.mac-env-manager</string>
  <key>CFBundleName</key>
  <string>Mac Env Manager</string>
  <key>CFBundleDisplayName</key>
  <string>Mac Env Manager</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

clean_app_xattrs() {
  xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
  xattr -d "com.apple.fileprovider.fpfs#P" "$APP_DIR" 2>/dev/null || true
  xattr -cr "$APP_DIR"
}

clean_app_xattrs
codesign --force --deep --sign - "$APP_DIR"
clean_app_xattrs

echo "$APP_DIR"
