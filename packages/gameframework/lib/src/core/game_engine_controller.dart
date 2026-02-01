import 'dart:async';
import '../models/game_engine_event.dart';
import '../models/game_engine_message.dart';
import '../models/game_engine_type.dart';
import '../models/game_scene_loaded.dart';

/// Callback types
typedef GameEngineCreatedCallback = void Function(
    GameEngineController controller);
typedef GameEngineMessageCallback = void Function(GameEngineMessage message);
typedef GameEngineSceneLoadedCallback = void Function(GameSceneLoaded scene);
typedef GameEngineUnloadCallback = void Function();

/// Abstract controller interface for all game engines
///
/// This provides a unified API for controlling game engines regardless
/// of the specific engine implementation (Unity, Unreal, etc.)
abstract class GameEngineController {
  /// Check if the engine is initialized and ready
  Future<bool> isReady();

  /// Check if the engine is currently paused
  Future<bool> isPaused();

  /// Check if the engine is loaded
  Future<bool> isLoaded();

  /// Check if the engine is running in background
  Future<bool> isInBackground();

  /// Create/initialize the engine player
  /// Call this if the engine is not ready or is unloaded
  ///
  /// Returns true if creation was successful
  Future<bool> create();

  /// Send a string message to the engine
  ///
  /// [target] - The target object/actor in the engine
  /// [method] - The method/function to call
  /// [data] - String data to send
  ///
  /// Example:
  /// ```dart
  /// controller.sendMessage('GameManager', 'SetDifficulty', 'Hard');
  /// ```
  Future<void> sendMessage(
    String target,
    String method,
    String data,
  );

  /// Send a JSON message to the engine
  ///
  /// [target] - The target object/actor in the engine
  /// [method] - The method/function to call
  /// [data] - Map that will be serialized to JSON
  ///
  /// Example:
  /// ```dart
  /// controller.sendJsonMessage('GameManager', 'LoadLevel', {
  ///   'levelId': 3,
  ///   'difficulty': 'hard',
  ///   'playerData': {...}
  /// });
  /// ```
  Future<void> sendJsonMessage(
    String target,
    String method,
    Map<String, dynamic> data,
  );

  /// Pause the engine execution
  Future<void> pause();

  /// Resume the engine execution
  Future<void> resume();

  /// Unload the engine (keeps it in memory but stops execution)
  /// Useful for temporary switches
  Future<void> unload();

  /// Completely quit/destroy the engine
  /// This will terminate the engine process
  Future<void> quit();

  /// Set the streaming cache path for addressable assets
  ///
  /// This configures the engine to load asset bundles from the specified
  /// local path instead of remote URLs.
  ///
  /// [path] - The local filesystem path to the cache directory
  ///
  /// Example:
  /// ```dart
  /// final cachePath = await getApplicationCacheDirectory();
  /// await controller.setStreamingCachePath('${cachePath.path}/streaming');
  /// ```
  Future<void> setStreamingCachePath(String path);

  /// Dispose of this controller
  /// Called automatically when the widget is disposed
  void dispose();

  /// Get the engine type
  GameEngineType get engineType;

  /// Get the engine version (e.g., "2022.3.18" for Unity)
  String get engineVersion;

  /// Stream of messages from the engine
  Stream<GameEngineMessage> get messageStream;

  /// Stream of scene load events
  Stream<GameSceneLoaded> get sceneLoadStream;

  /// Stream of engine lifecycle events
  Stream<GameEngineEvent> get eventStream;
}
