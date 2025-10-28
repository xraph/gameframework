import 'game_engine_controller.dart';
import '../models/game_engine_config.dart';

/// Factory interface for creating engine controllers
///
/// Each engine plugin must implement this factory to create
/// its specific controller implementation
abstract class GameEngineFactory {
  /// Create a controller for this engine
  ///
  /// [viewId] - Unique identifier for the platform view
  /// [config] - Configuration for the engine
  ///
  /// Returns a controller instance for this engine
  Future<GameEngineController> createController(
    int viewId,
    GameEngineConfig config,
  );
}
