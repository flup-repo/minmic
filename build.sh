#!/bin/bash

APP_NAME="MinMic"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building $APP_NAME..."

# Create App bundle directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

# Compile Swift files
swiftc Sources/*.swift -o "$MACOS_DIR/$APP_NAME" -target arm64-apple-macosx13.0 -target x86_64-apple-macosx13.0 -O

echo "Build complete: $APP_BUNDLE"

# Build DMG
DMG_NAME="${APP_NAME}.dmg"
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"
echo "Done! DMG is at $DMG_NAME"
