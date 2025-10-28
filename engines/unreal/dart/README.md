# Unreal Engine Plugin for Flutter Game Framework

[![pub package](https://img.shields.io/pub/v/gameframework_unreal.svg)](https://pub.dev/packages/gameframework_unreal)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-blue.svg)](https://pub.dev/packages/gameframework_unreal)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Integrate **Unreal Engine 5.x** into your Flutter applications with full bidirectional communication, quality settings control, console commands, and level loading.

## Features

✨ **Core Features:**
- 🎮 Full Unreal Engine 5.x integration
- 🔄 Bidirectional communication (Flutter ↔ Unreal)
- 🎯 Blueprint support for non-programmers
- 📱 Multi-platform support (Android, iOS, macOS, Windows, Linux)
- ⚡ High-performance native bridges (JNI, Objective-C++)

🎨 **Unreal-Specific Features:**
- 🎚️ Quality settings with 5 presets (low, medium, high, epic, cinematic)
- 🖥️ Console command execution (`stat fps`, `r.SetRes`, etc.)
- 🗺️ Level/map loading and streaming
- 📊 Quality level control (AA, shadows, textures, effects, etc.)
- 🎬 Blueprint events for lifecycle and messaging

## Platform Support

| Platform | Status | Requirements |
|----------|--------|--------------|
| Android | ✅ Production Ready | API 21+, NDK r25+ |
| iOS | ✅ Production Ready | iOS 12.0+, Xcode 14+ |
| macOS | ✅ Production Ready | macOS 10.14+, Xcode 14+ |
| Windows | ✅ Ready | Windows 10+, Visual Studio 2022 |
| Linux | ✅ Ready | Ubuntu 20.04+, GTK 3.0+ |

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  gameframework: ^0.5.0
  gameframework_unreal: ^0.5.0
```

Install:
```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:gameframework_unreal/gameframework_unreal.dart';

class MyGameScreen extends StatefulWidget {
  @override
  _MyGameScreenState createState() => _MyGameScreenState();
}

class _MyGameScreenState extends State<MyGameScreen> {
  UnrealController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameEngineWidget(
        engineType: GameEngineType.unreal,
        onControllerCreated: (controller) {
          _controller = controller as UnrealController;
          _initializeUnreal();
        },
      ),
    );
  }

  Future<void> _initializeUnreal() async {
    // Wait for engine to be ready
    await _controller!.create();

    // Apply quality settings
    await _controller!.applyQualitySettings(
      UnrealQualitySettings.high(),
    );

    // Load initial level
    await _controller!.loadLevel('MainMenu');

    // Listen for messages from Unreal
    _controller!.messages.listen((message) {
      print('Message from Unreal: ${message.method}');
    });
  }

  @override
  void dispose() {
    _controller?.quit();
    super.dispose();
  }
}
```

## Core API

### UnrealController

The main interface for controlling Unreal Engine:

```dart
// Lifecycle
await controller.create();           // Initialize engine
await controller.pause();             // Pause rendering
await controller.resume();            // Resume rendering
await controller.unload();            // Unload but keep ready
await controller.quit();              // Complete shutdown

// Communication
await controller.sendMessage('GameManager', 'onScoreChanged', '{"score": 100}');
await controller.sendJsonMessage('Player', 'takeDamage', {'amount': 25});

// Unreal-specific
await controller.executeConsoleCommand('stat fps');
await controller.loadLevel('Level_01');
await controller.applyQualitySettings(UnrealQualitySettings.epic());

// Get current settings
final settings = await controller.getQualitySettings();
```

### Quality Settings

Control Unreal Engine's quality with presets or custom settings:

```dart
// Use presets
await controller.applyQualitySettings(UnrealQualitySettings.low());      // Mobile/low-end
await controller.applyQualitySettings(UnrealQualitySettings.medium());   // Balanced
await controller.applyQualitySettings(UnrealQualitySettings.high());     // High-end devices
await controller.applyQualitySettings(UnrealQualitySettings.epic());     // Very high quality
await controller.applyQualitySettings(UnrealQualitySettings.cinematic());// Maximum quality

// Custom settings
await controller.applyQualitySettings(
  UnrealQualitySettings(
    qualityLevel: 3,              // Overall level (0-4)
    antiAliasingQuality: 4,       // Anti-aliasing (0-4)
    shadowQuality: 3,             // Shadows (0-4)
    postProcessQuality: 4,        // Post-processing (0-4)
    textureQuality: 4,            // Textures (0-4)
    effectsQuality: 3,            // Effects (0-4)
    foliageQuality: 2,            // Foliage (0-4)
    viewDistanceQuality: 3,       // View distance (0-4)
    targetFrameRate: 60,          // Target FPS
    enableVSync: false,           // VSync on/off
    resolutionScale: 1.0,         // Resolution scale (0.5-2.0)
  ),
);

