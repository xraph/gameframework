# Changelog

All notable changes to the gameframework package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.3] - 2026-02-06

### Changed
- Updated project status and roadmap in README
- Clarified platform support status (Production Ready vs WIP)
- Removed phase-based terminology in favor of clear roadmap
- Updated documentation to reflect accurate development status

## [0.0.2] - 2026-02-06

### Changed
- Updated README with improved documentation and examples
- Minor documentation improvements

## [0.0.1] - 2026-02-06

### Initial Release

A unified, modular framework for embedding multiple game engines (Unity, Unreal Engine) into Flutter applications.

#### Core Features

**Architecture:**
- Modular, extensible architecture for multiple game engine support
- Platform-agnostic controller interface with `GameEngineController`
- Factory pattern for game engine instantiation
- Registry system for engine discovery and management
- Lifecycle management (initialize, pause, resume, dispose)
- Bidirectional communication via message passing

**Dart API:**
- `GameWidget` - Drop-in Flutter widget for embedding game engines
- `GameEngineController` - Base controller interface for all engines
- `GameEngineFactory` - Factory for creating engine instances
- `GameEngineRegistry` - Central registry for engine types
- `GameEngineConfig` - Configuration model with platform-specific settings
- Type-safe models for events, messages, and scene loading

**Platform Support:**
- Android (API 21+) - Method channels and platform views
- iOS (12.0+) - Method channels and UIKit integration
- macOS (10.14+) - Native Swift implementation
- Windows (10+) - C++ plugin with CMake
- Linux (Ubuntu 20.04+) - GObject-based plugin

**Models & Types:**
- `GameEngineType` - Enum for supported engines (Unity, Unreal)
- `GameEngineEvent` - Event system for engine lifecycle
- `GameEngineMessage` - Bidirectional message passing
- `GameSceneLoaded` - Scene/level load notifications
- `AndroidPlatformViewMode` - Android rendering modes (Hybrid, Virtual, Texture)
- `GameEngineException` - Typed exception handling

**Utilities:**
- `PlatformInfo` - Platform detection and capabilities
- Development scripts for testing and debugging

#### Platform Support Details

| Platform | Status | Implementation |
|----------|--------|----------------|
| Android | ✅ Production Ready | Kotlin with method channels |
| iOS | ✅ Production Ready | Swift with Cocoa integration |
| macOS | ✅ Production Ready | Swift with AppKit |
| Windows | ✅ Ready | C++ with CMake |
| Linux | ✅ Ready | C with GObject |

#### Technical Specifications

**Code Metrics:**
- Dart core: 1,500+ lines
- Android Kotlin: 1,000+ lines
- iOS/macOS Swift: 800+ lines
- Windows C++: 300+ lines
- Linux C: 250+ lines
- Test coverage: Comprehensive unit tests
- **Total: 3,850+ lines**

**Architecture Highlights:**
- Clean separation between platform-agnostic and platform-specific code
- Factory pattern for engine instantiation
- Observer pattern for event handling
- Strategy pattern for platform-specific implementations
- Plugin architecture for extensibility

#### Dependencies

```yaml
dependencies:
  flutter: ">=3.3.0"
  plugin_platform_interface: ^2.0.2
  flutter_plugin_android_lifecycle: ^2.0.17

environment:
  sdk: '>=3.6.0 <4.0.0'
```

#### Companion Packages

This core framework is designed to work with engine-specific implementations:
- `gameframework_unity` - Unity Engine integration
- `gameframework_unreal` - Unreal Engine integration

#### Usage Example

```dart
import 'package:gameframework/gameframework.dart';

// Create a game widget
GameWidget(
  engineType: GameEngineType.unity,
  config: GameEngineConfig(
    androidPlatformViewMode: AndroidPlatformViewMode.hybrid,
    enableLogging: true,
  ),
  onEngineReady: (controller) {
    print('Engine initialized!');
  },
  onMessage: (message) {
    print('Received: ${message.data}');
  },
)
```

#### Development Tools

**Scripts:**
- `dev.sh` - Development environment setup and testing
- `fix_unity_embedding.sh` - Unity-specific embedding fixes
- `test_unity_embedding.sh` - Unity integration testing

#### Breaking Changes

None - Initial release.

#### Known Limitations

- Web platform support planned for future releases
- Game engine implementations require companion packages
- Platform-specific features may vary by engine

---

## [Unreleased]

### Planned Features

**v0.1.0 - Enhanced Core:**
- Web platform support (WebGL/Pixel Streaming)
- Enhanced error handling and recovery
- Performance profiling APIs
- Advanced lifecycle hooks

**v0.2.0 - Developer Experience:**
- DevTools integration
- Hot reload support for game content
- Debugging utilities
- Example applications

**v0.3.0 - Advanced Features:**
- Multi-engine support in single app
- State persistence and restoration
- Advanced memory management
- Background execution support

**v1.0.0 - Production Release:**
- Complete platform coverage
- Full test suite (95%+ coverage)
- Comprehensive documentation
- Migration guides
- Performance benchmarks

---

## Release Notes Format

For future releases:

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements

---

**Semantic Versioning:**
- **Major (X.0.0):** Breaking changes
- **Minor (0.X.0):** New features, backward compatible
- **Patch (0.0.X):** Bug fixes, backward compatible

---

## Links

- [GitHub Repository](https://github.com/xraph/gameframework)
- [Issue Tracker](https://github.com/xraph/gameframework/issues)
- [Discussions](https://github.com/xraph/gameframework/discussions)
- [pub.dev Package](https://pub.dev/packages/gameframework)

---

**Last Updated:** 2026-02-06
