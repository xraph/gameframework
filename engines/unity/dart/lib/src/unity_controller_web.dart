import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:gameframework/gameframework.dart';

/// A queued message waiting to be sent to Unity once ready.
class _QueuedMessage {
  final String target;
  final String method;
  final String data;

  _QueuedMessage(this.target, this.method, this.data);
}

/// Unity WebGL-specific implementation of GameEngineController
///
/// This controller manages Unity WebGL builds running in the browser.
/// It supports:
/// - Bidirectional communication between Flutter and Unity WebGL
/// - Message queuing for messages sent before Unity is ready
/// - Retry logic for failed Unity loads
/// - Loading progress tracking
/// - Lifecycle management (pause/resume/unload/quit)
class UnityControllerWeb implements GameEngineController {
  final String _containerId;
  final GameEngineConfig _config;

  final StreamController<GameEngineMessage> _messageController =
      StreamController<GameEngineMessage>.broadcast();
  final StreamController<GameSceneLoaded> _sceneLoadController =
      StreamController<GameSceneLoaded>.broadcast();
  final StreamController<GameEngineEvent> _eventController =
      StreamController<GameEngineEvent>.broadcast();

  /// Stream controller for loading progress (0.0 to 1.0)
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  bool _isReady = false;
  bool _isPaused = false;
  bool _isLoaded = false;
  bool _disposed = false;

  html.DivElement? _container;
  js.JsObject? _unityInstance;

  /// Message queue for messages sent before Unity is ready.
  /// Max queue size prevents unbounded memory usage.
  final List<_QueuedMessage> _messageQueue = [];
  static const int _maxQueueSize = 100;

  /// Maximum number of retries for Unity load failures.
  static const int _maxRetries = 3;

  /// Base delay between retries in milliseconds (exponential backoff).
  static const int _retryBaseDelayMs = 1000;

  UnityControllerWeb(int viewId, this._config)
      : _containerId = 'unity-container-$viewId' {
    _setupContainer();
    _setupMessageHandler();
    _registerPlatformViewFactory(viewId);
  }

  void _setupContainer() {
    _container = html.DivElement()
      ..id = _containerId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'relative';
  }

  /// Register an HtmlElementView factory so Flutter Web can render the Unity container.
  void _registerPlatformViewFactory(int viewId) {
    // ignore: undefined_prefixed_name, avoid_dynamic_calls
    // ignore: deprecated_member_use
    ui.platformViewRegistry.registerViewFactory(
      'com.xraph.gameframework/unity_$viewId',
      (int id) => _container!,
    );
  }

  void _setupMessageHandler() {
    // Register global message handler that Unity can call
    js.context['FlutterUnityReceiveMessage'] = (
      String target,
      String method,
      String data,
    ) {
      _handleUnityMessage(target, method, data);
    };

    // Register scene load handler
    js.context['FlutterUnitySceneLoaded'] = (
      String name,
      int buildIndex,
    ) {
      _handleSceneLoaded(name, buildIndex);
    };
  }

  void _handleUnityMessage(String target, String method, String data) {
    if (_disposed) return;

    _messageController.add(GameEngineMessage(
      data: data,
      timestamp: DateTime.now(),
      metadata: {
        'target': target,
        'method': method,
      },
    ));
  }

  void _handleSceneLoaded(String name, int buildIndex) {
    if (_disposed) return;

    _sceneLoadController.add(GameSceneLoaded(
      name: name,
      buildIndex: buildIndex,
      isLoaded: true,
      isValid: true,
    ));
  }

  @override
  GameEngineType get engineType => GameEngineType.unity;

  @override
  String get engineVersion => 'WebGL 2022.3.0';

  @override
  Stream<GameEngineMessage> get messageStream => _messageController.stream;

  @override
  Stream<GameSceneLoaded> get sceneLoadStream => _sceneLoadController.stream;

  @override
  Stream<GameEngineEvent> get eventStream => _eventController.stream;

  /// Stream of loading progress values (0.0 to 1.0).
  Stream<double> get progressStream => _progressController.stream;

  @override
  Future<bool> isReady() async => _isReady;

  @override
  Future<bool> isPaused() async => _isPaused;

  @override
  Future<bool> isLoaded() async => _isLoaded;

  @override
  Future<bool> isInBackground() async {
    // Check if browser tab is hidden
    return html.document.hidden ?? false;
  }

  @override
  Future<bool> create() async {
    if (_isReady) return true;

    return _createWithRetry(0);
  }