// Get current settings
final currentSettings = await controller.getQualitySettings();
print('Current quality level: ${currentSettings.qualityLevel}');
```

### Console Commands

Execute Unreal Engine console commands:

```dart
// Performance monitoring
await controller.executeConsoleCommand('stat fps');
await controller.executeConsoleCommand('stat unit');
await controller.executeConsoleCommand('stat gpu');

// Quality overrides
await controller.executeConsoleCommand('r.SetRes 1920x1080');
await controller.executeConsoleCommand('r.VSync 0');
await controller.executeConsoleCommand('sg.ViewDistanceQuality 3');

// Debugging
await controller.executeConsoleCommand('showdebug');
await controller.executeConsoleCommand('freezerendering');
```

See [CONSOLE_COMMANDS.md](CONSOLE_COMMANDS.md) for a complete reference.

### Level Loading

Load levels/maps dynamically:

```dart
// Load a level
await controller.loadLevel('MainMenu');
await controller.loadLevel('Level_01');
await controller.loadLevel('/Game/Maps/Arena');

// Listen for level loads
controller.sceneLoads.listen((scene) {
  print('Level loaded: ${scene.name}');
  print('Build index: ${scene.buildIndex}');
  print('Is loaded: ${scene.isLoaded}');
});
```

See [LEVEL_LOADING.md](LEVEL_LOADING.md) for more details.

## Event Streams

Listen to engine events:

```dart
// Lifecycle events
controller.events.listen((event) {
  switch (event.type) {
    case GameEngineEventType.created:
      print('Engine created');
      break;
    case GameEngineEventType.loaded:
      print('Engine loaded');
      break;
    case GameEngineEventType.paused:
      print('Engine paused');
      break;
    case GameEngineEventType.resumed:
      print('Engine resumed');
      break;
    case GameEngineEventType.unloaded:
      print('Engine unloaded');
      break;
    case GameEngineEventType.destroyed:
      print('Engine destroyed');
      break;
    case GameEngineEventType.error:
      print('Engine error: ${event.message}');
      break;
  }
});

// Messages from Unreal
controller.messages.listen((message) {
  print('From: ${message.target}');
  print('Method: ${message.method}');
  print('Data: ${message.data}');

  // Parse JSON data
  if (message.data != null) {
    final json = jsonDecode(message.data!);
    // Handle data...
  }
});

// Scene/level loads
controller.sceneLoads.listen((scene) {
  print('Level: ${scene.name}');
  print('Index: ${scene.buildIndex}');
});
```

## Unreal Engine Integration

### Setting Up Your Unreal Project

1. **Add Flutter Plugin to Your Unreal Project:**

```
YourUnrealProject/
├── Plugins/
│   └── FlutterPlugin/
│       ├── FlutterPlugin.uplugin
│       ├── Source/
│       │   └── FlutterPlugin/
│       │       ├── Public/
│       │       │   └── FlutterBridge.h
│       │       └── Private/
│       │           ├── FlutterBridge.cpp
│       │           └── Android/
│       │               └── FlutterBridge_Android.cpp
```

2. **Add FlutterBridge Actor to Your Level:**

In your Unreal Editor:
- Drag `FlutterBridge` actor into your level
- Or create it programmatically in your GameMode

3. **Use in Blueprints:**

**Send message to Flutter:**
```blueprint
FlutterBridge → SendToFlutter
  Target: "GameManager"
  Method: "onScoreChanged"
  Data: "{\"score\": 100}"
```

**Receive messages from Flutter:**
```blueprint
FlutterBridge → OnMessageFromFlutter (Event)
  → Print String (Target)
  → Print String (Method)
  → Print String (Data)
```

**Execute console commands:**
```blueprint
FlutterBridge → ExecuteConsoleCommand
  Command: "stat fps"
```

**Load levels:**
```blueprint
FlutterBridge → LoadLevel
  LevelName: "Level_01"
```

**Lifecycle events:**
```blueprint
FlutterBridge → OnEnginePausedBP (Event)
FlutterBridge → OnEngineResumedBP (Event)
FlutterBridge → OnEngineQuitBP (Event)
```

### C++ Usage

```cpp
// Get FlutterBridge instance
AFlutterBridge* Bridge = AFlutterBridge::GetInstance(GetWorld());

