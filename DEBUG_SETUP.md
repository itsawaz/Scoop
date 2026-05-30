# Debug Build Setup for iOS

## Overview
This document explains how to set up and run a debug version of the Scoop app on an iOS device for development and debugging purposes.

## Prerequisites
- macOS with Xcode installed
- iOS device (iPhone 17) connected via USB
- Apple Developer account (free tier works for development)

## Setup Steps

### 1. Open the iOS Project in Xcode
```bash
open ios/Runner.xcworkspace
```

### 2. Configure Xcode for Debug Build

#### Select Your Device
- In Xcode, select your connected iPhone 17 from the device dropdown at the top

#### Enable Debugging
- Go to **Runner** target → **Signing & Capabilities**
- Ensure "Automatically manage signing" is checked
- Select your team from the Team dropdown
- Xcode will automatically create/update provisioning profiles

#### Enable Developer Mode (iOS 16+)
- On your iPhone, go to Settings → Privacy & Security → Developer Mode
- Enable Developer Mode and restart your device if prompted

### 3. Build and Run in Debug Mode

#### Option A: Using Xcode
1. Select **Product → Run** (or press `Cmd + R`)
2. Xcode will build the debug version and install it on your device
3. The app will launch automatically

#### Option B: Using Flutter CLI
```bash
flutter run --debug
```

### 4. Access Debug Information

#### Flutter DevTools
- When running with `flutter run --debug`, you'll see a message like:
  ```
  Flutter DevTools is available at: http://127.0.0.1:9100
  ```
- Open this URL in your browser to access:
  - Widget inspector
  - Performance overlay
  - Network timeline
  - Dart debugger
  - Logging

#### Xcode Console
- View app logs in Xcode's **View → Debug Area → Activate Console** (or `Cmd + Shift + C`)

### 5. Hot Reload and Hot Restart
While the app is running:
- Press `r` in the terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

## Troubleshooting

### App Won't Install
- Ensure Developer Mode is enabled on your iPhone
- Check that your Apple ID is selected in Xcode signing settings
- Try cleaning the build: `flutter clean && flutter pub get`

### Connection Issues
- Ensure your iPhone is connected via USB
- Trust the computer when prompted on your iPhone
- Try disconnecting and reconnecting the USB cable

### Provisioning Profile Errors
- In Xcode: Product → Clean Build Folder
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/`
- Run: `flutter clean && flutter pub get`

## Future Reference Commands

### Quick Start
```bash
# Get dependencies
flutter pub get

# Open in Xcode
open ios/Runner.xcworkspace

# Run in debug mode
flutter run --debug
```

### Build Debug IPA (for distribution testing)
```bash
flutter build ios --debug --no-codesign
```

### View Logs
```bash
# Using Flutter
flutter logs

# Using Xcode Organizer (Window → Devices and Simulators)
```

## Notes
- Debug builds are not optimized for performance
- Debug builds include debugging symbols and DevTools integration
- For App Store distribution, use release builds: `flutter build ios --release`
## Health Data Debugging

### Checking Basal Energy Data

When the app runs, check the terminal output for these log messages:

```
[HealthService] === Health Data Summary ===
[HealthService] Active energy points: X
[HealthService] Basal energy points: X
[HealthService] Active calories: X.X
[HealthService] Basal calories: X.X
[HealthService] Steps: XXXX
```

If you see `WARNING: No basal energy data found in HealthKit!`, that confirms the issue.

### Common Issue: Basal Energy Shows 0

**Why this happens:**
- Apple Health doesn't automatically track basal energy (resting calories)
- Requires Apple Watch with metabolic tracking OR manual entry
- The app may not have permission to read basal energy data

**To check if data exists in Health app:**
1. Open Health app
2. Go to **Browse** → **Activity** → **Basal Energy Burned**
3. Check if any data exists for today

**To fix:**
1. Ensure Developer Mode is enabled on iPhone
2. Check Settings → Privacy → Health → Scoop permissions
3. If using Apple Watch, verify Watch app permissions
4. Consider adding manual basal energy entry in Health app
