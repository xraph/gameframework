/// Unreal Engine quality settings model
///
/// Represents quality settings that can be applied to an Unreal Engine instance.
class UnrealQualitySettings {
  /// Overall scalability quality level (0-4)
  /// 0 = Low, 1 = Medium, 2 = High, 3 = Epic, 4 = Cinematic
  final int? qualityLevel;

  /// Anti-aliasing quality (0-4)
  final int? antiAliasingQuality;

  /// Shadow quality (0-4)
  final int? shadowQuality;

  /// Post-processing quality (0-4)
  final int? postProcessQuality;

  /// Texture quality (0-4)
  final int? textureQuality;

  /// Effects quality (0-4)
  final int? effectsQuality;

  /// Foliage quality (0-4)
  final int? foliageQuality;

  /// View distance quality (0-4)
  final int? viewDistanceQuality;

  /// Target frame rate (0 = unlimited)
  final int? targetFrameRate;

  /// Enable VSync
  final bool? enableVSync;

  /// Resolution scale (0.1 - 2.0)
  final double? resolutionScale;

  const UnrealQualitySettings({
    this.qualityLevel,
    this.antiAliasingQuality,
    this.shadowQuality,
    this.postProcessQuality,
    this.textureQuality,
    this.effectsQuality,
    this.foliageQuality,
    this.viewDistanceQuality,
    this.targetFrameRate,
    this.enableVSync,
    this.resolutionScale,
  });

  /// Create low quality preset
  factory UnrealQualitySettings.low() {
    return const UnrealQualitySettings(
      qualityLevel: 0,
      antiAliasingQuality: 0,
      shadowQuality: 0,
      postProcessQuality: 0,
      textureQuality: 0,
      effectsQuality: 0,
      foliageQuality: 0,
      viewDistanceQuality: 0,
      targetFrameRate: 30,
      enableVSync: false,
      resolutionScale: 0.75,
    );
  }

  /// Create medium quality preset
  factory UnrealQualitySettings.medium() {
    return const UnrealQualitySettings(
      qualityLevel: 1,
      antiAliasingQuality: 1,
      shadowQuality: 1,
      postProcessQuality: 1,
      textureQuality: 1,
      effectsQuality: 1,
      foliageQuality: 1,
      viewDistanceQuality: 1,
      targetFrameRate: 60,
      enableVSync: true,
      resolutionScale: 1.0,
    );
  }

  /// Create high quality preset
  factory UnrealQualitySettings.high() {
    return const UnrealQualitySettings(
      qualityLevel: 2,
      antiAliasingQuality: 2,
      shadowQuality: 2,
      postProcessQuality: 2,
      textureQuality: 2,
      effectsQuality: 2,
      foliageQuality: 2,
      viewDistanceQuality: 2,
      targetFrameRate: 60,
      enableVSync: true,
      resolutionScale: 1.0,
    );
  }

  /// Create epic quality preset
  factory UnrealQualitySettings.epic() {
    return const UnrealQualitySettings(
      qualityLevel: 3,
      antiAliasingQuality: 3,
      shadowQuality: 3,
      postProcessQuality: 3,
      textureQuality: 3,
      effectsQuality: 3,
      foliageQuality: 3,
      viewDistanceQuality: 3,
      targetFrameRate: 60,
      enableVSync: true,
      resolutionScale: 1.0,
    );
  }

  /// Create cinematic quality preset
  factory UnrealQualitySettings.cinematic() {
    return const UnrealQualitySettings(
      qualityLevel: 4,
      antiAliasingQuality: 4,
      shadowQuality: 4,
      postProcessQuality: 4,
      textureQuality: 4,
      effectsQuality: 4,
      foliageQuality: 4,
      viewDistanceQuality: 4,
      targetFrameRate: 0, // Unlimited
      enableVSync: false,
      resolutionScale: 1.0,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() {
    return {
      if (qualityLevel != null) 'qualityLevel': qualityLevel,
      if (antiAliasingQuality != null) 'antiAliasingQuality': antiAliasingQuality,
      if (shadowQuality != null) 'shadowQuality': shadowQuality,
      if (postProcessQuality != null) 'postProcessQuality': postProcessQuality,
      if (textureQuality != null) 'textureQuality': textureQuality,
      if (effectsQuality != null) 'effectsQuality': effectsQuality,
      if (foliageQuality != null) 'foliageQuality': foliageQuality,
      if (viewDistanceQuality != null) 'viewDistanceQuality': viewDistanceQuality,
      if (targetFrameRate != null) 'targetFrameRate': targetFrameRate,
      if (enableVSync != null) 'enableVSync': enableVSync,
      if (resolutionScale != null) 'resolutionScale': resolutionScale,
    };
  }

  /// Create from map
  factory UnrealQualitySettings.fromMap(Map<String, dynamic> map) {
    return UnrealQualitySettings(
      qualityLevel: map['qualityLevel'] as int?,
      antiAliasingQuality: map['antiAliasingQuality'] as int?,
      shadowQuality: map['shadowQuality'] as int?,
      postProcessQuality: map['postProcessQuality'] as int?,
      textureQuality: map['textureQuality'] as int?,
      effectsQuality: map['effectsQuality'] as int?,
      foliageQuality: map['foliageQuality'] as int?,
      viewDistanceQuality: map['viewDistanceQuality'] as int?,
      targetFrameRate: map['targetFrameRate'] as int?,
      enableVSync: map['enableVSync'] as bool?,
      resolutionScale: map['resolutionScale'] as double?,
    );
  }

  /// Copy with updated values
  UnrealQualitySettings copyWith({
    int? qualityLevel,
    int? antiAliasingQuality,
    int? shadowQuality,
    int? postProcessQuality,
    int? textureQuality,
    int? effectsQuality,
    int? foliageQuality,
    int? viewDistanceQuality,
    int? targetFrameRate,
    bool? enableVSync,
    double? resolutionScale,
  }) {
    return UnrealQualitySettings(
      qualityLevel: qualityLevel ?? this.qualityLevel,
      antiAliasingQuality: antiAliasingQuality ?? this.antiAliasingQuality,
      shadowQuality: shadowQuality ?? this.shadowQuality,
      postProcessQuality: postProcessQuality ?? this.postProcessQuality,
      textureQuality: textureQuality ?? this.textureQuality,
      effectsQuality: effectsQuality ?? this.effectsQuality,
      foliageQuality: foliageQuality ?? this.foliageQuality,
      viewDistanceQuality: viewDistanceQuality ?? this.viewDistanceQuality,
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      enableVSync: enableVSync ?? this.enableVSync,
      resolutionScale: resolutionScale ?? this.resolutionScale,
    );
  }
}
