#!/bin/bash

# Create a DMG installer for MeetingAlert
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
APP_NAME="MeetingAlert"
VERSION="1.0"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="$DIST_DIR/${APP_NAME}-temp.dmg"
DMG_FINAL="$DIST_DIR/$DMG_NAME"

echo "🚀 Creating DMG installer for $APP_NAME v$VERSION..."

# Ensure app is built
APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found. Building first..."
    "$SCRIPT_DIR/build-release.sh"
fi

# Create DMG
echo "📦 Creating DMG..."
mkdir -p "$DIST_DIR"

# Create a temporary directory for DMG contents
DMG_CONTENTS="$DIST_DIR/dmg-contents"
rm -rf "$DMG_CONTENTS"
mkdir -p "$DMG_CONTENTS"

# Copy app to DMG contents
cp -R "$APP_PATH" "$DMG_CONTENTS/"

# Create Applications symlink
ln -s /Applications "$DMG_CONTENTS/Applications"

# Create DMG
hdiutil create -srcfolder "$DMG_CONTENTS" -volname "$APP_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 100m "$DMG_TEMP"

# Mount the DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | egrep '^/dev/' | sed 1q | awk '{print $1}')

# Wait for mount
sleep 2

# Set DMG properties
echo '
   tell application "Finder"
     tell disk "'$APP_NAME'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 920, 420}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 72
           set position of item "'$APP_NAME'.app" of container window to {160, 205}
           set position of item "Applications" of container window to {360, 205}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript

# Unmount
hdiutil detach "$DEVICE"

# Convert to read-only and compress
echo "🗜️  Compressing DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"

# Clean up
rm -rf "$DMG_TEMP" "$DMG_CONTENTS"

echo ""
echo "✅ DMG created successfully!"
echo "📦 DMG: $DMG_FINAL"
echo "🎉 Ready for distribution!"

