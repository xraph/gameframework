/// Flutter Game Framework - Asset Streaming Support
///
/// Provides on-demand downloading of Unity Addressable assets from
/// GameFramework Cloud, enabling apps to ship with minimal base size
/// and download additional content at runtime.
///
/// ## Getting Started
///
/// 1. Add the package to your pubspec.yaml:
/// ```yaml
/// dependencies:
///   gameframework_stream: ^1.0.0
/// ```
///
/// 2. Initialize streaming with your Unity controller:
/// ```dart
/// final streamController = GameStreamController(
///   engineController: unityController,
///   cloudUrl: 'https://cloud.gameframework.io',
///   packageName: 'my-game',
///   packageVersion: '1.0.0',
/// );
///
/// await streamController.initialize();
/// ```
///
/// 3. Preload content before launching the game:
/// ```dart
/// await streamController.preloadContent(
///   bundles: ['Level1', 'CoreUI'],
///   strategy: DownloadStrategy.wifiOrCellular,
/// );
/// ```
///
/// 4. Load additional content on-demand:
/// ```dart
/// await streamController.loadBundle('Level2');
/// ```
///
/// ## Features
///
/// - Download progress tracking
/// - Automatic cache management
/// - Network-aware downloading
/// - SHA256 verification
/// - Resume interrupted downloads
///
/// See the [README](https://github.com/xraph/flutter-game-framework/tree/main/packages/gameframework_stream#readme)
/// for complete documentation.
library gameframework_stream;

// Core
export 'src/game_stream_controller.dart';

// Models
export 'src/models/content_manifest.dart';
export 'src/models/download_progress.dart';
export 'src/models/download_strategy.dart';
export 'src/models/content_bundle.dart';

// Utilities (for advanced use)
export 'src/content_downloader.dart';
export 'src/cache_manager.dart';
