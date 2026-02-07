import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gameframework/gameframework.dart';

import 'cache_manager.dart';
import 'content_downloader.dart';
import 'models/content_manifest.dart';
import 'models/download_progress.dart';
import 'models/download_strategy.dart';

/// Controller for streaming game content from GameFramework Cloud
///
/// This controller manages downloading and loading Unity Addressable
/// content at runtime, enabling apps to ship with minimal base size.
///
/// Example:
/// ```dart
/// final streamController = GameStreamController(
///   engineController: unityController,
///   cloudUrl: 'https://cloud.gameframework.io',
///   packageName: 'my-game',
///   packageVersion: '1.0.0',
/// );
///
/// await streamController.initialize();
///
/// // Listen to download progress
/// streamController.downloadProgress.listen((progress) {
///   print('${progress.bundleName}: ${progress.percentageString}');
/// });
///
/// // Preload content
/// await streamController.preloadContent(
///   bundles: ['Level1', 'CoreUI'],
///   strategy: DownloadStrategy.wifiOrCellular,
/// );
///
/// // Load content on-demand
/// await streamController.loadBundle('Level2');
/// ```
class GameStreamController {
  /// The game engine controller
  final GameEngineController engineController;

  /// Cloud URL for fetching content
  final String cloudUrl;

  /// Package name
  final String packageName;

  /// Package version
  final String packageVersion;

  /// HTTP client for API calls
  final http.Client _httpClient;

  /// Content downloader
  late final ContentDownloader _downloader;

  /// Cache manager
  late final CacheManager _cacheManager;

  /// Content manifest
  ContentManifest? _manifest;

  /// Whether initialized
  bool _isInitialized = false;

  /// Progress stream controller
  final _progressController = StreamController<DownloadProgress>.broadcast();

  /// Error stream controller
  final _errorController = StreamController<StreamingError>.broadcast();

  /// State change controller
  final _stateController = StreamController<StreamingState>.broadcast();

  /// Current state
  StreamingState _state = StreamingState.uninitialized;

