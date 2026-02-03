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

  UnrealController(int viewId)
      : _channel = MethodChannel('gameframework_unreal_$viewId'),
        _eventController = StreamController<GameEngineEvent>.broadcast(),
        _messageController = StreamController<GameEngineMessage>.broadcast(),
        _sceneController = StreamController<GameSceneLoaded>.broadcast(),
        _binaryProgressController =
            StreamController<BinaryTransferProgress>.broadcast() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _chunkAssembler = _binaryProtocol.createAssembler();
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

        // Flush any messages queued before engine was ready
        await _flushPreReadyQueue();
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

  // MARK: - Method Call Handler

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMessage':
        _handleMessage(call.arguments);
        break;
      case 'onBinaryMessage':
        _handleBinaryMessage(call.arguments);
        break;
      case 'onBinaryChunk':
        _handleBinaryChunk(call.arguments);
        break;
      case 'onBinaryProgress':
        _handleBinaryProgress(call.arguments);
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
