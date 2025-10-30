import 'package:gameframework/gameframework.dart';
import 'unity_controller.dart';
import 'unity_controller_web.dart'
    if (dart.library.io) 'unity_controller.dart' as platform;

/// Unity Engine Plugin for Flutter Game Framework
///
/// This plugin registers the Unity engine factory with the game framework,
/// allowing Unity engines to be created and managed through the unified API.
class UnityEnginePlugin {
  static bool _initialized = false;
  static const String _engineType = 'unity';

  /// Initialize the Unity plugin
  ///
  /// This must be called before using Unity engines in your app.
  /// Typically called in main() before runApp().
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   UnityEnginePlugin.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void initialize() {
    if (_initialized) {
      return;
    }

    // Register Unity factory with the game framework
    GameEngineRegistry.instance.registerEngine(
      GameEngineType.unity,
      UnityEngineFactory(),
    );

    _initialized = true;
  }

  /// Check if the Unity plugin is initialized
  static bool get isInitialized => _initialized;

  /// Get the Unity engine type identifier
  static String get engineType => _engineType;
}

/// Factory for creating Unity controllers
class UnityEngineFactory implements GameEngineFactory {
  @override
  Future<GameEngineController> createController(
    int viewId,
    GameEngineConfig config,
  ) async {
    // Use platform-specific controller
    // On web: UnityControllerWeb
    // On mobile/desktop: UnityController
    return platform.createUnityController(viewId, config);
  }
}
