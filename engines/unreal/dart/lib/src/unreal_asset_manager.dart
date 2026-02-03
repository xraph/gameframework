import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Callback for reporting asset loading progress.
typedef ProgressCallback = void Function(double progress);

/// Asset loading state enumeration.
enum AssetLoadState {
  /// Asset not loaded
  notLoaded,

  /// Asset currently loading
  loading,

  /// Asset loaded successfully
  loaded,

  /// Asset loading failed
  failed,
}

/// Information about a loaded asset.
class LoadedAssetInfo {
  /// Asset path/identifier
  final String path;

  /// Asset type
  final String assetType;

  /// Load state
  final AssetLoadState state;

  /// Size in bytes (if available)
  final int? sizeBytes;

  /// Load timestamp
  final DateTime loadedAt;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  LoadedAssetInfo({
    required this.path,
    required this.assetType,
    required this.state,
    this.sizeBytes,
    DateTime? loadedAt,
    Map<String, dynamic>? metadata,
  })  : loadedAt = loadedAt ?? DateTime.now(),
        metadata = metadata ?? {};
}

/// Asset manager for Unreal Engine streaming and asset loading.
///
/// Provides functionality for loading assets from local cache or remote URLs,
/// with progress reporting and caching support.
///
/// This integrates with Unreal Engine's Asset Manager and Primary Asset system.
///
/// Example:
/// ```dart
/// final assetManager = UnrealAssetManager(controller);
///
/// // Set cache path for downloaded assets
/// await assetManager.setCachePath('/path/to/cache');
///
/// // Load an asset with progress
/// await assetManager.loadAsset(
///   'Character/Hero.uasset',
///   onProgress: (progress) => print('Loading: ${(progress * 100).toInt()}%'),
/// );
///
/// // Load a level
/// await assetManager.loadLevel('/Game/Maps/MainMenu');
/// ```
class UnrealAssetManager {
  final MethodChannel _channel;

  /// Cache path for downloaded assets
  String? _cachePath;

  /// Loaded assets tracking
  final Map<String, LoadedAssetInfo> _loadedAssets = {};

  /// Active loading operations
  final Map<String, Completer<bool>> _activeLoads = {};

  /// Progress streams for active loads
  final Map<String, StreamController<double>> _progressStreams = {};

  // Statistics
  int _assetsLoaded = 0;
  int _assetsFailed = 0;
  int _totalBytesLoaded = 0;

  UnrealAssetManager(this._channel);

  // ============================================================
  // MARK: - Cache Management
  // ============================================================

  /// Set the cache path for downloaded assets.
  ///
  /// This should be called before loading any remote assets.
  Future<void> setCachePath(String path) async {
    try {
      await _channel.invokeMethod('asset#setCachePath', {'path': path});
      _cachePath = path;
      debugPrint('UnrealAssetManager: Cache path set to $path');
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to set cache path: $e');
      rethrow;
    }
  }

  /// Get the current cache path.
  String? get cachePath => _cachePath;

  /// Clear the asset cache.
  Future<void> clearCache() async {
    try {
      await _channel.invokeMethod('asset#clearCache');
      debugPrint('UnrealAssetManager: Cache cleared');
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to clear cache: $e');
      rethrow;
    }
  }

  /// Get cache size in bytes.
  Future<int> getCacheSize() async {
    try {
      final result = await _channel.invokeMethod<int>('asset#getCacheSize');
      return result ?? 0;
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to get cache size: $e');
      return 0;
    }
  }

  // ============================================================
  // MARK: - Asset Loading
  // ============================================================

