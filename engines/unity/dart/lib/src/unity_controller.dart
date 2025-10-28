import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gameframework/gameframework.dart';

/// Unity-specific implementation of GameEngineController
///
/// This controller manages the lifecycle and communication with Unity engine.
class UnityController implements GameEngineController {
  final MethodChannel _channel;
  final EventChannel _eventChannel;

  final StreamController<GameEngineMessage> _messageController =
      StreamController<GameEngineMessage>.broadcast();
  final StreamController<GameSceneLoaded> _sceneLoadController =
      StreamController<GameSceneLoaded>.broadcast();
  final StreamController<GameEngineEvent> _eventController =
      StreamController<GameEngineEvent>.broadcast();

  StreamSubscription? _eventSubscription;
  bool _disposed = false;

  UnityController(int viewId)
      : _channel = MethodChannel('com.xraph.gameframework/engine_$viewId'),
        _eventChannel = EventChannel('com.xraph.gameframework/events_$viewId') {
    _setupEventStream();
  }

  void _setupEventStream() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final eventName = event['event'] as String?;
          final eventData = event['data'];

          switch (eventName) {
            case 'onMessage':
              if (eventData is Map) {
                final message = GameEngineMessage.fromMap(
                    Map<String, dynamic>.from(eventData));
                _messageController.add(message);
              }
              break;

            case 'onSceneLoaded':
              if (eventData is Map) {
                final sceneData = Map<String, dynamic>.from(eventData);
                final sceneLoaded = GameSceneLoaded(
                  name: sceneData['name'] as String? ?? '',
                  buildIndex: sceneData['buildIndex'] as int? ?? -1,
                  isLoaded: sceneData['isLoaded'] as bool? ?? false,
                  isValid: sceneData['isValid'] as bool? ?? false,
                  metadata:
                      sceneData['metadata'] as Map<String, dynamic>? ?? {},
                );
                _sceneLoadController.add(sceneLoaded);
              }
              break;

            case 'onCreated':
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.created,
                timestamp: DateTime.now(),
              ));
              break;

            case 'onLoaded':
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.loaded,
                timestamp: DateTime.now(),
              ));
              break;

            case 'onPaused':
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.paused,
                timestamp: DateTime.now(),
              ));
              break;

            case 'onResumed':
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.resumed,
                timestamp: DateTime.now(),
              ));
              break;

            case 'onUnloaded':
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.unloaded,
                timestamp: DateTime.now(),
              ));
              break;

            case 'onDestroyed':
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.destroyed,
                timestamp: DateTime.now(),
              ));
              break;

            case 'onError':
              final message = eventData is Map
                  ? (eventData['message'] as String? ?? 'Unknown error')
                  : 'Unknown error';
              _eventController.add(GameEngineEvent(
                type: GameEngineEventType.error,
                timestamp: DateTime.now(),
                message: message,
              ));
              break;
          }
        }
      },
      onError: (error) {
        _eventController.add(GameEngineEvent(
          type: GameEngineEventType.error,
          timestamp: DateTime.now(),
          message: 'Event stream error: $error',
        ));
      },
    );
  }

  @override
  GameEngineType get engineType => GameEngineType.unity;

  @override
  String get engineVersion => '2022.3.0'; // This should be dynamic

  @override
  Stream<GameEngineMessage> get messageStream => _messageController.stream;

  @override
  Stream<GameSceneLoaded> get sceneLoadStream => _sceneLoadController.stream;

  @override
  Stream<GameEngineEvent> get eventStream => _eventController.stream;

  @override
  Future<bool> isReady() async {
    try {
      final result = await _channel.invokeMethod<bool>('engine#isReady');
      return result ?? false;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to check if ready: $e',
        target: 'UnityController',
        method: 'isReady',
        engineType: engineType,
      );
    }
  }

  @override
  Future<bool> isPaused() async {
    try {
      final result = await _channel.invokeMethod<bool>('engine#isPaused');
      return result ?? false;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to check if paused: $e',
        target: 'UnityController',
        method: 'isPaused',
        engineType: engineType,
      );
    }
  }

  @override
  Future<bool> isLoaded() async {
    try {
      final result = await _channel.invokeMethod<bool>('engine#isLoaded');
      return result ?? false;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to check if loaded: $e',
        target: 'UnityController',
        method: 'isLoaded',
        engineType: engineType,
      );
    }
  }

  @override
  Future<bool> isInBackground() async {
    try {
      final result = await _channel.invokeMethod<bool>('engine#isInBackground');
      return result ?? false;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to check if in background: $e',
        target: 'UnityController',
        method: 'isInBackground',
        engineType: engineType,
      );
    }
  }

  @override
  Future<bool> create() async {
    try {
      final result = await _channel.invokeMethod<bool>('engine#create');
      return result ?? false;
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to create engine: $e',
        target: 'UnityController',
        method: 'create',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> sendMessage(String target, String method, String data) async {
    try {
      await _channel.invokeMethod('engine#sendMessage', {
        'target': target,
        'method': method,
        'data': data,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send message: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> sendJsonMessage(
      String target, String method, Map<String, dynamic> data) async {
    try {
      await _channel.invokeMethod('engine#sendMessage', {
        'target': target,
        'method': method,
        'data': data.toString(),
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send JSON message: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _channel.invokeMethod('engine#pause');
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to pause engine: $e',
        target: 'UnityController',
        method: 'pause',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _channel.invokeMethod('engine#resume');
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to resume engine: $e',
        target: 'UnityController',
        method: 'resume',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> unload() async {
    try {
      await _channel.invokeMethod('engine#unload');
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to unload engine: $e',
        target: 'UnityController',
        method: 'unload',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> quit() async {
    try {
      await _channel.invokeMethod('engine#quit');
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to quit engine: $e',
        target: 'UnityController',
        method: 'quit',
        engineType: engineType,
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _eventSubscription?.cancel();
    _messageController.close();
    _sceneLoadController.close();
    _eventController.close();
  }
}
