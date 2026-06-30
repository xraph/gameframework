# Changelog

All notable changes to the gameframework_unity package will be documented in this file.

## [0.0.4] - 2026-06-26

### Fixed
- **iOS:** resolve the `UnityFramework` Swift module on hosted (pub.dev) installs.
  The podspec's `FRAMEWORK_SEARCH_PATHS` used a single-`*` glob
  (`.symlinks/plugins/*/ios`) that Xcode does not expand, so consumers of the
  published package failed to build for iOS with
  `Unable to resolve module dependency: 'UnityFramework'`. It only worked when
  `game sync` planted a symlink in this pod's own directory — which never
  happens for hosted installs. Switched to Xcode's recursive `**` search syntax,
  which finds the consumer plugin's vendored `UnityFramework.framework` with no
  `game sync` symlink and no Podfile workaround.

## [0.0.3] - 2026-02-06

### Changed
- Updated platform support status in README
- Clarified production ready platforms (Android, iOS)
- Marked desktop and web platforms as Work in Progress
- Improved documentation clarity

## [0.0.2] - 2026-02-06

### Changed
- Updated README with improved documentation and examples
- Minor documentation improvements

## [0.0.1] - 2026-02-06

### Initial Release
- Unity Engine integration for Flutter with multi-platform support
- Complete desktop platform support (macOS, Windows, Linux)
- Unity WebGL support for Flutter Web applications
- Android and iOS Unity integration
- AR Foundation integration tools
- Performance monitoring capabilities
- Full bidirectional communication between Flutter and Unity
- Scene management and lifecycle handling
- Comprehensive documentation and guides

## [0.4.0] - 2024-10-27

### Added
- **Desktop Platform Support** - Full Unity integration for macOS, Windows, and Linux
- Unity WebGL support for Flutter Web applications
- UnityControllerWeb with JavaScript interop
- AR Foundation integration tools
- Performance monitoring capabilities
- Comprehensive WEBGL_GUIDE.md documentation
- Complete DESKTOP_GUIDE.md for all desktop platforms
- Full bidirectional communication between Flutter and Unity
- Scene management and lifecycle handling

### Platform Support
- ✅ Android (API 21+)
- ✅ iOS (12.0+)
- ✅ Web (WebGL 2.0 + WebAssembly)
- ✅ macOS (10.14+)
- ✅ Windows (10+)
- ✅ Linux (Ubuntu 20.04+)

### Features
- Android and iOS Unity integration
- Web platform support via WebGL
- **macOS Unity integration with Metal support**
- **Windows Unity integration with DirectX support**
- **Linux Unity integration with OpenGL/Vulkan support**
- AR Foundation support (ARCore/ARKit)
- Real-time performance metrics
- Event-driven architecture
- Type-safe message passing
- JSON message support

### Desktop Implementation
- macOS UnityEngineController with Cocoa integration
- Windows UnityEnginePlugin with C++ implementation
- Linux UnityEnginePlugin with GTK integration
- Platform-specific build configurations
- Native framework loading for each platform

### Documentation
- Complete API documentation
- WebGL integration guide (800+ lines)
- Desktop platform guide (600+ lines)
- Unity bridge setup guide
- Platform-specific troubleshooting
- Example projects and code samples for all platforms

## [0.3.0] - 2024-10

### Added
- Initial Unity plugin implementation
- Android and iOS native bridges
- Basic message passing
- Scene load notifications
- Lifecycle management (pause/resume)

## [0.2.0] - 2024-10

### Added
- Core plugin structure
- Platform channels setup
- Basic Unity controller interface

## [0.1.0] - 2024-10

### Added
- Project initialization
- Basic package structure
