# MeetingAlert

A macOS menu bar app that displays your upcoming calendar meetings and automatically opens Zoom links when clicked.

## Features

- 📅 Shows next/current meeting name in menu bar
- 📋 Dropdown menu with list of upcoming events
- 🎥 Auto-opens Zoom links when clicking on meetings
- 🔔 Full-screen alerts for meetings starting soon
- 🎯 Menu bar only (no dock icon)

## Requirements

- macOS 13.0 (Ventura) or later
- Calendar access permissions

## Installation

### Option 1: Homebrew Tap (Recommended)

```bash
# Add the tap
brew tap AkhilaShanmukha/meetingalert

# Install the app
brew install meetingalert

# Open the app
open /opt/homebrew/Cellar/meetingalert/1.0/MeetingAlert.app
```

### Option 2: Manual Installation

1. Download the latest release from [Releases](https://github.com/AkhilaShanmukha/MeetingAlert/releases)
2. Extract the ZIP file
3. Move `MeetingAlert.app` to your Applications folder
4. Open the app from Applications
5. Grant calendar permissions when prompted

### Option 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/AkhilaShanmukha/MeetingAlert.git
cd MeetingAlert

# Build the app
xcodebuild -scheme MeetingAlert -destination 'platform=macOS' -configuration Release -derivedDataPath ./build build

# The app will be in: build/Build/Products/Release/MeetingAlert.app
```

## Usage

1. **First Launch**: The app will request calendar permissions. Grant full access to calendars.

2. **Menu Bar**: Look for the meeting name (or "MA" if no meetings) in the top-right menu bar.

3. **View Meetings**: Click the menu bar item to see a dropdown list of upcoming meetings.

4. **Join Zoom**: Click any meeting with a Zoom link (marked with a video icon) to automatically open it.

5. **Meeting Alerts**: The app will show a full-screen alert when a Zoom meeting is about to start.

## Permissions

The app requires:
- **Full Calendar Access**: To read meeting details and detect Zoom links
- **Network Access**: To open Zoom links in your browser

## Troubleshooting

### App not showing in menu bar
- Check if the app is running in Activity Monitor
- Try quitting and reopening the app
- Check Console.app for error messages

### Calendar permissions not working
- Go to System Settings > Privacy & Security > Calendars
- Ensure "MeetingAlert" has "Full Access" enabled

### Zoom links not opening
- Ensure the meeting has a Zoom URL in the notes or location field
- Check that the URL format is correct (zoom.us)

## Building for Distribution

To create a distributable version:

```bash
# Build release version
./scripts/build-release.sh

# This creates: dist/MeetingAlert-1.0.zip
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions welcome! Please open an issue or pull request.

## Support

For issues or questions, please open an issue on GitHub.

