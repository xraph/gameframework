/// Configuration object for game engine initialization
class GameEngineConfig {
  const GameEngineConfig({
    this.fullscreen = false,
    this.hideStatusBar = false,
    this.runImmediately = false,
    this.unloadOnDispose = false,
    this.enableDebugLogs = true,
    this.targetFrameRate,
    this.engineSpecificConfig,
  });

  /// Force engine to fullscreen mode
  final bool fullscreen;

  /// Hide system status bar (mobile only)
  final bool hideStatusBar;

  /// Start engine immediately on widget creation
  /// If false, you must manually call controller.create()
  final bool runImmediately;

  /// Automatically unload engine when widget is disposed
  /// If false, engine stays loaded in memory
  final bool unloadOnDispose;

  /// Enable debug logging from the framework
  final bool enableDebugLogs;

  /// Target frame rate for the engine
  /// Null means use engine default
  final int? targetFrameRate;

  /// Engine-specific configuration options
  /// This allows passing custom config to specific engines
  ///
  /// Example for Unity:
  /// ```dart
  /// engineSpecificConfig: {
  ///   'graphicsAPI': 'OpenGLES3',
  ///   'useARCore': true,
  /// }
  /// ```
  final Map<String, dynamic>? engineSpecificConfig;

  /// Create a copy with updated values
  GameEngineConfig copyWith({
    bool? fullscreen,
    bool? hideStatusBar,
    bool? runImmediately,
    bool? unloadOnDispose,
    bool? enableDebugLogs,
    int? targetFrameRate,
    Map<String, dynamic>? engineSpecificConfig,
  }) {
    return GameEngineConfig(
      fullscreen: fullscreen ?? this.fullscreen,
      hideStatusBar: hideStatusBar ?? this.hideStatusBar,
      runImmediately: runImmediately ?? this.runImmediately,
      unloadOnDispose: unloadOnDispose ?? this.unloadOnDispose,
      enableDebugLogs: enableDebugLogs ?? this.enableDebugLogs,
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      engineSpecificConfig: engineSpecificConfig ?? this.engineSpecificConfig,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() {
    return {
      'fullscreen': fullscreen,
      'hideStatusBar': hideStatusBar,
      'runImmediately': runImmediately,
      'unloadOnDispose': unloadOnDispose,
      'enableDebugLogs': enableDebugLogs,
      'targetFrameRate': targetFrameRate,
      'engineSpecificConfig': engineSpecificConfig,
    };
  }

  @override
  String toString() {
    return 'GameEngineConfig('
        'fullscreen: $fullscreen, '
        'hideStatusBar: $hideStatusBar, '
        'runImmediately: $runImmediately, '
        'unloadOnDispose: $unloadOnDispose, '
        'enableDebugLogs: $enableDebugLogs, '
        'targetFrameRate: $targetFrameRate, '
        'engineSpecificConfig: $engineSpecificConfig'
        ')';
  }
}
