import 'game_engine_controller.dart';
import 'game_engine_factory.dart';
import '../models/game_engine_config.dart';
import '../models/game_engine_type.dart';
import '../exceptions/game_engine_exception.dart';

/// Registry for managing game engine implementations
///
/// This singleton class manages the registration and creation of
/// engine controllers. Engine plugins register themselves here
/// during initialization.
class GameEngineRegistry {
  GameEngineRegistry._();

  static final GameEngineRegistry _instance = GameEngineRegistry._();
  static GameEngineRegistry get instance => _instance;

  final Map<GameEngineType, GameEngineFactory> _factories = {};

  /// Register a game engine implementation
  ///
  /// This is typically called by engine plugins during initialization:
  /// ```dart
  /// void main() {
  ///   UnityEnginePlugin.initialize(); // Registers Unity
  ///   runApp(MyApp());
  /// }
  /// ```
  void registerEngine(
    GameEngineType type,
    GameEngineFactory factory,
  ) {
    _factories[type] = factory;
  }

  /// Unregister an engine (rarely needed)
  void unregisterEngine(GameEngineType type) {
    _factories.remove(type);
  }

  /// Check if an engine is registered
  bool isEngineRegistered(GameEngineType type) {
    return _factories.containsKey(type);
  }

  /// Get list of registered engines
  List<GameEngineType> get registeredEngines {
    return _factories.keys.toList();
  }

  /// Create a controller for the specified engine
  ///
  /// Throws [EngineNotRegisteredException] if engine is not registered
  Future<GameEngineController> createController(
    GameEngineType type,
    int viewId,
    GameEngineConfig config,
  ) async {
    final factory = _factories[type];
    if (factory == null) {
      throw EngineNotRegisteredException(type);
    }
    return factory.createController(viewId, config);
  }

  /// Clear all registrations (mainly for testing)
  void clear() {
    _factories.clear();
  }
}
