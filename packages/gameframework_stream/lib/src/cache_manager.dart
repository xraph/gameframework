import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Manages local cache for downloaded streaming content
class CacheManager {
  static const String _cacheDirName = 'gameframework_streaming';
  static const String _manifestFileName = 'cache_manifest.json';

  Directory? _cacheDir;
  Map<String, CacheEntry> _cacheManifest = {};

  /// Initialize the cache manager
  Future<void> initialize() async {
    final appCacheDir = await getApplicationCacheDirectory();
    _cacheDir = Directory('${appCacheDir.path}/$_cacheDirName');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    await _loadManifest();
  }

  /// Get the cache directory path
  Future<String> getCachePath() async {
    if (_cacheDir == null) await initialize();
    return _cacheDir!.path;
  }

  /// Check if a bundle is cached
  Future<bool> isCached(String bundleName) async {
    if (_cacheDir == null) await initialize();

    final entry = _cacheManifest[bundleName];
    if (entry == null) return false;

    // Verify file exists
    final file = File('${_cacheDir!.path}/$bundleName');
    if (!await file.exists()) {
      _cacheManifest.remove(bundleName);
      await _saveManifest();
      return false;
    }

    return true;
  }

  /// Check if a bundle is cached with matching hash
  Future<bool> isCachedWithHash(
      String bundleName, String expectedSha256) async {
    if (!await isCached(bundleName)) return false;

    final entry = _cacheManifest[bundleName];
    return entry?.sha256 == expectedSha256;
  }

  /// Get cached bundle file path
  Future<String?> getCachedBundlePath(String bundleName) async {
    if (!await isCached(bundleName)) return null;
    return '${_cacheDir!.path}/$bundleName';
  }

  /// Cache a bundle
  Future<void> cacheBundle(
    String bundleName,
    List<int> data, {
    String? sha256Hash,
  }) async {
    if (_cacheDir == null) await initialize();

    // Write file
    final file = File('${_cacheDir!.path}/$bundleName');
    await file.writeAsBytes(data);

    // Calculate hash if not provided
    final hash = sha256Hash ?? sha256.convert(data).toString();

    // Update manifest
    _cacheManifest[bundleName] = CacheEntry(
      name: bundleName,
      sha256: hash,
      sizeBytes: data.length,
      cachedAt: DateTime.now(),
    );

    await _saveManifest();
  }

  /// Cache a bundle from stream
  Future<void> cacheBundleFromStream(
    String bundleName,
    Stream<List<int>> dataStream, {
    required int expectedSize,
    required String sha256Hash,
  }) async {
    if (_cacheDir == null) await initialize();

    // Write file from stream
    final file = File('${_cacheDir!.path}/$bundleName');
    final sink = file.openWrite();

    await for (final chunk in dataStream) {
      sink.add(chunk);
    }

    await sink.close();

    // Update manifest
    _cacheManifest[bundleName] = CacheEntry(
      name: bundleName,
      sha256: sha256Hash,
      sizeBytes: expectedSize,
      cachedAt: DateTime.now(),
    );

    await _saveManifest();
  }

  /// Remove a cached bundle
  Future<void> removeBundle(String bundleName) async {
    if (_cacheDir == null) await initialize();

    final file = File('${_cacheDir!.path}/$bundleName');
    if (await file.exists()) {
      await file.delete();
    }

    _cacheManifest.remove(bundleName);
    await _saveManifest();
  }

  /// Clear all cached bundles
  Future<void> clearCache() async {
    if (_cacheDir == null) await initialize();

    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }

    _cacheManifest.clear();
    await _saveManifest();
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    if (_cacheDir == null) await initialize();

    int total = 0;
    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Get list of cached bundle names
  List<String> getCachedBundleNames() {
    return _cacheManifest.keys.toList();
  }

  /// Get cache entry for a bundle
  CacheEntry? getCacheEntry(String bundleName) {
    return _cacheManifest[bundleName];
  }

  /// Verify cache integrity
  Future<List<String>> verifyCache() async {
    if (_cacheDir == null) await initialize();

    final invalidBundles = <String>[];

    for (final entry in _cacheManifest.entries) {
      final file = File('${_cacheDir!.path}/${entry.key}');

      if (!await file.exists()) {
        invalidBundles.add(entry.key);
        continue;
      }

      // Verify hash
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (hash != entry.value.sha256) {
        invalidBundles.add(entry.key);
      }
    }

    // Remove invalid entries
    for (final name in invalidBundles) {
      await removeBundle(name);
    }

    return invalidBundles;
  }

  /// Load cache manifest from disk
  Future<void> _loadManifest() async {
    final manifestFile = File('${_cacheDir!.path}/$_manifestFileName');

    if (!await manifestFile.exists()) {
      _cacheManifest = {};
      return;
    }

    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final entries = json['entries'] as Map<String, dynamic>?;

      _cacheManifest = {};
      entries?.forEach((key, value) {
        _cacheManifest[key] =
            CacheEntry.fromJson(value as Map<String, dynamic>);
      });
    } catch (e) {
      // Invalid manifest, start fresh
      _cacheManifest = {};
    }
  }

  /// Save cache manifest to disk
  Future<void> _saveManifest() async {
    final manifestFile = File('${_cacheDir!.path}/$_manifestFileName');

    final json = {
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': _cacheManifest.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };

    await manifestFile.writeAsString(jsonEncode(json));
  }
}

/// Entry in the cache manifest
class CacheEntry {
  final String name;
  final String sha256;
  final int sizeBytes;
  final DateTime cachedAt;

  CacheEntry({
    required this.name,
    required this.sha256,
    required this.sizeBytes,
    required this.cachedAt,
  });

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      name: json['name'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sha256': sha256,
      'sizeBytes': sizeBytes,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }
}
