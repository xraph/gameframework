import 'content_bundle.dart';

/// Manifest describing all available streaming content
class ContentManifest {
  /// Version of the content
  final String version;

  /// Base URL for downloading content
  final String baseUrl;

  /// List of all available bundles
  final List<ContentBundle> bundles;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  /// Build timestamp
  final DateTime? buildTime;

  /// Target platform
  final String? platform;

  ContentManifest({
    required this.version,
    required this.baseUrl,
    required this.bundles,
    this.metadata = const {},
    this.buildTime,
    this.platform,
  });

  /// Create from JSON
  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final bundlesList = json['bundles'] as List<dynamic>?;

    return ContentManifest(
      version: json['version'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? json['base_url'] as String? ?? '',
      bundles: bundlesList
              ?.map((b) => ContentBundle.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      buildTime: json['buildTime'] != null
          ? DateTime.tryParse(json['buildTime'] as String)
          : null,
      platform: json['platform'] as String? ?? json['buildTarget'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'baseUrl': baseUrl,
      'bundles': bundles.map((b) => b.toJson()).toList(),
      'metadata': metadata,
      if (buildTime != null) 'buildTime': buildTime!.toIso8601String(),
      if (platform != null) 'platform': platform,
    };
  }

  /// Get base bundles (bundled with app)
  List<ContentBundle> get baseBundles =>
      bundles.where((b) => b.isBase).toList();

  /// Get streaming bundles (downloaded at runtime)
  List<ContentBundle> get streamingBundles =>
      bundles.where((b) => !b.isBase).toList();

  /// Get bundles by group
  List<ContentBundle> getBundlesByGroup(String group) =>
      bundles.where((b) => b.group == group).toList();

  /// Get bundle by name
  ContentBundle? getBundleByName(String name) {
    try {
      return bundles.firstWhere((b) => b.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Total size of all content
  int get totalSize => bundles.fold<int>(0, (sum, b) => sum + b.sizeBytes);

  /// Size of base content
  int get baseSize =>
      baseBundles.fold<int>(0, (sum, b) => sum + b.sizeBytes);

  /// Size of streaming content
  int get streamingSize =>
      streamingBundles.fold<int>(0, (sum, b) => sum + b.sizeBytes);

  /// Number of bundles
  int get bundleCount => bundles.length;

  /// Human-readable total size
  String get formattedTotalSize => _formatBytes(totalSize);

  /// Human-readable base size
  String get formattedBaseSize => _formatBytes(baseSize);

  /// Human-readable streaming size
  String get formattedStreamingSize => _formatBytes(streamingSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get all unique groups
  Set<String> get groups =>
      bundles.where((b) => b.group != null).map((b) => b.group!).toSet();

  /// Resolve dependencies for a bundle (returns bundle + all dependencies)
  List<ContentBundle> resolveDependencies(String bundleName) {
    final result = <ContentBundle>[];
    final visited = <String>{};

    void resolve(String name) {
      if (visited.contains(name)) return;
      visited.add(name);

      final bundle = getBundleByName(name);
      if (bundle == null) return;

      // Resolve dependencies first
      for (final dep in bundle.dependencies) {
        resolve(dep);
      }

      result.add(bundle);
    }

    resolve(bundleName);
    return result;
  }

  @override
  String toString() {
    return 'ContentManifest(version: $version, bundles: $bundleCount, total: $formattedTotalSize)';
  }
}
