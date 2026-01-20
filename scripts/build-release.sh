#!/bin/bash

# Build script for MeetingAlert distribution
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
APP_NAME="MeetingAlert"
VERSION="1.3"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

echo "🚀 Building $APP_NAME v$VERSION for distribution..."

# Clean previous builds
echo "📦 Cleaning previous builds..."
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build the app
echo "🔨 Building app..."
cd "$PROJECT_DIR"
xcodebuild -scheme "$APP_NAME" \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build

# Check if build succeeded
APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed - app not found at $APP_PATH"
    exit 1
fi

echo "✅ Build successful!"

# Create distribution package
echo "📦 Creating distribution package..."
cd "$BUILD_DIR/Build/Products/Release"
zip -r "$DIST_DIR/$ZIP_NAME" "${APP_NAME}.app" > /dev/null

# Calculate SHA256 for Homebrew formula
SHA256=$(shasum -a 256 "$DIST_DIR/$ZIP_NAME" | awk '{print $1}')
SIZE=$(stat -f%z "$DIST_DIR/$ZIP_NAME")

# Format size (macOS compatible)
if command -v numfmt >/dev/null 2>&1; then
    SIZE_FORMATTED=$(numfmt --to=iec-i --suffix=B $SIZE)
else
    # Fallback for macOS
    SIZE_FORMATTED=$(awk "BEGIN {printf \"%.1fKB\", $SIZE/1024}")
fi

echo ""
echo "✅ Distribution package created!"
echo "📦 Package: $DIST_DIR/$ZIP_NAME"
echo "📏 Size: $SIZE_FORMATTED"
echo "🔐 SHA256: $SHA256"
echo ""
echo "📝 Update Formula/meetingalert.rb with:"
echo "   sha256 \"$SHA256\""
echo ""
echo "🎉 Ready for distribution!"

