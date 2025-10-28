import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gameframework/gameframework.dart';
import 'unreal_quality_settings.dart';

/// Unreal Engine-specific implementation of GameEngineController
///
/// Provides control over an Unreal Engine instance running within a Flutter app.
/// Supports bidirectional communication, lifecycle management, quality settings,
/// and console command execution.
class UnrealController implements GameEngineController {
  final MethodChannel _channel;
  final StreamController<GameEngineEvent> _eventController;
  final StreamController<GameEngineMessage> _messageController;
  final StreamController<GameSceneLoaded> _sceneController;

  bool _isReady = false;
  bool _isPaused = false;
  bool _isDisposed = false;

  UnrealController(int viewId)
      : _channel = MethodChannel('gameframework_unreal_$viewId'),
        _eventController = StreamController<GameEngineEvent>.broadcast(),
        _messageController = StreamController<GameEngineMessage>.broadcast(),
        _sceneController = StreamController<GameSceneLoaded>.broadcast() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  GameEngineType get engineType => GameEngineType.unreal;

  @override
  String get engineVersion => '5.3.0';

  @override
  Future<bool> isReady() async => _isReady;

  @override
  Future<bool> isPaused() async => _isPaused;

  @override
  Future<bool> isLoaded() async => _isReady;

  @override
  Stream<GameEngineEvent> get eventStream => _eventController.stream;

  @override
  Stream<GameEngineMessage> get messageStream => _messageController.stream;

  @override
  Stream<GameSceneLoaded> get sceneLoadStream => _sceneController.stream;

  // MARK: - Lifecycle Methods

  @override
  Future<bool> create() async {
    _throwIfDisposed();

    try {
      final result = await _channel.invokeMethod<bool>('engine#create');
      _isReady = result ?? false;

      if (_isReady) {
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.created,
          timestamp: DateTime.now(),
        ));
      }

      return _isReady;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to create Unreal engine: $e',
        target: 'UnrealController',
        method: 'create',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> pause() async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#pause');
      _isPaused = true;

