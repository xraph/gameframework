# Flutter Game Framework - Actual Project Structure

This document describes the **actual implemented** structure of the Flutter Game Framework project as of version 0.4.0.

---

## Root Structure

```
flutter-game-framework/
├── lib/                          # Core Dart framework
├── android/                      # Android native bridge
├── ios/                          # iOS native bridge
├── engines/                      # Engine-specific plugins
│   ├── unity/                    # Unity plugin
│   └── unreal/                   # Unreal plugin (planned)
├── example/                      # Example application
├── docs-files/                   # Design documentation
├── test/                         # Tests
├── pubspec.yaml                  # Package configuration
├── README.md                     # Project README
├── QUICK_START.md                # Quick start guide
├── IMPLEMENTATION_STATUS.md      # Current status
├── SESSION_SUMMARY.md            # Development summary
├── CHANGELOG.md                  # Version history
└── LICENSE                       # License file
```

---

## Core Framework (`lib/`)

### Dart Implementation

```
lib/
├── gameframework.dart                    # Main export file
├── gameframework_platform_interface.dart # Platform interface (legacy)
├── gameframework_method_channel.dart     # Method channel (legacy)
└── src/
    ├── core/                             # Core classes
    │   ├── game_widget.dart              # Main widget for embedding engines
    │   ├── game_engine_controller.dart   # Abstract controller interface
    │   ├── game_engine_registry.dart     # Singleton registry
    │   └── game_engine_factory.dart      # Factory interface
    ├── models/                           # Data models
    │   ├── game_engine_type.dart         # Engine enum (Unity, Unreal)
    │   ├── game_engine_config.dart       # Configuration model
    │   ├── game_engine_message.dart      # Message model
    │   ├── game_scene_loaded.dart        # Scene load event
    │   └── game_engine_event.dart        # Lifecycle events
    ├── exceptions/                       # Exception classes
    │   └── game_engine_exception.dart    # All exception types
    └── utils/                            # Utilities
        └── platform_info.dart            # Platform detection utilities
```

### Exports

`gameframework.dart` exports:
- Core classes (GameWidget, GameEngineController, GameEngineRegistry, GameEngineFactory)
- Models (GameEngineType, GameEngineConfig, GameEngineMessage, GameSceneLoaded, GameEngineEvent)
- Exceptions (GameEngineException and subtypes)
- Utils (PlatformInfo)
- Version constant (`gameFrameworkVersion`)

---

## Android Native Bridge (`android/`)

### Kotlin Implementation

```
android/
├── build.gradle                          # Build configuration
└── src/
    └── main/
        ├── AndroidManifest.xml           # Manifest file
        └── kotlin/com/xraph/gameframework/gameframework/
            ├── GameframeworkPlugin.kt    # Main plugin
            └── core/                     # Core native classes
                ├── GameEngineController.kt   # Abstract controller
                ├── GameEngineFactory.kt      # Abstract factory
                └── GameEngineRegistry.kt     # Singleton registry
```

### Key Features

- **GameEngineController.kt** (Abstract)
  - Implements PlatformView, DefaultLifecycleObserver, MethodCallHandler
  - Manages method channels
  - Handles lifecycle (onCreate, onPause, onResume, onDestroy)
  - Thread-safe operations

- **GameEngineRegistry.kt** (Singleton)
  - Thread-safe double-check locking
  - Manages factories and controllers
  - Provides activity/lifecycle access

- **GameframeworkPlugin.kt**
  - Registers platform view factories
  - Exposes getRegisteredEngines(), isEngineRegistered()

---

## iOS Native Bridge (`ios/`)

### Swift Implementation

```
ios/
├── gameframework.podspec                 # CocoaPods spec
└── Classes/
    ├── GameframeworkPlugin.swift         # Main plugin
    └── Core/                             # Core native classes
        ├── GameEngineController.swift    # Protocol & base class
        └── GameEngineRegistry.swift      # Registry & factory wrapper
```

### Key Features

- **GameEngineController.swift**
  - `GameEnginePlatformView` protocol
  - Base class with common implementation
  - Method channel and event channel management
  - Utility methods (sendEvent, addEngineView, getConfigValue)

- **GameEngineRegistry.swift**
  - `GameEngineFactory` protocol
  - Singleton registry
  - `GameEnginePlatformViewFactory` wrapper for Flutter

---

## Unity Plugin (`engines/unity/`)

### Structure

