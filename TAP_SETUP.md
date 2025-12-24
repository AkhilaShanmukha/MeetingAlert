# Homebrew Tap Setup Guide

This guide explains how to set up a Homebrew tap to distribute MeetingAlert.

## Step 1: Create a GitHub Repository

1. Create a new repository on GitHub (e.g., `MeetingAlert`)
2. Push your code to the repository

## Step 2: Create a Homebrew Tap Repository

1. Create a new repository named `homebrew-meetingalert` (or `homebrew-tap`)
2. This will be your tap repository

## Step 3: Build and Release

1. Build the release version:
   ```bash
   ./scripts/build-release.sh
   ```

2. Create a GitHub release:
   - Go to your GitHub repository
   - Click "Releases" > "Create a new release"
   - Tag: `v1.0`
   - Upload `dist/MeetingAlert-1.0.zip`

3. Get the SHA256:
   ```bash
   shasum -a 256 dist/MeetingAlert-1.0.zip
   ```

## Step 4: Update the Formula

1. Edit `Formula/meetingalert.rb`:
   - Update `homepage` with your GitHub URL
   - Update `url` with the release URL
   - Update `sha256` with the SHA256 from step 3

2. Copy the formula to your tap repository:
   ```bash
   # In your tap repository
   mkdir -p Formula
   cp MeetingAlert/Formula/meetingalert.rb Formula/
   ```

## Step 5: Publish the Tap

1. Commit and push to your tap repository:
   ```bash
   cd homebrew-meetingalert
   git add Formula/meetingalert.rb
   git commit -m "Add MeetingAlert formula"
   git push
   ```

## Step 6: Installation Instructions

Users can now install with:

```bash
brew tap yourusername/meetingalert
brew install meetingalert
```

## Alternative: Direct Installation

If you don't want to set up a tap, you can:

1. Host the ZIP file somewhere (GitHub releases, your website, etc.)
2. Users can install directly:
   ```bash
   brew install --build-from-source Formula/meetingalert.rb
   ```

Or create a DMG for easier distribution:

```bash
./scripts/create-dmg.sh
```

The DMG will be in `dist/MeetingAlert-1.0.dmg` and can be shared directly.

