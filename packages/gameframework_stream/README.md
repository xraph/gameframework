# GameFramework Stream

Asset streaming support for Game Framework. Enables apps to ship with minimal base size and download Unity Addressable content at runtime from GameFramework Cloud.

## Features

- **Minimal App Size**: Ship only essential content bundled with the app
- **On-Demand Downloads**: Download additional content when needed
- **Progress Tracking**: Real-time download progress streams
- **Intelligent Caching**: Automatic local caching with SHA256 verification
- **Network-Aware**: WiFi-only, cellular, or any connection strategies
- **Resume Support**: Interrupted downloads resume automatically
- **Cache Management**: Control cache size and clear when needed

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  gameframework_stream: ^1.0.0
```

## Quick Start

```dart
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_stream/gameframework_stream.dart';

// After creating your Unity controller...
final streamController = GameStreamController(
  engineController: unityController,
  cloudUrl: 'https://cloud.gameframework.io',
  packageName: 'my-game-package',
  packageVersion: '1.0.0',
);

// Initialize (fetches manifest, configures Unity)
await streamController.initialize();

// Listen to download progress
streamController.downloadProgress.listen((progress) {
  print('${progress.bundleName}: ${progress.percentageString}');
});

// Preload essential content
await streamController.preloadContent(
  bundles: ['Level1', 'CoreUI'],
  strategy: DownloadStrategy.wifiOrCellular,
);

// Load content on-demand
await streamController.loadBundle('Level2');
```

## Download Strategies

```dart
// Only download on WiFi
DownloadStrategy.wifiOnly

// Download on WiFi or cellular
DownloadStrategy.wifiOrCellular

// Download on any connection
DownloadStrategy.any

// Manual download only (no auto-download)
DownloadStrategy.manual
```

## Checking Cache Status

```dart
// Check if a bundle is cached
final isCached = await streamController.isBundleCached('Level1');

// Get all cached bundles
final cachedBundles = await streamController.getCachedBundles();

// Get total cache size
final cacheSize = await streamController.getCacheSize();

// Clear cache
await streamController.clearCache();
```

## Working with Manifests

```dart
// Get the content manifest
final manifest = await streamController.getManifest();

// View available bundles
for (final bundle in manifest.bundles) {
  print('${bundle.name}: ${bundle.formattedSize}');
  print('  Base: ${bundle.isBase}');
  print('  SHA256: ${bundle.sha256}');
}

// Get streaming vs base sizes
print('Base size: ${manifest.formattedBaseSize}');
print('Streaming size: ${manifest.formattedStreamingSize}');
```

## Error Handling

```dart
// Listen to errors
streamController.errors.listen((error) {
  print('Error: ${error.type} - ${error.message}');
});

// Handle specific error types
streamController.errors.listen((error) {
  switch (error.type) {
    case StreamingErrorType.networkUnavailable:
      // Show offline message
      break;
    case StreamingErrorType.downloadFailed:
      // Show retry option
      break;
    case StreamingErrorType.manifestFetchFailed:
      // Handle manifest error
      break;
  }
});
```

## State Changes

```dart
// Listen to state changes
streamController.stateChanges.listen((state) {
  switch (state) {
    case StreamingState.initializing:
      // Show loading indicator
      break;
    case StreamingState.ready:
      // Ready to use
      break;
    case StreamingState.downloading:
      // Show progress UI
      break;
    case StreamingState.error:
      // Handle error state
      break;
  }
});
```

## Full Example

```dart
class StreamingGameWidget extends StatefulWidget {
  @override
  State<StreamingGameWidget> createState() => _StreamingGameWidgetState();
}

class _StreamingGameWidgetState extends State<StreamingGameWidget> {
  GameEngineController? _engineController;
  GameStreamController? _streamController;
  double _downloadProgress = 0.0;
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GameWidget(
          engineType: GameEngineType.unity,
          onEngineCreated: _onEngineCreated,
        ),
        if (!_isReady)
          _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Downloading game content...',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 8),
            Text(
              '${(_downloadProgress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEngineCreated(GameEngineController controller) async {
    _engineController = controller;

    // Initialize streaming
    _streamController = GameStreamController(
      engineController: controller,
      cloudUrl: 'https://cloud.gameframework.io',
      packageName: 'my-game',
      packageVersion: '1.0.0',
    );

    await _streamController!.initialize();

    // Listen to progress
    _streamController!.downloadProgress.listen((progress) {
      setState(() {
        _downloadProgress = progress.percentage;
      });
    });

    // Preload essential content
    await _streamController!.preloadContent(
      bundles: ['Level1', 'Characters'],
      strategy: DownloadStrategy.wifiOrCellular,
    );

    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _streamController?.dispose();
    super.dispose();
  }
}
```

## Unity Configuration

Before using streaming, you need to configure your Unity project:

1. **Install Addressables**: In Unity Editor, go to `Game Framework > Streaming > Setup Addressables`

2. **Configure Groups**: Assign assets to addressable groups:
   - **Base** groups: Essential content bundled with app
   - **Streaming** groups: Content downloaded at runtime

3. **Build with Streaming**: In your `.game.yml`:
   ```yaml
   engines:
     unity:
       project_path: ../UnityProject
       streaming:
         enabled: true
         base_content:
           - "Scenes/Bootstrap"
           - "UI/*"
         streamable_content:
           - "Scenes/Level*"
           - "Models/*"
         chunk_size_mb: 10
   ```

4. **Publish**: Run `game publish` to upload content to GameFramework Cloud

## API Reference

### GameStreamController

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize the controller (required before use) |
| `preloadContent()` | Download specified bundles |
| `loadBundle()` | Download and load a specific bundle |
| `loadScene()` | Load an addressable scene |
| `isBundleCached()` | Check if a bundle is cached |
| `getCachedBundles()` | Get list of cached bundle names |
| `getCacheSize()` | Get total cache size in bytes |
| `clearCache()` | Clear all cached content |
| `cancelDownloads()` | Cancel all active downloads |
| `dispose()` | Clean up resources |

### DownloadProgress

| Property | Description |
|----------|-------------|
| `bundleName` | Name of the bundle |
| `downloadedBytes` | Bytes downloaded |
| `totalBytes` | Total bytes to download |
| `percentage` | Progress as 0.0-1.0 |
| `percentageString` | Progress as "45%" |
| `state` | Current download state |
| `speedString` | Download speed (e.g., "1.2 MB/s") |
| `etaString` | Estimated time remaining |

### ContentManifest

| Property | Description |
|----------|-------------|
| `bundles` | List of all bundles |
| `baseBundles` | Bundles bundled with app |
| `streamingBundles` | Bundles to download |
| `totalSize` | Total content size |
| `baseSize` | Size of base content |
| `streamingSize` | Size of streaming content |

## License

See LICENSE file in the repository root.