  /// Create a new GameStreamController
  GameStreamController({
    required this.engineController,
    required this.cloudUrl,
    required this.packageName,
    required this.packageVersion,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Stream of download progress events
  Stream<DownloadProgress> get downloadProgress => _progressController.stream;

  /// Stream of errors
  Stream<StreamingError> get errors => _errorController.stream;

  /// Stream of state changes
  Stream<StreamingState> get stateChanges => _stateController.stream;

  /// Current state
  StreamingState get state => _state;

  /// Whether initialized
  bool get isInitialized => _isInitialized;

  /// Content manifest (null until initialized)
  ContentManifest? get manifest => _manifest;

  /// Initialize the streaming controller
  ///
  /// This fetches the content manifest and configures Unity to use
  /// the local cache for loading addressables.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setState(StreamingState.initializing);

    try {
      // Initialize cache manager
      _cacheManager = CacheManager();
      await _cacheManager.initialize();

      // Initialize downloader
      _downloader = ContentDownloader(
        cacheManager: _cacheManager,
        httpClient: _httpClient,
      );

      // Fetch manifest
      _manifest = await _fetchManifest();

      // Configure Unity to use cache path
      await _configureUnityCachePath();

      _isInitialized = true;
      _setState(StreamingState.ready);
    } catch (e) {
      _setState(StreamingState.error);
      _errorController.add(StreamingError(
        type: StreamingErrorType.initializationFailed,
        message: 'Failed to initialize streaming: $e',
      ));
      rethrow;
    }
  }

  /// Preload content bundles
  ///
  /// [bundles] - List of bundle names to download, or null for all streaming content
  /// [strategy] - Download strategy (WiFi only, cellular allowed, etc.)
  ///
  /// Returns when all specified bundles are downloaded.
  Future<void> preloadContent({
    List<String>? bundles,
    DownloadStrategy strategy = DownloadStrategy.wifiOnly,
  }) async {
    _ensureInitialized();

    final bundlesToDownload = bundles != null
        ? _manifest!.bundles.where((b) => bundles.contains(b.name)).toList()
        : _manifest!.streamingBundles;

    if (bundlesToDownload.isEmpty) {
      debugPrint('No bundles to download');
      return;
    }

    _setState(StreamingState.downloading);

    await for (final progress in _downloader.downloadBundles(
      bundlesToDownload,
      strategy,
    )) {
      _progressController.add(progress);
    }

    _setState(StreamingState.ready);
  }

  /// Load a specific bundle
  ///
  /// Downloads the bundle if not cached, then tells Unity to load it.
  Future<void> loadBundle(String bundleName) async {
    _ensureInitialized();

    final bundle = _manifest!.getBundleByName(bundleName);
    if (bundle == null) {
      throw StreamingError(
        type: StreamingErrorType.bundleNotFound,
        message: 'Bundle not found: $bundleName',
      );
    }

    // Download if not cached
    if (!await _cacheManager.isCachedWithHash(bundleName, bundle.sha256)) {
      _setState(StreamingState.downloading);

      await for (final progress in _downloader.downloadBundle(bundle)) {
        _progressController.add(progress);

        if (progress.isFailed) {
          _setState(StreamingState.error);
          throw StreamingError(
            type: StreamingErrorType.downloadFailed,
            message: progress.error ?? 'Download failed',
          );
        }
      }

      _setState(StreamingState.ready);
    }

    // Tell Unity to load the bundle
    await engineController.sendMessage(
      'FlutterAddressablesManager',
      'LoadAssetBundle',
      bundleName,
    );
  }

  /// Load a scene from an addressable bundle
  ///
  /// Downloads the bundle if needed, then loads the scene in Unity.
  Future<void> loadScene(
    String sceneName, {
    String loadMode = 'Single',
  }) async {
    _ensureInitialized();

    // Find which bundle contains this scene
    // (This requires the manifest to include scene-to-bundle mapping)
    // For now, assume scene name matches bundle name or there's metadata

    await engineController.sendJsonMessage(
      'FlutterAddressablesManager',
      'LoadSceneAsync',
      {
        'sceneName': sceneName,
        'callbackId': DateTime.now().millisecondsSinceEpoch.toString(),
        'loadMode': loadMode,
      },
    );
  }

  /// Get the content manifest
  Future<ContentManifest> getManifest() async {
    _ensureInitialized();
    return _manifest!;
  }

  /// Check which bundles are cached
  Future<List<String>> getCachedBundles() async {
    _ensureInitialized();
    return _cacheManager.getCachedBundleNames();
  }

  /// Check if a specific bundle is cached
  Future<bool> isBundleCached(String bundleName) async {
    _ensureInitialized();
    final bundle = _manifest!.getBundleByName(bundleName);
    if (bundle == null) return false;
    return await _cacheManager.isCachedWithHash(bundleName, bundle.sha256);
  }

  /// Get total cache size
  Future<int> getCacheSize() async {
    _ensureInitialized();
    return await _cacheManager.getCacheSize();
  }

  /// Clear all cached content
  Future<void> clearCache() async {
    _ensureInitialized();
    await _cacheManager.clearCache();
  }

  /// Cancel all active downloads
  void cancelDownloads() {
    _downloader.cancelAllDownloads();
    _setState(StreamingState.ready);
  }

  /// Dispose resources
  void dispose() {
    _downloader.dispose();
    _progressController.close();
    _errorController.close();
    _stateController.close();
    _httpClient.close();
  }

  // Private methods

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StreamingError(
        type: StreamingErrorType.notInitialized,
        message:
            'GameStreamController not initialized. Call initialize() first.',
      );
    }
  }

  void _setState(StreamingState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<ContentManifest> _fetchManifest() async {
    final url =
        '$cloudUrl/v1/packages/$packageName/versions/$packageVersion/manifest.json';

    try {
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ContentManifest.fromJson(json);
    } catch (e) {
      throw StreamingError(
        type: StreamingErrorType.manifestFetchFailed,
        message: 'Failed to fetch manifest: $e',
      );
    }
  }

  Future<void> _configureUnityCachePath() async {
    final cachePath = await _cacheManager.getCachePath();

    // Send cache path to Unity
    await engineController.sendMessage(
      'FlutterAddressablesManager',
      'SetCachePath',
      cachePath,
    );
  }
}

/// State of the streaming controller
enum StreamingState {
  /// Not yet initialized
  uninitialized,

  /// Currently initializing
  initializing,

  /// Ready for use
  ready,

  /// Currently downloading content
  downloading,

  /// An error occurred
  error,
}

/// Error type for streaming operations
enum StreamingErrorType {
  /// Controller not initialized
  notInitialized,

  /// Initialization failed
  initializationFailed,

  /// Manifest fetch failed
  manifestFetchFailed,

  /// Bundle not found in manifest
  bundleNotFound,

  /// Download failed
  downloadFailed,

  /// Network not available
  networkUnavailable,

  /// Cache error
  cacheError,
}

/// Error class for streaming operations
class StreamingError implements Exception {
  final StreamingErrorType type;
  final String message;
  final Object? cause;

  StreamingError({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'StreamingError($type): $message';
}
