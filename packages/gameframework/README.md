# Game Framework

A unified, modular framework for embedding multiple game engines (Unity, Unreal Engine, and potentially others) into Flutter applications.

[![pub package](https://img.shields.io/pub/v/gameframework.svg)](https://pub.dev/packages/gameframework)
[![pub points](https://img.shields.io/pub/points/gameframework?logo=dart)](https://pub.dev/packages/gameframework/score)
[![popularity](https://img.shields.io/pub/popularity/gameframework?logo=dart)](https://pub.dev/packages/gameframework/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg)](https://flutter.dev)

---

## ✨ Features

- **🎮 Unified API** - One interface for all game engines
- **🔌 Modular Architecture** - Plug in only the engines you need
- **↔️ Bidirectional Communication** - Flutter ↔ Engine messaging
- **♻️ Lifecycle Management** - Automatic pause/resume/destroy
- **📱 Multi-Platform** - Android & iOS (Web/Desktop coming soon)
- **🛡️ Type-Safe** - Full Dart type safety
- **🚀 Production-Ready** - Export automation, validation, and tooling
- **📖 Well-Documented** - 3,400+ lines of documentation

---

## 🚀 Quick Start

### 1. Add Dependencies

```yaml
dependencies:
  gameframework: ^0.0.2
  gameframework_unity: ^0.0.2
  gameframework_stream: ^0.0.2  # Optional: for asset streaming
```

Or install from the command line:

```bash
flutter pub add gameframework
flutter pub add gameframework_unity
```

### 2. Initialize Engine Plugin

```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnityEnginePlugin.initialize();
  runApp(MyApp());
}
```

### 3. Embed Engine in Your App

```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        engineType: GameEngineType.unity,
        onEngineCreated: (controller) {
          controller.sendMessage('GameManager', 'Start', 'level1');
        },
        onMessage: (message) {
          print('Message from engine: ${message.data}');
        },
      ),
    );
  }
}
```

**That's it!** See [QUICK_START.md](QUICK_START.md) for detailed instructions.

---

## 📦 Supported Engines

| Engine | Status | Platforms | Version |
|--------|--------|-----------|---------|
| **Unity** | ✅ Production (Android, iOS)<br>🚧 WIP (Web, Desktop) | Android, iOS, Web*, macOS*, Windows*, Linux* | 2022.3.x |
| **Unreal Engine** | 🚧 WIP (Android, iOS) | Android*, iOS* | 5.x |

\* = Work in Progress

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              Flutter Application                 │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  GameWidget (Unified API)                  │ │
│  └─────────────┬──────────────────────────────┘ │
│                │                                 │
│  ┌─────────────▼──────────────────────────────┐ │
│  │  GameEngineController (Interface)          │ │
│  └─────────────┬──────────────────────────────┘ │
└────────────────┼──────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────┐  ┌───────▼──────┐
│Unity Plugin  │  │Unreal Plugin │
│              │  │   (Soon)     │
└───────┬──────┘  └──────────────┘
        │
┌───────▼──────────────────────────┐
│    Native Bridge                 │
│  (Android/iOS)                   │
└───────┬──────────────────────────┘
        │
┌───────▼──────────────────────────┐
│    Game Engine                   │
│  (Unity/Unreal)                  │
└──────────────────────────────────┘
```

---

## 📚 Documentation

### Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Get up and running in 5 minutes
- **[Implementation Status](IMPLEMENTATION_STATUS.md)** - Current project status

### Unity Integration
- **[Unity Plugin Guide](engines/unity/dart/README.md)** - Flutter-side Unity usage
- **[Unity Bridge Guide](engines/unity/plugin/README.md)** - Unity-side integration
- **[AR Foundation Guide](engines/unity/plugin/AR_FOUNDATION.md)** - AR experiences

### Architecture & Design
- **[Design Documents](docs-files/)** - 10 detailed design documents
- **[API Reference](lib/gameframework.dart)** - Inline API documentation
- **[Changelog](CHANGELOG.md)** - Version history

---

## 🎯 Use Cases

### Mobile Gaming
Embed Unity/Unreal games directly in your Flutter app:
```dart
GameWidget(
  engineType: GameEngineType.unity,
  config: GameEngineConfig(fullscreen: true),
)
```

### AR Experiences
Build AR apps with AR Foundation:
```dart
GameWidget(
  engineType: GameEngineType.unity,
  onEngineCreated: (controller) {
    controller.sendMessage('ARManager', 'StartAR', '');
  },
)
```

### Interactive Content
Mix game content with Flutter UI:
```dart
Column(
  children: [
    Expanded(child: GameWidget(...)),
    ControlPanel(), // Your Flutter UI
  ],
)
```

---

## 🛠️ Unity Integration

### Export Your Unity Project

1. Add Flutter scripts to your Unity project
2. In Unity menu: **Flutter > Export for Flutter**
3. Select Android and/or iOS
4. Export to your Flutter project

### Validate Your Project

1. In Unity menu: **Flutter > Validate Project**
2. Fix any issues with one-click fixes
3. Ready to export!

**See [Unity Plugin Guide](engines/unity/plugin/README.md) for details.**

---

## 💬 Communication

### Flutter → Unity

```dart
// Simple message
await controller.sendMessage('Player', 'Jump', '10.5');

// JSON message
await controller.sendJsonMessage('GameManager', 'UpdateScore', {
  'score': 100,
  'stars': 3,
});
```

### Unity → Flutter

```csharp
// Simple message
FlutterBridge.Instance.SendToFlutter("GameManager", "onReady", "true");

// JSON message
var data = new GameData { score = 100, level = 5 };
FlutterBridge.Instance.SendToFlutter("GameManager", "onUpdate", data);
```

---

## 🎓 Example

Run the included example to see it in action:

```bash
cd example
flutter run
```

The example demonstrates:
- ✅ Engine initialization
- ✅ Lifecycle management
- ✅ Bidirectional communication
- ✅ Event logging
- ✅ UI controls

---

## 📊 Project Status & Roadmap

**Current Version:** 0.0.2

### ✅ Production Ready
- **Unity:** Android, iOS
- **Core Framework:** All platforms
- **Quality:** Type-safe API, comprehensive tests, clean static analysis

### 🚧 Work in Progress
- **Unity:** Web, macOS, Windows, Linux
- **Unreal:** Android, iOS

### 📋 Roadmap
- **Near-term:**
  - Complete Unity desktop (macOS, Windows, Linux) support
  - Complete Unity Web/WebGL support
  - Complete Unreal Engine mobile (Android, iOS) integration
  
- **Mid-term:**
  - Unreal desktop & web support
  - Advanced asset streaming features
  - Performance optimization tools
  
- **Long-term:**
  - Additional game engine integrations
  - Cloud services integration
  - v1.0 Production release

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

### Areas We Need Help
- Testing on various devices
- Additional game engine integrations
- Documentation improvements
- Example projects

---

## 📋 Requirements

### Flutter
- Flutter 3.10.0 or higher
- Dart 3.0.0 or higher

### Android
- minSdkVersion: 21 (Android 5.0)
- targetSdkVersion: 33
- Kotlin 1.8+
- Gradle 8.0+

### iOS
- iOS 12.0 or higher
- Swift 5.0+
- Xcode 14.0+

### Unity
- Unity 2022.3.x or 2023.1.x
- IL2CPP scripting backend recommended

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/xraph/gameframework/issues)
- **Discussions:** [GitHub Discussions](https://github.com/xraph/gameframework/discussions)
- **Documentation:** See [docs-files/](docs-files/)

---

## 🔗 Links

- [Quick Start Guide](QUICK_START.md)
- [Unity Plugin Guide](engines/unity/plugin/README.md)
- [AR Foundation Guide](engines/unity/plugin/AR_FOUNDATION.md)
- [API Documentation](lib/gameframework.dart)
- [Changelog](CHANGELOG.md)

---

**Made with 🎮 for Flutter game developers**