```
engines/unity/
├── dart/                                 # Dart plugin
│   ├── lib/
│   │   ├── gameframework_unity.dart      # Main export
│   │   └── src/
│   │       ├── unity_controller.dart     # Unity controller
│   │       └── unity_engine_plugin.dart  # Plugin registration
│   ├── pubspec.yaml                      # Package config
│   └── README.md                         # Usage guide (500+ lines)
├── android/                              # Android implementation
│   ├── src/main/kotlin/com/xraph/gameframework/unity/
│   │   ├── UnityEngineController.kt      # Unity controller
│   │   └── UnityEnginePlugin.kt          # Plugin registration
│   ├── build.gradle                      # Build config
│   └── src/main/AndroidManifest.xml      # Manifest
├── ios/                                  # iOS implementation
│   ├── Classes/
│   │   ├── UnityEngineController.swift   # Unity controller
│   │   └── UnityEnginePlugin.swift       # Plugin registration
│   └── gameframework_unity.podspec       # Podspec
├── plugin/                               # Unity C# scripts
│   ├── Scripts/
│   │   ├── FlutterBridge.cs              # Core bridge (280 lines)
│   │   ├── FlutterSceneManager.cs        # Scene management (100 lines)
│   │   ├── FlutterGameManager.cs         # Example manager (240 lines)
│   │   └── FlutterUtilities.cs           # Utilities (380 lines)
│   ├── Editor/
│   │   ├── FlutterExporter.cs            # Export automation (420 lines)
│   │   └── FlutterProjectValidator.cs    # Validator (450 lines)
│   ├── Plugins/
│   │   └── iOS/
│   │       └── FlutterBridge.mm          # iOS native bridge (50 lines)
│   ├── README.md                         # Unity usage guide (900+ lines)
│   └── AR_FOUNDATION.md                  # AR guide (600+ lines)
└── README.md                             # Overview
```

### Key Components

#### Dart Plugin
- `UnityController` - Implements GameEngineController
- `UnityEnginePlugin` - Registration and factory
- Version: 2022.3.0 (aligned with Unity)

#### Android Native
- Extends core GameEngineController
- Manages UnityPlayer lifecycle
- Platform-specific JNI communication

#### iOS Native
- Extends core GameEngineController
- Manages UnityFramework lifecycle
- Dynamic framework loading

#### Unity C# Scripts
- **FlutterBridge** - Core communication with event system
- **FlutterSceneManager** - Automatic scene management
- **FlutterGameManager** - Example game lifecycle
- **FlutterUtilities** - Data conversion, performance, touch handling

#### Unity Editor Tools
- **FlutterExporter** - One-click export with GUI
- **FlutterProjectValidator** - 20+ automated checks with fixes

---

## Example Application (`example/`)

```
example/
├── lib/
│   └── main.dart                         # Enhanced example (460 lines)
│       ├── HomePage                      # Engine selection
│       └── UnityExampleScreen            # Full Unity demo
├── android/                              # Android config
├── ios/                                  # iOS config
└── pubspec.yaml                          # Dependencies
```

### Features

- Home screen with engine selection
- Full-featured Unity integration demo
- Status bar with readiness indicator
- Control panel (Start, Pause, Stop, Send Message, Reset)
- Real-time event logging (terminal-style)
- Score tracking
- Info dialog with setup instructions

---

## Documentation (`docs-files/`)

```
docs-files/
├── 00-README.md                          # Documentation index
├── 01-analysis-summary.md                # flutter-unity-view-widget analysis
├── 02-architecture-design.md             # Architecture (20KB)
├── 03-api-design.md                      # API specifications (24KB)
├── 04-native-bridge-architecture.md      # Native bridge (29KB)
├── 05-engine-plugin-packages.md          # Engine plugins (25KB)
├── 06-project-structure.md               # Project structure (17KB)
├── 07-versioning-compatibility.md        # Versioning strategy (12KB)
├── 08-implementation-roadmap.md          # 32-week roadmap (16KB)
└── 09-actual-project-structure.md        # Actual structure
```

**Total**: 150+ pages of design documentation

---

## Root Documentation Files

```
README.md                                 # Project overview (330 lines)
QUICK_START.md                            # Quick start guide (400+ lines)
IMPLEMENTATION_STATUS.md                  # Current status (500+ lines)
SESSION_SUMMARY.md                        # Development summary (800+ lines)
CHANGELOG.md                              # Version history (53 lines)
LICENSE                                   # MIT License
```

---

## Configuration Files

### Core Framework (`pubspec.yaml`)

