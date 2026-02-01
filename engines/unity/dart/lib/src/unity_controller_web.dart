import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:gameframework/gameframework.dart';

/// Unity WebGL-specific implementation of GameEngineController
///
/// This controller manages Unity WebGL builds running in the browser.
class UnityControllerWeb implements GameEngineController {
  final String _containerId;
  final GameEngineConfig _config;

  final StreamController<GameEngineMessage> _messageController =
      StreamController<GameEngineMessage>.broadcast();
  final StreamController<GameSceneLoaded> _sceneLoadController =
      StreamController<GameSceneLoaded>.broadcast();
  final StreamController<GameEngineEvent> _eventController =
      StreamController<GameEngineEvent>.broadcast();

  bool _isReady = false;
  bool _isPaused = false;
  bool _isLoaded = false;
  bool _disposed = false;

  html.DivElement? _container;
  js.JsObject? _unityInstance;

  UnityControllerWeb(int viewId, this._config)
      : _containerId = 'unity-container-$viewId' {
    _setupContainer();
    _setupMessageHandler();
  }

  void _setupContainer() {
    _container = html.DivElement()
      ..id = _containerId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'relative';
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

      // Load Unity loader script
      await _loadScript(loaderUrl);

      // Create Unity instance
      final config = js.JsObject.jsify({
        'dataUrl': dataUrl ?? '$buildUrl/Build.data',
        'frameworkUrl': frameworkUrl ?? '$buildUrl/Build.framework.js',
        'codeUrl': codeUrl ?? '$buildUrl/Build.wasm',
        'streamingAssetsUrl': '$buildUrl/StreamingAssets',
        'companyName':
            _getConfigValue<String>('companyName') ?? 'DefaultCompany',
        'productName': _getConfigValue<String>('productName') ?? 'Unity Game',
        'productVersion': _getConfigValue<String>('productVersion') ?? '1.0',
      });

      // Create Unity instance
      final createUnityInstance = js.context['createUnityInstance'];
      if (createUnityInstance == null) {
        throw Exception('Unity loader not found. Check loaderUrl.');
      }

      // Call createUnityInstance
      final instancePromise = createUnityInstance.apply([
        _container,
        config,
      ]);

      // Convert JS Promise to Dart Future
      _unityInstance = await _promiseToFuture(instancePromise);

      _isReady = true;
      _isLoaded = true;

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.created,
        timestamp: DateTime.now(),
      ));

      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.loaded,
        timestamp: DateTime.now(),
      ));

      return true;
    } catch (e) {
      _eventController.add(GameEngineEvent(
        type: GameEngineEventType.error,
        timestamp: DateTime.now(),
        message: 'Failed to create Unity WebGL: $e',
        error: e,
      ));
      return false;
    }
  }

  @override
  Future<void> sendMessage(String target, String method, String data) async {
    if (!_isReady || _unityInstance == null) {
      throw EngineNotReadyException(GameEngineType.unity);
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
      // Unity WebGL doesn't have direct pause, but we can send a message
      await sendMessage('GameManager', 'OnPause', '');
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
      // Unity WebGL doesn't have direct resume, but we can send a message
      await sendMessage('GameManager', 'OnResume', '');
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
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _unityInstance?.callMethod('Quit');
    _unityInstance = null;

    _container?.remove();
    _container = null;

    _messageController.close();
    _sceneLoadController.close();
    _eventController.close();

    // Clean up global handlers
    js.context.deleteProperty('FlutterUnityReceiveMessage');
    js.context.deleteProperty('FlutterUnitySceneLoaded');

    _eventController.add(GameEngineEvent(
      type: GameEngineEventType.destroyed,
      timestamp: DateTime.now(),
    ));
  }

  // Helper methods

  T? _getConfigValue<T>(String key) {
    final value = _config.engineSpecificConfig?[key];
    return value is T ? value : null;
  }

  Future<void> _loadScript(String url) async {
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

  /// Get the HTML container element for the Unity game
  html.DivElement? get container => _container;

  /// Set fullscreen mode
  Future<void> setFullscreen(bool fullscreen) async {
    if (_unityInstance == null) return;

    try {
      _unityInstance!.callMethod('SetFullscreen', [fullscreen ? 1 : 0]);
    } catch (e) {
      // Fullscreen might not be supported
      print('Failed to set fullscreen: $e');
    }
  }
}

/// Platform-specific controller creation for web
GameEngineController createUnityController(
    int viewId, GameEngineConfig config) {
  return UnityControllerWeb(viewId, config);
}