// Send message to Flutter
Bridge->SendToFlutter(TEXT("GameManager"), TEXT("onScoreChanged"), TEXT("{\"score\": 100}"));

// Execute console command
Bridge->ExecuteConsoleCommand(TEXT("stat fps"));

// Load level
Bridge->LoadLevel(TEXT("Level_01"));

// Apply quality settings
Bridge->ApplyQualitySettings(
    3,  // Quality level
    4,  // Anti-aliasing
    3,  // Shadows
    4,  // Post-process
    4,  // Textures
    3,  // Effects
    2,  // Foliage
    3   // View distance
);

// Get quality settings
TMap<FString, int32> Settings = Bridge->GetQualitySettings();
int32 AAQuality = Settings[TEXT("antiAliasing")];
```

## Platform-Specific Setup

### Android

See [SETUP_GUIDE.md#Android](SETUP_GUIDE.md#android) for complete instructions.

**Requirements:**
- Unreal Engine 5.3.x or 5.4.x Android build
- Android NDK r25 or later
- Minimum API level 21

**Key Steps:**
1. Build your Unreal project for Android
2. Configure Flutter app to embed Unreal APK
3. Add required permissions to AndroidManifest.xml

### iOS

See [SETUP_GUIDE.md#iOS](SETUP_GUIDE.md#ios) for complete instructions.

**Requirements:**
- Unreal Engine 5.3.x or 5.4.x iOS framework
- Xcode 14.0 or later
- iOS 12.0+

**Key Steps:**
1. Build your Unreal project for iOS
2. Embed UnrealFramework.framework in Flutter app
3. Configure build settings in Xcode

### macOS

See [SETUP_GUIDE.md#macOS](SETUP_GUIDE.md#macos) for complete instructions.

**Requirements:**
- Unreal Engine 5.3.x or 5.4.x macOS build
- Xcode 14.0 or later
- macOS 10.14+

### Windows & Linux

See [SETUP_GUIDE.md#Windows](SETUP_GUIDE.md#windows) and [SETUP_GUIDE.md#Linux](SETUP_GUIDE.md#linux).

## Examples

### Basic Example

```dart
import 'package:flutter/material.dart';
import 'package:gameframework_unreal/gameframework_unreal.dart';

