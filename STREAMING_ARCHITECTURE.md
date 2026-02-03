# Streaming Architecture

This document describes the architecture of the asset streaming system in Flutter Game Framework.

## Overview

The streaming system enables Flutter apps to ship with minimal base content while downloading additional game assets at runtime. This significantly reduces initial app download size and enables content updates without app store releases.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Build Time                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Unity Project         Game CLI              GameFramework Cloud    │
│   ┌──────────┐         ┌──────────┐          ┌──────────────────┐  │
│   │Addressable│   →    │  Build   │    →     │   Artifact       │  │
│   │ Groups    │        │  Command │          │   Storage        │  │
│   └──────────┘         └──────────┘          └──────────────────┘  │
│        │                    │                        │              │
│        ▼                    ▼                        ▼              │
│   ┌──────────┐         ┌──────────┐          ┌──────────────────┐  │
│   │  Base +  │   →     │ Chunker  │    →     │  Manifest.json   │  │
│   │ Streaming│         │          │          │  + Chunks        │  │
│   └──────────┘         └──────────┘          └──────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          Runtime                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Flutter App                                  GameFramework Cloud   │
│   ┌─────────────────────────────┐            ┌──────────────────┐  │
│   │     GameStreamController    │  ← API →   │   Cloud API      │  │
│   ├─────────────────────────────┤            └──────────────────┘  │
│   │  ┌───────────────────────┐  │                    │             │
│   │  │   ContentDownloader   │  │  ← Download →      │             │
│   │  └───────────────────────┘  │                    │             │
│   │  ┌───────────────────────┐  │                    ▼             │
│   │  │     CacheManager      │  │            ┌──────────────────┐  │
│   │  └───────────────────────┘  │            │  Bundle Storage  │  │
│   └─────────────────────────────┘            └──────────────────┘  │
│              │                                                       │
│              ▼                                                       │
│   ┌─────────────────────────────┐                                   │
│   │      Unity Controller       │                                   │
│   │   (FlutterAddressables)     │                                   │
│   └─────────────────────────────┘                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Unity Editor Components

#### FlutterAddressablesSetup.cs
Automated setup for Unity Addressables:
- Installs Addressables package
- Creates default groups (Base, UI, Level1, etc.)
- Configures remote build/load paths
- Creates StreamingConfig asset

#### FlutterAddressablesBuildScript.cs
Builds Addressables during Unity export:
- Triggers Addressables build before player build
- Generates `streaming_manifest.json`
- Separates base and streaming bundles
- Calculates bundle sizes and hashes

#### FlutterStreamingConfig.cs
ScriptableObject for per-project configuration:
- Cloud URL and package name
- Base vs streaming group lists
- Chunk size and compression settings
- Runtime settings (concurrent downloads, timeouts)

#### FlutterStreamingAnalyzer.cs
Editor window for visualizing streaming setup:
- Shows base vs streaming content breakdown
- Estimates app size reduction
- Provides recommendations
- Quick actions for configuration

#### FlutterAddressablesManager.cs
Unity runtime component:
- Receives cache path from Flutter
- Transforms Addressable URLs to local paths
- Loads assets and scenes on demand
- Reports progress to Flutter

### 2. CLI Components

#### streaming_validator.dart
Validates streaming configuration:
- Checks .game.yml streaming settings
- Verifies Unity project setup
- Validates Addressables installation
- Reports issues and suggestions

#### asset_bundle_chunker.dart
Chunks Addressables output for upload:
- Separates base and streaming bundles
- Creates upload chunks by size
- Generates chunk manifest
- Computes SHA256 hashes

#### streaming_command.dart
CLI commands for streaming management:
- `streaming status` - Show configuration
- `streaming analyze` - Analyze project
- `streaming estimate` - Estimate sizes
- `streaming validate` - Validate setup

### 3. Flutter Package (gameframework_stream)

#### GameStreamController
Main API for developers:
- Initializes streaming system
- Fetches manifest from cloud
- Manages downloads and cache
- Communicates with Unity

#### ContentDownloader
Handles bundle downloads:
- Progress tracking
- SHA256 verification
- Retry logic with backoff
- Concurrent download support

#### CacheManager
Manages local cache:
- Stores downloaded bundles
- Tracks cache manifest
- Verifies cached content
- Cleanup and size management

#### Models
- `ContentManifest` - Describes available content
- `ContentBundle` - Individual bundle info
- `DownloadProgress` - Download status
- `DownloadStrategy` - Network preferences

### 4. Platform Integration