  /// Load an asset by path.
  ///
  /// Returns true if the asset was loaded successfully.
  /// The [onProgress] callback reports loading progress (0.0 - 1.0).
  Future<bool> loadAsset(
    String assetPath, {
    ProgressCallback? onProgress,
    String? assetType,
    bool forceReload = false,
  }) async {
    // Check if already loaded
    if (!forceReload && isAssetLoaded(assetPath)) {
      onProgress?.call(1.0);
      return true;
    }

    // Check if already loading
    if (_activeLoads.containsKey(assetPath)) {
      // Wait for existing load to complete
      return _activeLoads[assetPath]!.future;
    }

    final completer = Completer<bool>();
    _activeLoads[assetPath] = completer;

    // Create progress stream for this load
    final progressController = StreamController<double>.broadcast();
    _progressStreams[assetPath] = progressController;

    // Subscribe to progress updates
    if (onProgress != null) {
      progressController.stream.listen(onProgress);
    }

    try {
      // Mark as loading
      _loadedAssets[assetPath] = LoadedAssetInfo(
        path: assetPath,
        assetType: assetType ?? 'unknown',
        state: AssetLoadState.loading,
      );

      // Start loading
      final result = await _channel.invokeMethod<bool>('asset#load', {
        'path': assetPath,
        'type': assetType,
        'forceReload': forceReload,
      });

      final success = result ?? false;

      if (success) {
        _assetsLoaded++;
        _loadedAssets[assetPath] = LoadedAssetInfo(
          path: assetPath,
          assetType: assetType ?? 'unknown',
          state: AssetLoadState.loaded,
        );
        progressController.add(1.0);
      } else {
        _assetsFailed++;
        _loadedAssets[assetPath] = LoadedAssetInfo(
          path: assetPath,
          assetType: assetType ?? 'unknown',
          state: AssetLoadState.failed,
        );
      }

      completer.complete(success);
      return success;
    } catch (e) {
      _assetsFailed++;
      _loadedAssets[assetPath] = LoadedAssetInfo(
        path: assetPath,
        assetType: assetType ?? 'unknown',
        state: AssetLoadState.failed,
        metadata: {'error': e.toString()},
      );
      completer.completeError(e);
      rethrow;
    } finally {
      _activeLoads.remove(assetPath);
      await progressController.close();
      _progressStreams.remove(assetPath);
    }
  }

  /// Load multiple assets in parallel.
  ///
  /// Returns a map of asset paths to load results.
  Future<Map<String, bool>> loadAssets(
    List<String> assetPaths, {
    ProgressCallback? onProgress,
    int maxConcurrent = 4,
  }) async {
    final results = <String, bool>{};
    int completed = 0;

    // Create batches
    final batches = <List<String>>[];
    for (int i = 0; i < assetPaths.length; i += maxConcurrent) {
      batches.add(assetPaths.sublist(
        i,
        (i + maxConcurrent).clamp(0, assetPaths.length),
      ));
    }

    for (final batch in batches) {
      final futures = batch.map((path) async {
        final success = await loadAsset(path);
        results[path] = success;
        completed++;
        onProgress?.call(completed / assetPaths.length);
        return success;
      });

      await Future.wait(futures);
    }

    return results;
  }

  /// Unload an asset.
  Future<void> unloadAsset(String assetPath) async {
    try {
      await _channel.invokeMethod('asset#unload', {'path': assetPath});
      _loadedAssets.remove(assetPath);
      debugPrint('UnrealAssetManager: Unloaded $assetPath');
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to unload $assetPath: $e');
      rethrow;
    }
  }

  /// Unload all loaded assets.
  Future<void> unloadAllAssets() async {
    final paths = _loadedAssets.keys.toList();
    for (final path in paths) {
      await unloadAsset(path);
    }
  }

  // ============================================================
  // MARK: - Level Loading
  // ============================================================

  /// Load a level/map.
  ///
  /// Returns true if the level was loaded successfully.
  Future<bool> loadLevel(
    String levelPath, {
    ProgressCallback? onProgress,
    bool async = true,
  }) async {
    try {
      final progressController = StreamController<double>.broadcast();

      if (onProgress != null) {
        progressController.stream.listen(onProgress);
      }

      final result = await _channel.invokeMethod<bool>('asset#loadLevel', {
        'path': levelPath,
        'async': async,
      });

      await progressController.close();
      return result ?? false;
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to load level $levelPath: $e');
      rethrow;
    }
  }