```yaml
name: gameframework
description: Unified framework for embedding game engines in Flutter
version: 0.4.0
environment:
  sdk: '>=3.1.3 <4.0.0'
  flutter: ">=3.10.0"
dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.0.2
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
flutter:
  plugin:
    platforms:
      android:
        package: com.xraph.gameframework.gameframework
        pluginClass: GameframeworkPlugin
      ios:
        pluginClass: GameframeworkPlugin
```

### Unity Plugin (`engines/unity/dart/pubspec.yaml`)

```yaml
name: gameframework_unity
description: Unity Engine plugin for Flutter Game Framework
version: 2022.3.0
dependencies:
  flutter:
    sdk: flutter
  gameframework:
    path: ../../../
flutter:
  plugin:
    platforms:
      android:
        package: com.xraph.gameframework.unity
        pluginClass: UnityEnginePlugin
      ios:
        pluginClass: UnityEnginePlugin
```

---

## File Statistics

### Code Files

| Category | Files | Lines |
|----------|-------|-------|
| **Dart Core** | 11 | ~1,200 |
| **Android Core** | 4 | ~800 |
| **iOS Core** | 3 | ~600 |
| **Unity Dart** | 2 | ~400 |
| **Unity Android** | 2 | ~350 |
| **Unity iOS** | 2 | ~260 |
| **Unity C#** | 4 | ~1,000 |
| **Unity Editor** | 2 | ~870 |
| **Unity iOS Bridge** | 1 | ~50 |
| **Example** | 1 | ~460 |
| **Utils** | 1 | ~100 |
| **Total** | **33** | **~6,090** |

### Documentation Files

| File | Lines |
|------|-------|
| README.md | 330 |
| QUICK_START.md | 400+ |
| IMPLEMENTATION_STATUS.md | 500+ |
| SESSION_SUMMARY.md | 800+ |
| CHANGELOG.md | 53 |
| Unity Dart README | 500+ |
| Unity Plugin README | 900+ |
| AR Foundation Guide | 600+ |
| Design Docs (10 files) | 5,000+ |
| **Total Documentation** | **~9,000+** |

---

## Platform Support Matrix

| Platform | Core | Unity | Unreal | Status |
|----------|------|-------|--------|--------|
| **Android** | ✅ | ✅ | 📋 | Complete |
| **iOS** | ✅ | ✅ | 📋 | Complete |
| **Web** | 🚧 | 🚧 | 📋 | Planned |
| **macOS** | 🚧 | 🚧 | 📋 | Planned |
| **Windows** | 🚧 | 🚧 | 📋 | Planned |
| **Linux** | 🚧 | 🚧 | 📋 | Planned |

---

## Key Features Implemented

### Core Framework
- ✅ Unified GameWidget API
- ✅ Abstract GameEngineController interface
- ✅ Singleton GameEngineRegistry
- ✅ Factory pattern for controllers
- ✅ Type-safe models and exceptions
- ✅ Platform detection utilities

### Native Bridge
- ✅ Android native (Kotlin)
- ✅ iOS native (Swift)
- ✅ Method channel communication
- ✅ Lifecycle management
- ✅ Thread-safe operations

### Unity Integration
- ✅ Complete Dart plugin
- ✅ Android native controller
- ✅ iOS native controller
- ✅ Unity C# bridge scripts
- ✅ Export automation tool
- ✅ Project validator tool
- ✅ AR Foundation support
- ✅ Performance monitoring
- ✅ Touch input handling

---

## Next Steps

### Phase 4 Completion
- 🚧 WebGL/Web platform support
- 🚧 Unity package (.unitypackage) creation
- 🚧 Comprehensive unit tests
- 🚧 AR Foundation example projects

### Phase 5-6: Unreal Plugin
- 📋 Unreal Dart plugin
- 📋 Unreal Android native
- 📋 Unreal iOS native
- 📋 Unreal C++ bridge
- 📋 Export automation

### Phase 7-8: Polish & Release
- 📋 Performance optimizations
- 📋 CI/CD pipeline
- 📋 Pub.dev release
- 📋 Video tutorials

---

## Summary

The current project structure provides:

1. **✅ Complete Core Framework** - All foundational classes
2. **✅ Complete Native Bridge** - Android & iOS ready
3. **✅ Complete Unity Plugin** - Full implementation
4. **✅ Production Tooling** - Export & validation
5. **✅ Comprehensive Documentation** - 9,000+ lines
6. **✅ Working Examples** - Full-featured demo

**Overall Progress**: ~55% Complete (4 of 8 phases)
**Current Version**: 0.4.0
**Status**: Production-ready for Unity integration

---

For the original planned structure, see [06-project-structure.md](docs-files/06-project-structure.md).

For current implementation status, see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).