#### Android (UnityEngineController.kt)
- Sets streaming cache path
- Configures Unity system properties
- Notifies Unity via message

#### iOS (UnityEngineController.swift)
- Creates cache directory
- Sets UserDefaults for Unity
- Sends path to Unity runtime

## Data Flow

### Build Time

1. **Configure** - Developer configures `.game.yml` with streaming settings
2. **Export** - `game build` triggers Unity export with `-enableStreaming`
3. **Build Addressables** - Unity builds addressables, generates manifest
4. **Chunk** - CLI chunks streaming content by configured size
5. **Publish** - `game publish` uploads chunks and manifest to cloud

### Runtime

1. **Initialize** - App creates `GameStreamController`
2. **Fetch Manifest** - Controller fetches manifest from cloud
3. **Configure Unity** - Controller sets cache path in Unity
4. **Download** - App requests bundles, controller downloads
5. **Cache** - Downloaded bundles stored locally
6. **Load** - Controller tells Unity to load cached bundles

## Manifest Format

```json
{
  "version": "1.0.0",
  "buildTarget": "Android",
  "buildTime": "2024-01-15T10:30:00Z",
  "totalSize": 157286400,
  "baseSize": 31457280,
  "streamableSize": 125829120,
  "bundleCount": 15,
  "bundles": [
    {
      "name": "base_assets.bundle",
      "path": "base/base_assets.bundle",
      "sizeBytes": 31457280,
      "sha256": "abc123...",
      "isBase": true,
      "dependencies": []
    },
    {
      "name": "level1_assets.bundle",
      "path": "streaming/level1_assets.bundle",
      "sizeBytes": 41943040,
      "sha256": "def456...",
      "isBase": false,
      "dependencies": ["base_assets.bundle"]
    }
  ]
}
```

## Configuration Schema

### .game.yml

```yaml
engines:
  unity:
    project_path: ../UnityProject
    streaming:
      enabled: true                    # Enable streaming
      base_content:                    # Patterns for bundled content
        - "Scenes/Bootstrap"
        - "UI/*"
      streamable_content:              # Patterns for streaming content
        - "Scenes/Level*"
        - "Models/*"
      chunk_size_mb: 10                # Upload chunk size
      custom_catalog_url: null         # Optional custom URL
```

### StreamingConfig.asset (Unity)

```csharp
cloudUrl = "https://cloud.gameframework.io"
packageName = "my-game"
enableStreaming = true
baseGroups = ["Base", "UI"]
streamingGroups = ["Level1", "Level2", "Characters"]
chunkSizeMB = 10
maxConcurrentDownloads = 3
downloadTimeoutSeconds = 60
```

## Security Considerations

1. **SHA256 Verification** - All downloads verified against manifest hash
2. **HTTPS Only** - All cloud communication over TLS
3. **Cache Isolation** - Bundles cached in app-private directory
4. **No Execution** - Downloaded content is data only (asset bundles)

## Performance Optimizations

1. **Chunked Uploads** - Large bundles split for reliable uploads
2. **Parallel Downloads** - Configurable concurrent download count
3. **LZ4 Compression** - Fast decompression on mobile devices
4. **Incremental Updates** - Only download changed bundles
5. **Background Downloads** - Continue downloading in background

## Error Handling

| Error | Handling |
|-------|----------|
| Network unavailable | Queue for retry, notify user |
| Download timeout | Retry with exponential backoff |
| SHA256 mismatch | Delete and re-download |
| Manifest fetch failed | Use cached manifest if available |
| Unity load failed | Report to Flutter, allow retry |

## Testing

### Unit Tests
- CacheManager operations
- ContentDownloader retry logic
- Manifest parsing
- Chunker algorithm

### Integration Tests
- Full download flow
- Unity loading flow
- Cache persistence
- Error recovery

### Manual Testing
- All platforms (iOS, Android, Desktop)
- Network conditions (WiFi, cellular, offline)
- Large downloads
- Interrupted downloads

## Migration Guide

### From Non-Streaming to Streaming

1. Install Addressables in Unity
2. Run Setup Addressables
3. Assign assets to groups
4. Add streaming config to .game.yml
5. Build and publish
6. Update Flutter code to use GameStreamController

### Version Considerations

- Minimum Unity: 2021.3 LTS
- Breaking changes: Yes (new .game.yml schema)
- Data migration: Not required (new infrastructure)

## Future Enhancements

- [ ] Delta updates (only changed content)
- [ ] P2P content distribution
- [ ] Predictive preloading
- [ ] Analytics integration
- [ ] A/B testing support
- [ ] Regional CDN optimization