      _addEvent(GameEngineEvent(
        type: GameEngineEventType.paused,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to pause Unreal engine: $e',
        target: 'UnrealController',
        method: 'pause',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> resume() async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#resume');
      _isPaused = false;

      _addEvent(GameEngineEvent(
        type: GameEngineEventType.resumed,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to resume Unreal engine: $e',
        target: 'UnrealController',
        method: 'resume',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> unload() async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#unload');

      _addEvent(GameEngineEvent(
        type: GameEngineEventType.unloaded,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to unload Unreal engine: $e',
        target: 'UnrealController',
        method: 'unload',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> quit() async {
    _throwIfDisposed();

    try {
      await _channel.invokeMethod('engine#quit');
      _isReady = false;

      _addEvent(GameEngineEvent(
        type: GameEngineEventType.destroyed,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to quit Unreal engine: $e',
        target: 'UnrealController',
        method: 'quit',
        engineType: engineType,
      );
    }
  }

  // MARK: - Communication Methods

  @override
  Future<void> sendMessage(String target, String method, String data) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#sendMessage', {
        'target': target,
        'method': method,
        'data': data,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send message to Unreal: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> sendJsonMessage(
    String target,
    String method,
    Map<String, dynamic> data,
  ) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#sendJsonMessage', {
        'target': target,
        'method': method,
        'data': data,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send JSON message to Unreal: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  // MARK: - Unreal-Specific Methods

  /// Execute a console command in Unreal Engine
  ///
  /// Example: `executeConsoleCommand('stat fps')`
  Future<void> executeConsoleCommand(String command) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#executeConsoleCommand', {
        'command': command,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to execute console command: $e',
        target: 'UnrealController',
        method: 'executeConsoleCommand',
        engineType: engineType,
      );
    }
  }

  /// Load a level/map in Unreal Engine
  ///
  /// Example: `loadLevel('MainMenu')`
  Future<void> loadLevel(String levelName) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#loadLevel', {
        'levelName': levelName,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to load level: $e',
        target: 'UnrealController',
        method: 'loadLevel',
        engineType: engineType,
      );
    }
  }

  /// Apply quality settings to Unreal Engine
  Future<void> applyQualitySettings(UnrealQualitySettings settings) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      await _channel.invokeMethod('engine#applyQualitySettings', settings.toMap());
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to apply quality settings: $e',
        target: 'UnrealController',
        method: 'applyQualitySettings',
        engineType: engineType,
      );
    }
  }

  /// Get current quality settings from Unreal Engine
  Future<UnrealQualitySettings> getQualitySettings() async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      final result = await _channel.invokeMethod<Map>('engine#getQualitySettings');
      if (result == null) {
        throw EngineCommunicationException(
          'Failed to get quality settings: null result',
          target: 'UnrealController',
          method: 'getQualitySettings',
          engineType: engineType,
        );
      }

      return UnrealQualitySettings.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to get quality settings: $e',
        target: 'UnrealController',
        method: 'getQualitySettings',
        engineType: engineType,
      );
    }
  }

  /// Check if engine is in background (mobile platforms)
  @override
  Future<bool> isInBackground() async {
    _throwIfDisposed();

    try {
      final result = await _channel.invokeMethod<bool>('engine#isInBackground');
      return result ?? false;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to check if in background: $e',
        target: 'UnrealController',
        method: 'isInBackground',
        engineType: engineType,
      );
    }
  }

  // MARK: - Method Call Handler

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMessage':
        _handleMessage(call.arguments);
        break;
      case 'onLevelLoaded':
        _handleLevelLoaded(call.arguments);
        break;
      case 'onEvent':
        _handleEvent(call.arguments);
        break;
      default:
        debugPrint('UnrealController: Unknown method call: ${call.method}');
    }
  }

  void _handleMessage(dynamic arguments) {
    if (arguments is Map) {
      final message = GameEngineMessage(
        data: arguments['data'] as String? ?? '',
        timestamp: DateTime.now(),
        metadata: {
          'target': arguments['target'],
          'method': arguments['method'],
        },
      );

      _messageController.add(message);
    }
  }

  void _handleLevelLoaded(dynamic arguments) {
    if (arguments is Map) {
      final scene = GameSceneLoaded(
        name: arguments['name'] as String? ?? '',
        buildIndex: arguments['buildIndex'] as int? ?? -1,
        isLoaded: arguments['isLoaded'] as bool? ?? true,
        isValid: arguments['isValid'] as bool? ?? true,
        metadata: Map<String, dynamic>.from(arguments['metadata'] ?? {}),
      );

      _sceneController.add(scene);
    }
  }

  void _handleEvent(dynamic arguments) {
    if (arguments is Map) {
      final type = _parseEventType(arguments['type'] as String?);

      final event = GameEngineEvent(
        type: type,
        timestamp: DateTime.now(),
        message: arguments['message'] as String?,
        error: arguments['error'],
      );

      _addEvent(event);
    }
  }

  GameEngineEventType _parseEventType(String? typeString) {
    switch (typeString) {
      case 'created':
        return GameEngineEventType.created;
      case 'loaded':
        return GameEngineEventType.loaded;
      case 'paused':
        return GameEngineEventType.paused;
      case 'resumed':
        return GameEngineEventType.resumed;
      case 'unloaded':
        return GameEngineEventType.unloaded;
      case 'destroyed':
        return GameEngineEventType.destroyed;
      case 'error':
        return GameEngineEventType.error;
      default:
        return GameEngineEventType.error;
    }
  }

  void _addEvent(GameEngineEvent event) {
    if (!_isDisposed) {
      _eventController.add(event);
    }
  }

  // MARK: - Helper Methods

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw EngineNotReadyException(engineType);
    }
  }

  void _throwIfNotReady() {
    if (!_isReady) {
      throw EngineNotReadyException(engineType);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await _eventController.close();
    await _messageController.close();
    await _sceneController.close();

    try {
      await quit();
    } catch (e) {
      debugPrint('UnrealController: Error during dispose: $e');
    }
  }
}
