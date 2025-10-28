# Flutter Game Framework - Example App

A comprehensive example demonstrating the Flutter Game Framework capabilities.

## Features Demonstrated

This example app showcases:

- **Engine Initialization** - Proper setup of Unity engine plugin
- **Lifecycle Management** - Automatic pause/resume/destroy handling
- **Bidirectional Communication** - Flutter ↔ Unity message passing
- **Event Logging** - Real-time event stream monitoring
- **UI Controls** - Control panel for testing engine operations

## Getting Started

### Prerequisites

- Flutter 3.10.0 or higher
- Unity 2022.3.x (for building Unity content)
- Android SDK or Xcode (for mobile testing)

### Running the Example

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on Android:**
   ```bash
   flutter run -d android
   ```

3. **Run on iOS:**
   ```bash
   flutter run -d ios
   ```

4. **Run on Web:**
   ```bash
   flutter run -d chrome
   ```

## What's Included

### Main Features

- **Game Widget** - Full-screen Unity game integration
- **Control Panel** - UI for sending messages and testing operations
- **Event Log** - Real-time display of engine events
- **Debug Console** - Message history and debugging tools

### Code Examples

The example demonstrates:

```dart
// Initialize Unity engine
UnityEnginePlugin.initialize();

// Embed game in Flutter UI
GameWidget(
  engineType: GameEngineType.unity,
  onEngineCreated: (controller) {
    // Engine ready - send initial message
    controller.sendMessage('GameManager', 'Start', 'level1');
  },
  onMessage: (message) {
    // Handle messages from Unity
    print('Unity says: ${message.data}');
  },
)
```

## Unity Project Setup

To test with actual Unity content:

1. Create a Unity project (2022.3.x)
2. Add Flutter bridge scripts from `engines/unity/plugin/`
3. Build for Android/iOS using **Flutter > Export for Flutter**
4. The exported build will be integrated automatically

See the [Unity Plugin Guide](../engines/unity/plugin/README.md) for details.

## Troubleshooting

### "No Unity project found"

This is expected - the example runs with a mock Unity instance. To test with real Unity content, follow the Unity Project Setup steps above.

### Platform-specific issues

- **Android:** Ensure Android SDK is installed and configured
- **iOS:** Requires Xcode and CocoaPods
- **Web:** WebGL builds require additional setup (see WEBGL_GUIDE.md)

## Learn More

- [Quick Start Guide](../QUICK_START.md)
- [Unity Plugin Guide](../engines/unity/plugin/README.md)
- [API Documentation](../lib/gameframework.dart)
- [Full Documentation](../README.md)

## License

MIT License - see [LICENSE](../LICENSE) file for details.
