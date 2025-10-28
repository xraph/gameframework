import 'package:flutter/services.dart';
import 'package:gameframework/gameframework.dart';
import 'unreal_controller.dart';

/// Unreal Engine plugin for the Flutter Game Framework
///
/// Registers the Unreal Engine factory with the game framework registry.
class UnrealEnginePlugin {
  static const MethodChannel _channel = MethodChannel('gameframework_unreal');

  static bool _initialized = false;

  /// Initialize the Unreal Engine plugin
  ///
  /// This should be called in main() before runApp():
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   UnrealEnginePlugin.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void initialize() {
    if (_initialized) {
      return;
    }

    // Register Unreal engine factory
    GameEngineRegistry.instance.registerEngine(
      GameEngineType.unreal,
      UnrealEngineFactory(),
    );

    _initialized = true;
  }

  /// Check if Unreal Engine is supported on this platform
  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isEngineSupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get the Unreal Engine version
  static Future<String> getEngineVersion() async {
    try {
      final result = await _channel.invokeMethod<String>('getEngineVersion');
      return result ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get platform information
  static Future<String> getPlatformVersion() async {
    try {
      final result = await _channel.invokeMethod<String>('getPlatformVersion');
      return result ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }
}

/// Factory for creating Unreal Engine controllers
class UnrealEngineFactory implements GameEngineFactory {
  @override
  Future<GameEngineController> createController(
    int viewId,
    GameEngineConfig config,
  ) async {
    return UnrealController(viewId);
  }

  GameEngineType get engineType => GameEngineType.unreal;
}
