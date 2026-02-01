/// Represents a content bundle that can be downloaded
class ContentBundle {
  /// Unique name/identifier for the bundle
  final String name;

  /// Download URL for this bundle
  final String url;

  /// Size of the bundle in bytes
  final int sizeBytes;

  /// SHA256 hash for verification
  final String sha256;

  /// Whether this bundle is part of the base app content
  final bool isBase;

  /// List of other bundles this one depends on
  final List<String> dependencies;

  /// Optional group/category for this bundle
  final String? group;

  /// Optional metadata
  final Map<String, dynamic>? metadata;

  ContentBundle({
    required this.name,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.isBase,
    this.dependencies = const [],
    this.group,
    this.metadata,
  });

  /// Create from JSON
  factory ContentBundle.fromJson(Map<String, dynamic> json) {
    return ContentBundle(
      name: json['name'] as String,
      url: json['url'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? json['size_bytes'] as int? ?? 0,
      sha256: json['sha256'] as String? ?? '',
      isBase: json['isBase'] as bool? ?? json['is_base'] as bool? ?? false,
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      group: json['group'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'sizeBytes': sizeBytes,
      'sha256': sha256,
      'isBase': isBase,
      'dependencies': dependencies,
      if (group != null) 'group': group,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Human-readable size
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'ContentBundle(name: $name, size: $formattedSize, isBase: $isBase)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentBundle && other.name == name && other.sha256 == sha256;
  }

  @override
  int get hashCode => name.hashCode ^ sha256.hashCode;
}