  /// Attempt to create Unity instance with retry logic and exponential backoff.
  Future<bool> _createWithRetry(int attempt) async {
    try {
      // Get Unity build configuration from config
      final buildUrl = _getConfigValue<String>('buildUrl');
      final loaderUrl = _getConfigValue<String>('loaderUrl');
      final dataUrl = _getConfigValue<String>('dataUrl');
      final frameworkUrl = _getConfigValue<String>('frameworkUrl');
      final codeUrl = _getConfigValue<String>('codeUrl');

      if (buildUrl == null || loaderUrl == null) {
        throw Exception(
            'Unity WebGL requires buildUrl and loaderUrl in config');
      }

      // Emit initial progress
      _emitProgress(0.1);

      // Load Unity loader script
      await _loadScript(loaderUrl);
      _emitProgress(0.2);

      // Build Unity config object
      final config = js.JsObject.jsify({
        'dataUrl': dataUrl ?? '$buildUrl/Build.data',
        'frameworkUrl': frameworkUrl ?? '$buildUrl/Build.framework.js',
        'codeUrl': codeUrl ?? '$buildUrl/Build.wasm',
        'streamingAssetsUrl': '$buildUrl/StreamingAssets',
        'companyName':
            _getConfigValue<String>('companyName') ?? 'DefaultCompany',
        'productName':
            _getConfigValue<String>('productName') ?? 'Unity Game',
        'productVersion':
            _getConfigValue<String>('productVersion') ?? '1.0',
      });

      _emitProgress(0.3);

      // Find createUnityInstance
      final createUnityInstance = js.context['createUnityInstance'];
      if (createUnityInstance == null) {
        throw Exception('Unity loader not found. Check loaderUrl.');
      }

      // Create a progress callback
      final progressCallback = js.allowInterop((double progress) {
        // Unity reports progress from 0 to 1 during loading
        // We map it to 0.3 - 0.9 range (loader already loaded)
        _emitProgress(0.3 + (progress * 0.6));
      });

      // Call createUnityInstance with progress callback
      final instancePromise = createUnityInstance.apply([
        _container,
        config,
        progressCallback,
      ]);

      // Convert JS Promise to Dart Future
      _unityInstance = await _promiseToFuture(instancePromise);

      _isReady = true;
      _isLoaded = true;

      _emitProgress(1.0);

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.created,
        timestamp: DateTime.now(),
      ));

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.loaded,
        timestamp: DateTime.now(),
      ));

      // Flush queued messages now that Unity is ready
      _flushMessageQueue();

      return true;
    } catch (e) {
      if (attempt < _maxRetries) {
        final delay =
            Duration(milliseconds: _retryBaseDelayMs * (1 << attempt));
        debugPrint(
            'Unity WebGL load failed (attempt ${attempt + 1}/$_maxRetries). '
            'Retrying in ${delay.inMilliseconds}ms...');

        _eventController.add(GameEngineEvent(
          type: GameEngineEventType.error,
          timestamp: DateTime.now(),
          message:
              'Unity WebGL load attempt ${attempt + 1} failed: $e. Retrying...',
          error: e,
        ));

        await Future.delayed(delay);
        return _createWithRetry(attempt + 1);
      }

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.error,
        timestamp: DateTime.now(),
        message:
            'Failed to create Unity WebGL after ${_maxRetries + 1} attempts: $e',
        error: e,
      ));
      return false;
    }
  }

  /// Emit a progress value to the progress stream.
  void _emitProgress(double value) {
    if (_disposed) return;
    _progressController.add(value.clamp(0.0, 1.0));
  }

  /// Flush all queued messages to Unity.
  void _flushMessageQueue() {
    if (_messageQueue.isEmpty) return;

    debugPrint(
        'Flushing ${_messageQueue.length} queued messages to Unity WebGL');

    final messages = List<_QueuedMessage>.from(_messageQueue);
    _messageQueue.clear();

    for (final msg in messages) {
      try {
        _unityInstance?.callMethod('SendMessage', [
          msg.target,
          msg.method,
          msg.data,
        ]);
      } catch (e) {
        debugPrint('Failed to flush queued message ${msg.target}.${msg.method}: $e');
      }
    }
  }

  @override
  Future<void> sendMessage(String target, String method, String data) async {
    // If Unity is not ready, queue the message
    if (!_isReady || _unityInstance == null) {
      if (_messageQueue.length >= _maxQueueSize) {
        // Remove oldest message to make room
        _messageQueue.removeAt(0);
        debugPrint(
            'Unity WebGL message queue full ($_maxQueueSize). Dropped oldest message.');
      }
      _messageQueue.add(_QueuedMessage(target, method, data));
      debugPrint(
          'Unity WebGL not ready. Message queued: $target.$method '
          '(${_messageQueue.length}/$_maxQueueSize)');
      return;
    }

    try {
      _unityInstance!.callMethod('SendMessage', [target, method, data]);
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send message to Unity WebGL: $e',
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
    final jsonString =
        js.context['JSON'].callMethod('stringify', [js.JsObject.jsify(data)]);
    await sendMessage(target, method, jsonString.toString());
  }

  @override
  Future<void> pause() async {
    if (!_isReady) return;

    try {
      // Unity WebGL doesn't have direct pause API, so we send a message
      // to the FlutterBridge in Unity which calls NativeAPI.Pause(true)
      await sendMessage('FlutterBridge', 'ReceiveMessage',
          '{"target":"NativeAPI","method":"Pause","data":"true"}');
      _isPaused = true;

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.paused,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to pause Unity WebGL: $e',
        target: 'UnityController',
        method: 'pause',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> resume() async {
    if (!_isReady) return;

    try {
      await sendMessage('FlutterBridge', 'ReceiveMessage',
          '{"target":"NativeAPI","method":"Pause","data":"false"}');
      _isPaused = false;

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.resumed,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to resume Unity WebGL: $e',
        target: 'UnityController',
        method: 'resume',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> unload() async {
    if (!_isReady) return;

    try {
      _unityInstance?.callMethod('Quit');
      _isLoaded = false;
      _isReady = false;
      _messageQueue.clear();

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.unloaded,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to unload Unity WebGL: $e',
        target: 'UnityController',
        method: 'unload',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> quit() async {
    await unload();
    dispose();
  }

  @override
  Future<void> setStreamingCachePath(String path) async {
    // WebGL doesn't support local file system cache paths.
    // Streaming assets are loaded via HTTP from the web server.
    // This is a no-op for web platform.
    return;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _unityInstance?.callMethod('Quit');
    _unityInstance = null;
    _messageQueue.clear();

    _container?.remove();
    _container = null;

    // Clean up global handlers
    js.context.deleteProperty('FlutterUnityReceiveMessage');
    js.context.deleteProperty('FlutterUnitySceneLoaded');

    _messageController.close();
    _sceneLoadController.close();
    _progressController.close();

    // Emit destroyed event before closing the controller
    if (!_eventController.isClosed) {
      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.destroyed,
        timestamp: DateTime.now(),
      ));
      _eventController.close();
    }
  }

  // Helper methods

  T? _getConfigValue<T>(String key) {
    final value = _config.engineSpecificConfig?[key];
    return value is T ? value : null;
  }

  Future<void> _loadScript(String url) async {
    // Check if script is already loaded
    final existingScripts = html.document.head?.querySelectorAll('script');
    if (existingScripts != null) {
      for (final script in existingScripts) {
        if (script is html.ScriptElement && script.src == url) {
          debugPrint('Unity loader script already loaded: $url');
          return;
        }
      }
    }

    final completer = Completer<void>();

    final script = html.ScriptElement()
      ..src = url
      ..type = 'text/javascript';

    script.onLoad.listen((_) {
      completer.complete();
    });

    script.onError.listen((error) {
      completer.completeError(Exception('Failed to load script: $url'));
    });

    html.document.head?.append(script);
    return completer.future;
  }

  Future<js.JsObject> _promiseToFuture(js.JsObject promise) {
    final completer = Completer<js.JsObject>();

    promise.callMethod('then', [
      (result) {
        completer.complete(result as js.JsObject);
      }
    ]);

    promise.callMethod('catch', [
      (error) {
        completer.completeError(error);
      }
    ]);

    return completer.future;
  }

  /// Get the HTML container element for the Unity game.
  html.DivElement? get container => _container;

  /// Get the container ID used for HtmlElementView registration.
  String get containerId => _containerId;

  /// Get the number of queued messages waiting to be sent.
  int get queuedMessageCount => _messageQueue.length;

  /// Set fullscreen mode for the Unity WebGL player.
  Future<void> setFullscreen(bool fullscreen) async {
    if (_unityInstance == null) return;

    try {
      _unityInstance!.callMethod('SetFullscreen', [fullscreen ? 1 : 0]);
    } catch (e) {
      // Fullscreen might not be supported
      debugPrint('Failed to set fullscreen: $e');
    }
  }
}

/// Platform-specific controller creation for web
GameEngineController createUnityController(
    int viewId, GameEngineConfig config) {
  return UnityControllerWeb(viewId, config);
}
