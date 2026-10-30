#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP_DIR="$PROJECT_DIR/build/键览.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/build/module-cache"
xcrun swift -module-cache-path "$PROJECT_DIR/build/module-cache" scripts/icon.swift "$PROJECT_DIR/build/AppIcon.icns"
xcrun swiftc -swift-version 5 -O -module-cache-path "$PROJECT_DIR/build/module-cache" -target arm64-apple-macosx14.0 Sources/KeyAtlas/*.swift -o "$APP_DIR/Contents/MacOS/KeyAtlas" -framework SwiftUI -framework AppKit -framework Carbon
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KeyAtlas</string>
<key>CFBundleIdentifier</key><string>com.local.keyatlas</string>
<key>CFBundleName</key><string>键览</string>
<key>CFBundleDisplayName</key><string>键览</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>KeyAtlas · Local-first shortcut viewer</string>
</dict></plist>
PLIST
if [ -f "$PROJECT_DIR/build/AppIcon.icns" ]; then cp "$PROJECT_DIR/build/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"; fi
codesign --force --deep --sign - "$APP_DIR"
printf '%s\n' "$APP_DIR"
