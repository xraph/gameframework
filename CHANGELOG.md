# Changelog

All notable changes to the GameFramework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01 (Current)

### Added - Asset Streaming Architecture

- **New Package: `gameframework_stream`**
  - On-demand asset downloading from GameFramework Cloud
  - `GameStreamController` for managing streaming lifecycle
  - `ContentDownloader` with progress tracking and retry logic
  - `CacheManager` for local storage with SHA256 verification
  - Network-aware download strategies (WiFi-only, cellular allowed)
  - Background download support

- **Unity Addressables Integration**
  - `FlutterAddressablesSetup.cs` - One-click Addressables configuration
  - `FlutterAddressablesBuildScript.cs` - Automated build integration
  - `FlutterStreamingConfig.cs` - Project-level streaming configuration
  - `FlutterAddressablesManager.cs` - Runtime asset loading
  - `FlutterStreamingAnalyzer.cs` - Editor window for analysis

- **CLI Streaming Support**
  - `streaming status` - Show current configuration
  - `streaming analyze` - Analyze project readiness
  - `streaming estimate` - Estimate bundle sizes
  - `streaming validate` - Validate setup
  - Asset bundle chunking for upload
  - Chunked cloud API uploads

- **Platform Integration**
  - Android `setStreamingCachePath()` implementation
  - iOS `setStreamingCachePath()` implementation
  - Unity runtime cache path configuration

- **Developer Experience**
  - Streaming Analyzer window in Unity Editor
  - Validation warnings before build/publish
  - Size estimates and recommendations
  - Comprehensive documentation

### Breaking Changes

- Minimum Unity version: 2021.3 LTS (for Addressables support)
- New `.game.yml` schema for streaming configuration
- `GameEngineController` now includes `setStreamingCachePath()` method

### Migration Guide

For existing projects:
1. Install Unity Addressables package
2. Run "Game Framework > Streaming > Setup Addressables" in Unity
3. Add streaming config to `.game.yml`
4. Rebuild and republish

See [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md) for details.

## [0.4.0] - 2024-01

### Added - Phase 4: Unity Production Features

- Unity C# bridge scripts (FlutterBridge, FlutterSceneManager, FlutterGameManager, FlutterUtilities)
- Unity Editor tools (FlutterExporter, FlutterProjectValidator)
- iOS native bridge (FlutterBridge.mm)
- AR Foundation integration guide (600+ lines)
- Quick Start guide and comprehensive documentation
- PlatformInfo utility for platform detection
- Enhanced example application with full UI

### Testing

- Comprehensive test suite with 39 passing tests
- Full coverage of core models and exceptions
- GameEngineType, GameEngineConfig, GameEngineMessage tests
- GameSceneLoaded, GameEngineEvent tests
- All exception types validated
- GameEngineRegistry and PlatformInfo tests
- Integration tests for framework validation

### Fixed

- UnityController API alignment with GameEngineController interface
- Added missing isInBackground() method implementation
- Fixed EngineCommunicationException usage with proper parameters
- GameEngineEvent construction (removed non-existent factory methods)
- Example app message handling to use actual API
- Integration tests updated to test actual framework APIs

## [0.3.0] - 2024-01

### Added - Phase 3: Unity Plugin

- Complete Unity plugin (Dart, Android, iOS)
- UnityController implementing GameEngineController
- UnityPlayer and UnityFramework integration
- Bidirectional communication system
- Scene management and lifecycle support

## [0.2.0] - 2024-01

### Added - Phase 2: Native Bridge Architecture

- Android native bridge (Kotlin)
- iOS native bridge (Swift)
- GameEngineController base classes
- GameEngineRegistry and Factory patterns
- Method channel infrastructure

## [0.1.0] - 2024-01

### Added - Phase 1: Core Framework

- Core Dart framework with unified API
- GameWidget, GameEngineController, GameEngineRegistry
- Models (GameEngineType, Config, Message, Event)
- Exception handling
- Architecture documentation (10 design docs)

---

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for detailed project status.