void main() {
  // Initialize Unreal Engine plugin
  UnrealEnginePlugin.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  UnrealController? _controller;
  String _statusText = 'Initializing...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Unreal Engine Game')),
      body: Stack(
        children: [
          // Unreal Engine rendering view
          GameEngineWidget(
            engineType: GameEngineType.unreal,
            onControllerCreated: _onControllerCreated,
          ),

          // UI overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                _statusText,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

          // Controls
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _showFPS,
                  child: Text('Show FPS'),
                ),
                ElevatedButton(
                  onPressed: _changeQuality,
                  child: Text('Change Quality'),
                ),
                ElevatedButton(
                  onPressed: _loadLevel,
                  child: Text('Load Level'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onControllerCreated(GameEngineController controller) {
    _controller = controller as UnrealController;
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    setState(() => _statusText = 'Loading...');

    // Create engine
    await _controller!.create();

    // Apply quality settings
    await _controller!.applyQualitySettings(UnrealQualitySettings.high());

    // Load first level
    await _controller!.loadLevel('MainMenu');

    // Listen for events
    _controller!.events.listen((event) {
      setState(() => _statusText = 'Event: ${event.type}');
    });

    // Listen for messages
    _controller!.messages.listen((message) {
      print('Message from Unreal: ${message.method}');
    });

    setState(() => _statusText = 'Ready');
  }

  Future<void> _showFPS() async {
    await _controller?.executeConsoleCommand('stat fps');
  }

  Future<void> _changeQuality() async {
    await _controller?.applyQualitySettings(UnrealQualitySettings.epic());
    setState(() => _statusText = 'Quality: Epic');
  }

  Future<void> _loadLevel() async {
    await _controller?.loadLevel('Level_01');
    setState(() => _statusText = 'Loading Level_01...');
  }

  @override
  void dispose() {
    _controller?.quit();
    super.dispose();
  }
}
```

### Advanced Example with Custom Quality

```dart
class AdvancedGameScreen extends StatefulWidget {
  @override
  _AdvancedGameScreenState createState() => _AdvancedGameScreenState();
}

class _AdvancedGameScreenState extends State<AdvancedGameScreen> {
  UnrealController? _controller;
  UnrealQualitySettings _currentSettings = UnrealQualitySettings.high();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Game view
          Expanded(
            child: GameEngineWidget(
              engineType: GameEngineType.unreal,
              onControllerCreated: (controller) {
                _controller = controller as UnrealController;
                _controller!.create();
              },
            ),
          ),

          // Quality controls
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildQualitySlider('Overall Quality', 0, 4,
                  _currentSettings.qualityLevel?.toDouble() ?? 3.0,
                  (value) => _updateQuality(qualityLevel: value.toInt()),
                ),
                _buildQualitySlider('Anti-Aliasing', 0, 4,
                  _currentSettings.antiAliasingQuality?.toDouble() ?? 3.0,
                  (value) => _updateQuality(antiAliasingQuality: value.toInt()),
                ),
                _buildQualitySlider('Shadows', 0, 4,
                  _currentSettings.shadowQuality?.toDouble() ?? 3.0,
                  (value) => _updateQuality(shadowQuality: value.toInt()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySlider(
    String label,
    double min,
    double max,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: max.toInt(),
            value: value,
            onChanged: onChanged,
          ),
        ),
        Text(value.toInt().toString()),
      ],
    );
  }

  Future<void> _updateQuality({
    int? qualityLevel,
    int? antiAliasingQuality,
    int? shadowQuality,
  }) async {
    _currentSettings = UnrealQualitySettings(
      qualityLevel: qualityLevel ?? _currentSettings.qualityLevel,
      antiAliasingQuality: antiAliasingQuality ?? _currentSettings.antiAliasingQuality,
      shadowQuality: shadowQuality ?? _currentSettings.shadowQuality,
      postProcessQuality: _currentSettings.postProcessQuality,
      textureQuality: _currentSettings.textureQuality,
      effectsQuality: _currentSettings.effectsQuality,
      foliageQuality: _currentSettings.foliageQuality,
      viewDistanceQuality: _currentSettings.viewDistanceQuality,
    );

    await _controller?.applyQualitySettings(_currentSettings);
    setState(() {});
  }
}
```

## Performance Tips

1. **Use Quality Presets:** Start with presets and adjust based on device capability
2. **Monitor FPS:** Use `stat fps` console command during development
3. **Adjust Resolution Scale:** Lower resolution scale for better performance
4. **Disable VSync on Mobile:** Can improve responsiveness
5. **Profile with Unreal Insights:** Use Unreal's profiling tools

See [QUALITY_SETTINGS_GUIDE.md](QUALITY_SETTINGS_GUIDE.md) for detailed optimization tips.

## Troubleshooting

### Common Issues

**Engine not starting:**
- Check Unreal framework/APK is properly embedded
- Verify minimum platform versions
- Check logs for errors

**Black screen:**
- Ensure Unreal view is properly attached
- Check quality settings aren't too high for device
- Verify level is loaded correctly

**Messages not received:**
- Check FlutterBridge actor is in the level
- Verify message target and method names match
- Check JSON formatting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more solutions.

## Documentation

- [Setup Guide](SETUP_GUIDE.md) - Complete setup instructions for all platforms
- [Quality Settings Guide](QUALITY_SETTINGS_GUIDE.md) - Detailed quality settings reference
- [Console Commands](CONSOLE_COMMANDS.md) - Console command reference
- [Level Loading](LEVEL_LOADING.md) - Level loading and streaming
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions

## API Reference

See [API documentation](https://pub.dev/documentation/gameframework_unreal/latest/) on pub.dev.

## Requirements

### Flutter
- Flutter 3.10.0 or later
- Dart 3.0.0 or later

### Unreal Engine
- Unreal Engine 5.3.x or 5.4.x
- Visual Studio 2022 (Windows)
- Xcode 14+ (macOS/iOS)
- Android NDK r25+ (Android)

## License

MIT License - see [LICENSE](../LICENSE) file for details.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## Support

- 📖 [Documentation](https://pub.dev/packages/gameframework_unreal)
- 🐛 [Issue Tracker](https://github.com/xraph/flutter-game-framework/issues)
- 💬 [Discussions](https://github.com/xraph/flutter-game-framework/discussions)

## Related Packages

- [gameframework](https://pub.dev/packages/gameframework) - Core framework
- [gameframework_unity](https://pub.dev/packages/gameframework_unity) - Unity Engine plugin

## Credits

Created and maintained by [xraph](https://github.com/xraph).

Built with Flutter and Unreal Engine.
