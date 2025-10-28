/// Event fired when a scene/level is loaded in the engine
class GameSceneLoaded {
  const GameSceneLoaded({
    required this.name,
    required this.buildIndex,
    required this.isLoaded,
    required this.isValid,
    this.metadata,
  });

  /// The name of the scene/level
  final String name;

  /// The build index of the scene
  final int buildIndex;

  /// Whether the scene is loaded
  final bool isLoaded;

  /// Whether the scene is valid
  final bool isValid;

  /// Optional engine-specific metadata
  final Map<String, dynamic>? metadata;

  /// Create from platform map
  factory GameSceneLoaded.fromMap(Map<String, dynamic> map) {
    return GameSceneLoaded(
      name: map['name'] as String? ?? '',
      buildIndex: map['buildIndex'] as int? ?? 0,
      isLoaded: map['isLoaded'] as bool? ?? false,
      isValid: map['isValid'] as bool? ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'buildIndex': buildIndex,
      'isLoaded': isLoaded,
      'isValid': isValid,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'GameSceneLoaded('
        'name: $name, '
        'buildIndex: $buildIndex, '
        'isLoaded: $isLoaded, '
        'isValid: $isValid, '
        'metadata: $metadata'
        ')';
  }
}
