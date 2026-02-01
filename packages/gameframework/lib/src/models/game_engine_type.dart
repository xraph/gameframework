/// Enum representing supported game engines
enum GameEngineType {
  /// Unity game engine
  unity,

  /// Unreal Engine
  unreal,

  // Future engines can be added here
}

extension GameEngineTypeExtension on GameEngineType {
  /// Get the engine name as a string
  String get engineName {
    switch (this) {
      case GameEngineType.unity:
        return 'Unity';
      case GameEngineType.unreal:
        return 'Unreal Engine';
    }
  }

  /// Get the engine identifier for platform channels
  String get identifier {
    switch (this) {
      case GameEngineType.unity:
        return 'unity';
      case GameEngineType.unreal:
        return 'unreal';
    }
  }
}