  /// Unload a level/map.
  Future<void> unloadLevel(String levelPath) async {
    try {
      await _channel.invokeMethod('asset#unloadLevel', {'path': levelPath});
      debugPrint('UnrealAssetManager: Unloaded level $levelPath');
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to unload level $levelPath: $e');
      rethrow;
    }
  }

  // ============================================================
  // MARK: - Catalog Management
  // ============================================================

  /// Update the asset catalog from a remote URL.
  ///
  /// This downloads and applies updates to the asset catalog,
  /// similar to Addressables catalog updates.
  Future<bool> updateCatalog(String catalogUrl) async {
    try {
      final result = await _channel.invokeMethod<bool>('asset#updateCatalog', {
        'url': catalogUrl,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to update catalog: $e');
      rethrow;
    }
  }

  /// Check if a catalog update is available.
  Future<bool> checkForCatalogUpdate(String catalogUrl) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('asset#checkCatalogUpdate', {
        'url': catalogUrl,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('UnrealAssetManager: Failed to check catalog update: $e');
      return false;
    }
  }

  // ============================================================
  // MARK: - Asset Queries
  // ============================================================

  /// Check if an asset is loaded.
  bool isAssetLoaded(String assetPath) {
    final info = _loadedAssets[assetPath];
    return info != null && info.state == AssetLoadState.loaded;
  }

  /// Check if an asset is currently loading.
  bool isAssetLoading(String assetPath) {
    return _activeLoads.containsKey(assetPath);
  }

  /// Get information about a loaded asset.
  LoadedAssetInfo? getAssetInfo(String assetPath) {
    return _loadedAssets[assetPath];
  }

  /// Get all loaded assets.
  List<LoadedAssetInfo> getLoadedAssets() {
    return _loadedAssets.values
        .where((info) => info.state == AssetLoadState.loaded)
        .toList();
  }

  /// Get loading progress stream for an asset.
  ///
  /// Returns null if the asset is not currently loading.
  Stream<double>? getLoadingProgress(String assetPath) {
    return _progressStreams[assetPath]?.stream;
  }

  // ============================================================
  // MARK: - Statistics
  // ============================================================

  /// Get asset manager statistics.
  AssetManagerStatistics get statistics => AssetManagerStatistics(
        assetsLoaded: _assetsLoaded,
        assetsFailed: _assetsFailed,
        totalBytesLoaded: _totalBytesLoaded,
        currentlyLoaded: _loadedAssets.values
            .where((i) => i.state == AssetLoadState.loaded)
            .length,
        currentlyLoading: _activeLoads.length,
      );

  /// Reset statistics.
  void resetStatistics() {
    _assetsLoaded = 0;
    _assetsFailed = 0;
    _totalBytesLoaded = 0;
  }

  /// Dispose the asset manager.
  void dispose() {
    for (final controller in _progressStreams.values) {
      controller.close();
    }
    _progressStreams.clear();
    _activeLoads.clear();
  }
}

/// Statistics for the asset manager.
class AssetManagerStatistics {
  final int assetsLoaded;
  final int assetsFailed;
  final int totalBytesLoaded;
  final int currentlyLoaded;
  final int currentlyLoading;

  AssetManagerStatistics({
    required this.assetsLoaded,
    required this.assetsFailed,
    required this.totalBytesLoaded,
    required this.currentlyLoaded,
    required this.currentlyLoading,
  });

  /// Success rate (0.0 - 1.0)
  double get successRate {
    final total = assetsLoaded + assetsFailed;
    return total > 0 ? assetsLoaded / total : 1.0;
  }

  @override
  String toString() => 'AssetStats(loaded=$assetsLoaded, failed=$assetsFailed, '
      'current=$currentlyLoaded, loading=$currentlyLoading)';
}
