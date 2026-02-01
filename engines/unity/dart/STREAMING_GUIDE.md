# Unity Streaming Setup Guide

This guide explains how to configure your Unity project for asset streaming with the Flutter Game Framework.

## Overview

Asset streaming allows you to:
- Reduce your app's initial download size
- Download additional game content at runtime
- Update content without releasing a new app version

## Prerequisites

- Unity 2021.3 LTS or newer (recommended)
- Flutter Game Framework CLI (`game` command)
- GameFramework Cloud account

## Step 1: Install Addressables

1. Open your Unity project
2. Go to **Game Framework > Streaming > Setup Addressables**
3. Wait for the Addressables package to install
4. Run the setup again if prompted

This will:
- Install the Unity Addressables package
- Create default addressable groups
- Configure build/load paths for streaming
- Create a StreamingConfig asset

## Step 2: Configure Addressable Groups

### Understanding Groups

- **Base Groups**: Content bundled with your app (fast loading, always available)
- **Streaming Groups**: Content downloaded at runtime (reduces app size)

### Recommended Structure

| Group | Type | Content |
|-------|------|---------|
| Base | Local | Bootstrap scene, essential UI |
| UI | Local | Common UI assets, fonts |
| Level1 | Remote | First level (download on first play) |
| Level2+ | Remote | Additional levels |
| Characters | Remote | Character models, animations |
| Environment | Remote | Environment assets, textures |

### Assigning Assets to Groups

1. Go to **Window > Asset Management > Addressables > Groups**
2. Select assets in the Project window
3. Right-click and choose **Addressable > Make Addressable**
4. Drag assets to the appropriate group

Or use the quick action:
- **Assets > Game Framework > Mark as Base Content**
- **Assets > Game Framework > Mark as Streaming Content**

## Step 3: Configure CLI

Add streaming configuration to your `.game.yml`:

```yaml
engines:
  unity:
    project_path: ../UnityProject
    streaming:
      enabled: true
      base_content:
        - "Scenes/Bootstrap"
        - "Scenes/MainMenu"
        - "UI/*"
      streamable_content:
        - "Scenes/Level*"
        - "Models/Characters/*"
        - "Models/Environment/*"
        - "Audio/Music/*"
      chunk_size_mb: 10
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `enabled` | Enable streaming | `false` |
| `base_content` | Patterns for bundled content | `[]` |
| `streamable_content` | Patterns for streaming content | `[]` |
| `chunk_size_mb` | Upload chunk size in MB | `10` |
| `custom_catalog_url` | Custom catalog URL | Cloud URL |

## Step 4: Analyze Your Configuration

### Unity Editor

1. Go to **Game Framework > Streaming > Analyze Streaming**
2. Review the summary:
   - Base content size
   - Streaming content size
   - Estimated app size reduction
3. Check recommendations for optimization

### CLI

```bash
# Show current configuration
game streaming status

# Analyze project readiness
game streaming analyze --engine unity

# Estimate sizes
game streaming estimate --platform android

# Validate configuration
game streaming validate --platform android
```

## Step 5: Build and Publish

### Build with Streaming

```bash
# Build for Android with streaming
game build --platform android

# Build for iOS with streaming
game build --platform ios
```

This will:
1. Build Unity Addressables
2. Separate base and streaming content
3. Generate the streaming manifest
4. Create the Flutter app with base content only

### Publish to Cloud

```bash
# Publish including streaming content
game publish
```

This will:
1. Upload base content (bundled with app)
2. Chunk and upload streaming content
3. Upload the content manifest

## Step 6: Use in Flutter

```dart
// Create stream controller
final streamController = GameStreamController(
  engineController: unityController,
  cloudUrl: 'https://cloud.gameframework.io',
  packageName: 'my-game',
  packageVersion: '1.0.0',
);

// Initialize
await streamController.initialize();

// Preload content
await streamController.preloadContent(
  bundles: ['Level1'],
  strategy: DownloadStrategy.wifiOrCellular,
);
```

## Best Practices

### Content Organization

1. **Essential Content in Base**
   - Bootstrap/loading scenes
   - Main menu UI
   - Common audio (UI sounds)
   - Fonts and basic textures

2. **Large Content in Streaming**
   - Game levels
   - Character models
   - High-resolution textures
   - Background music

### Size Optimization

1. **Compress Textures**: Use appropriate compression for each platform
2. **Audio Compression**: Use compressed formats for music
3. **Mesh Optimization**: LODs for 3D models
4. **Analyze Dependencies**: Avoid duplicate assets across groups

### User Experience

1. **Download on WiFi**: Default to WiFi-only for large downloads
2. **Show Progress**: Always show download progress
3. **Allow Cancellation**: Let users cancel downloads
4. **Background Downloads**: Support background downloading
5. **Offline Fallback**: Handle offline gracefully

## Troubleshooting

### "Addressables not installed"

Run **Game Framework > Streaming > Setup Addressables** in Unity.

### "No streaming groups found"

1. Open Addressables Groups window
2. Create groups with Remote build/load paths
3. Move content to streaming groups

### "Build failed: Addressables error"

1. Check Unity console for errors
2. Verify Addressables settings
3. Clean and rebuild: **Game Framework > Streaming > Build Addressables**

### "Download failed: 404"

1. Verify content was published: `game publish`
2. Check cloud URL in StreamingConfig
3. Verify package name and version match

### "SHA256 mismatch"

1. Content was modified after publishing
2. Republish: `game publish --force`

## Advanced Configuration

### Custom Catalog URL

```yaml
streaming:
  enabled: true
  custom_catalog_url: "https://cdn.example.com/catalog"
```

### Multiple Build Configurations

```yaml
engines:
  unity:
    project_path: ../UnityProject
    export_settings:
      build_configuration: Release
    streaming:
      enabled: true
      chunk_size_mb: 10  # Smaller for slow connections
```

### Platform-Specific Settings

```yaml
platforms:
  android:
    enabled: true
    build_settings:
      streaming_chunk_mb: 8  # Smaller for mobile
  ios:
    enabled: true
    build_settings:
      streaming_chunk_mb: 8
```

## Support

- [GitHub Issues](https://github.com/xraph/flutter-game-framework/issues)
- [Documentation](https://github.com/xraph/flutter-game-framework/tree/main/docs)
