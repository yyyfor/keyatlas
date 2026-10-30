#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP_DIR="$PROJECT_DIR/build/键览.app"
if [ ! -f "$APP_DIR/Contents/MacOS/KeyAtlas" ]; then
  bash scripts/build.sh
fi
codesign --verify --deep --strict "$APP_DIR"
APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
ARCHIVE_NAME="KeyAtlas-${APP_VERSION}-macOS-arm64.zip"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP_DIR" "$PROJECT_DIR/build/$ARCHIVE_NAME"
cd "$PROJECT_DIR/build"
shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
printf '%s\n' "$PROJECT_DIR/build/$ARCHIVE_NAME"
