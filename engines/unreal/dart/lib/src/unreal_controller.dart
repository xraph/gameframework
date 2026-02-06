import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gameframework/gameframework.dart';
import 'unreal_quality_settings.dart';
import 'unreal_binary_protocol.dart';

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
  final StreamController<BinaryTransferProgress> _binaryProgressController;

  /// Binary protocol handler for encoding/compression/chunking
  final UnrealBinaryProtocol _binaryProtocol = UnrealBinaryProtocol();

  /// Chunk assembler for receiving chunked binary data
  late final ChunkAssembler _chunkAssembler;

  /// Pre-ready message queue for messages sent before engine is ready
  final List<_QueuedMessage> _preReadyQueue = [];

  /// Maximum queue size for pre-ready messages
  static const int _maxPreReadyQueueSize = 100;

  bool _isReady = false;
  bool _isPaused = false;
  bool _isDisposed = false;

  final EventChannel _eventChannel;
  StreamSubscription? _eventSubscription;
  bool _eventStreamSetup = false;

  UnrealController(int viewId)
      : _channel = MethodChannel('com.xraph.gameframework/engine_$viewId'),
        _eventChannel = EventChannel('com.xraph.gameframework/events_$viewId'),
        _eventController = StreamController<GameEngineEvent>.broadcast(),
        _messageController = StreamController<GameEngineMessage>.broadcast(),
        _sceneController = StreamController<GameSceneLoaded>.broadcast(),
        _binaryProgressController =
            StreamController<BinaryTransferProgress>.broadcast() {
    _chunkAssembler = _binaryProtocol.createAssembler();
    // Defer event stream setup to ensure platform view is created
    scheduleMicrotask(_setupEventStream);
  }

  /// Set up event stream with explicit native confirmation
  Future<void> _setupEventStream(
      {int attempt = 0, int maxAttempts = 10}) async {
    if (_isDisposed || _eventStreamSetup) return;

    try {
      // On first attempt, add a small delay to give iOS time to fully set up
      // the platform view and method channel handler
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Request native side to register event handler
      final setupResult = await _channel.invokeMethod<bool>('events#setup');

      if (setupResult != true) {
        throw Exception('Native event setup returned false or null');
      }

      _eventStreamSetup = true;

      // Native handler is now guaranteed to be registered
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleNativeEvent,
        onError: (error) {
          debugPrint('UnrealController: Event stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (attempt < maxAttempts && !_isDisposed) {
        final delay = Duration(milliseconds: 100 * (attempt + 1));
        debugPrint(
            'UnrealController: Event setup failed, retrying in ${delay.inMilliseconds}ms (attempt ${attempt + 1}/$maxAttempts)');
        await Future.delayed(delay);
        await _setupEventStream(attempt: attempt + 1, maxAttempts: maxAttempts);
      } else {
        debugPrint(
            'UnrealController: Failed to setup event stream after $maxAttempts attempts: $e');
      }
    }
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;

    final eventName = event['event'] as String?;
    final data = event['data'];

    switch (eventName) {
      case 'onMessage':
        _handleMessage(data);
        break;
      case 'onBinaryMessage':
        _handleBinaryMessage(data);
        break;
      case 'onBinaryChunk':
        _handleBinaryChunk(data);
        break;
      case 'onBinaryProgress':
        _handleBinaryProgress(data);
        break;
      case 'onSceneLoaded':
        _handleLevelLoaded(data);
        break;
      case 'onCreated':
        _isReady = true;
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.created,
          timestamp: DateTime.now(),
        ));
        break;
      case 'onLoaded':
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.loaded,
          timestamp: DateTime.now(),
        ));
        break;
      case 'onPaused':
        _isPaused = true;
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.paused,
          timestamp: DateTime.now(),
        ));
        break;
      case 'onResumed':
        _isPaused = false;
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.resumed,
          timestamp: DateTime.now(),
        ));
        break;
      case 'onUnloaded':
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.unloaded,
          timestamp: DateTime.now(),
        ));
        break;
      case 'onDestroyed':
        _isReady = false;
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.destroyed,
          timestamp: DateTime.now(),
        ));
        break;
      case 'onError':
        final message =
            data is Map ? data['message'] as String? : data?.toString();
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.error,
          timestamp: DateTime.now(),
          message: message,
          error: message,
        ));
        break;
      default:
        debugPrint('UnrealController: Unknown event: $eventName');
    }
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

  /// Stream of binary transfer progress events
  Stream<BinaryTransferProgress> get binaryProgressStream =>
      _binaryProgressController.stream;

  /// Access to binary protocol for advanced usage
  UnrealBinaryProtocol get binaryProtocol => _binaryProtocol;

  // MARK: - Lifecycle Methods

  @override
  Future<bool> create({int attempt = 0, int maxAttempts = 10}) async {
    _throwIfDisposed();

    try {
      final result = await _channel.invokeMethod<bool>('engine#create');
      _isReady = result ?? false;

      if (_isReady) {
        _addEvent(GameEngineEvent(
          type: GameEngineEventType.created,
          timestamp: DateTime.now(),
        ));

        // Flush any messages queued before engine was ready
        await _flushPreReadyQueue();
      }

      return _isReady;
    } catch (e) {
      // Handle MissingPluginException - platform view not created yet
      if (e is MissingPluginException && attempt < maxAttempts) {
        // Exponential backoff: 50ms, 100ms, 200ms, 400ms, 800ms...
        final delayMs = 50 * (1 << attempt);
        if (attempt == 0) {
          // First attempt failure is expected, don't log
        } else if (attempt < 3) {
          debugPrint(
              'Platform view not ready for create(), retrying in ${delayMs}ms (attempt ${attempt + 1}/$maxAttempts)');
        } else {
          debugPrint(
              'Warning: Platform view still not ready for create() after $attempt attempts, retrying in ${delayMs}ms');
        }

        await Future.delayed(Duration(milliseconds: delayMs));
        return create(attempt: attempt + 1, maxAttempts: maxAttempts);
      }

      // Fatal error or max retries exceeded
      throw EngineCommunicationException(
        attempt >= maxAttempts
            ? 'Platform view creation timeout after $maxAttempts attempts'
            : 'Failed to create Unreal engine: $e',
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

  // MARK: - Binary Messaging

  /// Send binary data to Unreal Engine.
  ///
  /// Binary data is encoded to base64 for transmission. For large data (>1KB),
  /// compression is automatically applied unless disabled.
  ///
  /// Example:
  /// ```dart
  /// final imageBytes = await file.readAsBytes();
  /// await controller.sendBinaryMessage('AssetLoader', 'loadTexture', imageBytes);
  /// ```
  Future<void> sendBinaryMessage(
    String target,
    String method,
    Uint8List data, {
    bool compress = true,
  }) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      // Check if chunking is needed
      if (data.length > UnrealBinaryProtocol.maxSingleMessageSize) {
        await _sendChunkedBinary(target, method, data);
        return;
      }

      // Encode with optional compression
      final envelope = _binaryProtocol.encodeWithMetadata(
        data,
        compress: compress,
      );

      await _channel.invokeMethod('engine#sendBinaryMessage', {
        'target': target,
        'method': method,
        'data': envelope.data,
        'originalSize': envelope.originalSize,
        'compressedSize': envelope.compressedSize,
        'isCompressed': envelope.isCompressed,
        'checksum': envelope.checksum,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send binary message to Unreal: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  /// Send compressed data to Unreal Engine.
  ///
  /// Forces compression regardless of data size.
  Future<void> sendCompressedMessage(
    String target,
    String method,
    String data,
  ) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      final bytes = Uint8List.fromList(data.codeUnits);
      final compressed = _binaryProtocol.compressData(bytes);
      final encoded = _binaryProtocol.encode(compressed);

      await _channel.invokeMethod('engine#sendCompressedMessage', {
        'target': target,
        'method': method,
        'data': encoded,
        'originalSize': bytes.length,
        'compressedSize': compressed.length,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send compressed message to Unreal: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  /// Send large binary data using chunked transfer.
  ///
  /// Automatically splits data into chunks and reports progress.
  Future<void> sendChunkedBinaryMessage(
    String target,
    String method,
    Uint8List data, {
    void Function(double progress)? onProgress,
  }) async {
    _throwIfDisposed();
    _throwIfNotReady();

    await _sendChunkedBinary(target, method, data, onProgress: onProgress);
  }

  Future<void> _sendChunkedBinary(
    String target,
    String method,
    Uint8List data, {
    void Function(double progress)? onProgress,
  }) async {
    int chunkIndex = 0;

    try {
      await for (final chunk in _binaryProtocol.createChunks(
        data,
        onProgress: onProgress,
      )) {
        await _channel.invokeMethod('engine#sendBinaryChunk', {
          'target': target,
          'method': method,
          ...chunk.toMap(),
        });

        // Emit progress event
        if (chunk.type == BinaryChunkType.data) {
          _binaryProgressController.add(BinaryTransferProgress(
            transferId: chunk.transferId,
            currentChunk: chunk.chunkIndex! + 1,
            totalChunks: chunk.totalChunks!,
            bytesTransferred:
                (chunk.chunkIndex! + 1) * _binaryProtocol.chunkSize,
            totalBytes: data.length,
            direction: BinaryTransferDirection.sending,
          ));
          chunkIndex = chunk.chunkIndex!;
        }
      }
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send chunked binary to Unreal: $e (chunk $chunkIndex)',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  /// Send a typed message with automatic JSON serialization.
  Future<void> sendTypedMessage<T>(
    String target,
    String method,
    T data,
  ) async {
    _throwIfDisposed();
    _throwIfNotReady();

    try {
      final jsonData = data is Map || data is List
          ? jsonEncode(data)
          : jsonEncode({'value': data});

      await _channel.invokeMethod('engine#sendMessage', {
        'target': target,
        'method': method,
        'data': jsonData,
        'dataType': 'json',
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to send typed message to Unreal: $e',
        target: target,
        method: method,
        engineType: engineType,
      );
    }
  }

  /// Queue a message to be sent when the engine is ready.
  ///
  /// If the engine is already ready, the message is sent immediately.
  Future<void> queueMessage(String target, String method, String data) async {
    _throwIfDisposed();

    if (_isReady) {
      await sendMessage(target, method, data);
      return;
    }

    if (_preReadyQueue.length >= _maxPreReadyQueueSize) {
      debugPrint(
          'UnrealController: Pre-ready queue full, dropping oldest message');
      _preReadyQueue.removeAt(0);
    }

    _preReadyQueue.add(_QueuedMessage(
      target: target,
      method: method,
      data: data,
      isJson: false,
    ));
  }

  /// Queue a JSON message to be sent when the engine is ready.
  Future<void> queueJsonMessage(
    String target,
    String method,
    Map<String, dynamic> data,
  ) async {
    _throwIfDisposed();

    if (_isReady) {
      await sendJsonMessage(target, method, data);
      return;
    }

    if (_preReadyQueue.length >= _maxPreReadyQueueSize) {
      debugPrint(
          'UnrealController: Pre-ready queue full, dropping oldest message');
      _preReadyQueue.removeAt(0);
    }

    _preReadyQueue.add(_QueuedMessage(
      target: target,
      method: method,
      data: data,
      isJson: true,
    ));
  }

  /// Flush all queued pre-ready messages.
  Future<void> _flushPreReadyQueue() async {
    if (_preReadyQueue.isEmpty) return;

    final queue = List<_QueuedMessage>.from(_preReadyQueue);
    _preReadyQueue.clear();

    for (final msg in queue) {
      try {
        if (msg.isJson) {
          await sendJsonMessage(
            msg.target,
            msg.method,
            msg.data as Map<String, dynamic>,
          );
        } else {
          await sendMessage(msg.target, msg.method, msg.data as String);
        }
      } catch (e) {
        debugPrint('UnrealController: Failed to flush queued message: $e');
      }
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
      await _channel.invokeMethod(
          'engine#applyQualitySettings', settings.toMap());
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
      final result =
          await _channel.invokeMethod<Map>('engine#getQualitySettings');
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

  // MARK: - Event Handlers

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

  void _handleBinaryMessage(dynamic arguments) {
    if (arguments is Map) {
      try {
        final data = arguments['data'] as String;
        final isCompressed = arguments['isCompressed'] as bool? ?? false;
        final checksum = arguments['checksum'] as int?;

        Uint8List decoded = _binaryProtocol.decode(data);

        // Decompress if needed
        if (isCompressed) {
          decoded = _binaryProtocol.decompressData(decoded);
        }

        // Verify checksum if provided
        if (checksum != null &&
            !_binaryProtocol.verifyChecksum(decoded, checksum)) {
          debugPrint('UnrealController: Binary message checksum mismatch');
        }

        // Emit as message with binary metadata
        final message = GameEngineMessage(
          data: base64Encode(decoded),
          timestamp: DateTime.now(),
          metadata: {
            'target': arguments['target'],
            'method': arguments['method'],
            'isBinary': true,
            'originalSize': decoded.length,
          },
        );

        _messageController.add(message);
      } catch (e) {
        debugPrint('UnrealController: Failed to handle binary message: $e');
      }
    }
  }

  void _handleBinaryChunk(dynamic arguments) {
    if (arguments is Map) {
      try {
        final chunk = BinaryChunk.fromMap(Map<String, dynamic>.from(arguments));
        final result = _chunkAssembler.processChunk(chunk);

        if (result != null) {
          // Transfer complete, emit message
          final message = GameEngineMessage(
            data: base64Encode(result),
            timestamp: DateTime.now(),
            metadata: {
              'target': arguments['target'],
              'method': arguments['method'],
              'isBinary': true,
              'isChunked': true,
              'originalSize': result.length,
            },
          );

          _messageController.add(message);
        }
      } catch (e) {
        debugPrint('UnrealController: Failed to handle binary chunk: $e');
      }
    }
  }

  void _handleBinaryProgress(dynamic arguments) {
    if (arguments is Map) {
      final progress = BinaryTransferProgress(
        transferId: arguments['transferId'] as String? ?? '',
        currentChunk: arguments['currentChunk'] as int? ?? 0,
        totalChunks: arguments['totalChunks'] as int? ?? 0,
        bytesTransferred: arguments['bytesTransferred'] as int? ?? 0,
        totalBytes: arguments['totalBytes'] as int? ?? 0,
        direction: BinaryTransferDirection.receiving,
      );

      _binaryProgressController.add(progress);
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
  Future<void> setStreamingCachePath(String path) async {
    _throwIfDisposed();

    try {
      await _channel.invokeMethod('engine#setStreamingCachePath', {
        'path': path,
      });
    } catch (e) {
      throw EngineCommunicationException(
        'Failed to set streaming cache path: $e',
        target: 'UnrealController',
        method: 'setStreamingCachePath',
        engineType: engineType,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancel event subscription first
    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await _eventController.close();
    await _messageController.close();
    await _sceneController.close();
    await _binaryProgressController.close();

    // Clean up chunk assembler
    _chunkAssembler.cancelAll();

    // Clear pre-ready queue
    _preReadyQueue.clear();

    try {
      await quit();
    } catch (e) {
      debugPrint('UnrealController: Error during dispose: $e');
    }
  }
}

/// Internal class for queued messages
class _QueuedMessage {
  final String target;
  final String method;
  final dynamic data;
  final bool isJson;

  _QueuedMessage({
    required this.target,
    required this.method,
    required this.data,
    required this.isJson,
  });
}
