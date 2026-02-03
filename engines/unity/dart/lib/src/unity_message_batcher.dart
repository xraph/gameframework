import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'unity_controller.dart';

/// Message batcher for high-frequency Unity communication.
///
/// Coalesces multiple messages into single batched transmissions
/// to reduce overhead for high-frequency updates.
///
/// Example:
/// ```dart
/// final batcher = UnityMessageBatcher(controller);
/// batcher.configure(maxBatchSize: 50, flushIntervalMs: 16);
///
/// // In update loop - messages are batched automatically
/// batcher.queue('Player', 'position', {'x': 1.0, 'y': 2.0});
/// ```
class UnityMessageBatcher {
  final UnityController _controller;

  final List<_BatchedMessage> _pendingMessages = [];
  Timer? _flushTimer;

  // Configuration
  int _maxBatchSize = 50;
  int _flushIntervalMs = 16; // ~60fps
  bool _enabled = true;
  bool _enableCoalescing = true;

  // Statistics
  int _messagesBatched = 0;
  int _batchesSent = 0;
  int _messagesCoalesced = 0;

  UnityMessageBatcher(this._controller);

  /// Configure batching parameters.
  void configure({
    int? maxBatchSize,
    int? flushIntervalMs,
    bool? enabled,
    bool? enableCoalescing,
  }) {
    if (maxBatchSize != null) _maxBatchSize = maxBatchSize;
    if (flushIntervalMs != null) _flushIntervalMs = flushIntervalMs;
    if (enabled != null) _enabled = enabled;
    if (enableCoalescing != null) _enableCoalescing = enableCoalescing;

    // Restart timer with new interval
    _startTimer();
  }

  /// Queue a message for batched sending.
  void queue(String target, String method, dynamic data) {
    if (!_enabled) {
      // Send immediately if batching disabled
      _sendImmediate(target, method, data);
      return;
    }

    // Check for coalescing opportunity
    if (_enableCoalescing) {
      for (int i = _pendingMessages.length - 1; i >= 0; i--) {
        final existing = _pendingMessages[i];
        if (existing.target == target && existing.method == method) {
          // Coalesce: replace with newer value
          _pendingMessages[i] = _BatchedMessage(
            target: target,
            method: method,
            data: data,
            timestamp: DateTime.now(),
          );
          _messagesCoalesced++;
          return;
        }
      }
    }

    // Add new message
    _pendingMessages.add(_BatchedMessage(
      target: target,
      method: method,
      data: data,
      timestamp: DateTime.now(),
    ));
    _messagesBatched++;

    // Check if batch is full
    if (_pendingMessages.length >= _maxBatchSize) {
      flush();
    }
  }

  /// Queue a binary message for batched sending.
  void queueBinary(String target, String method, List<int> data) {
    final base64Data = base64Encode(data);
    queue(target, method, {'_binary': base64Data});
  }

  /// Immediately flush all pending messages.
  Future<void> flush() async {
    if (_pendingMessages.isEmpty) return;

    final messages = List<_BatchedMessage>.from(_pendingMessages);
    _pendingMessages.clear();

    if (messages.length == 1) {
      // Single message - send directly
      final msg = messages.first;
      await _sendImmediate(msg.target, msg.method, msg.data);
    } else {
      // Multiple messages - send as batch
      await _sendBatch(messages);
    }

    _batchesSent++;
  }

  Future<void> _sendImmediate(
      String target, String method, dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        await _controller.sendJsonMessage(target, method, data);
      } else if (data is String) {
        await _controller.sendMessage(target, method, data);
      } else {
        await _controller.sendJsonMessage(target, method, {'value': data});
      }
    } catch (e) {
      debugPrint('UnityMessageBatcher: Send failed: $e');
    }
  }

  Future<void> _sendBatch(List<_BatchedMessage> messages) async {
    try {
      final batchData = {
        'batch': true,
        'count': messages.length,
        'messages': messages
            .map((m) => {
                  't': m.target,
                  'm': m.method,
                  'd': m.data is String ? m.data : jsonEncode(m.data),
                  'dt': m.data is String ? 's' : 'j',
                })
            .toList(),
      };

      await _controller.sendJsonMessage('_batch', 'onBatch', batchData);
    } catch (e) {
      debugPrint('UnityMessageBatcher: Batch send failed: $e');

      // Fallback: send individually
      for (final msg in messages) {
        await _sendImmediate(msg.target, msg.method, msg.data);
      }
    }
  }

  void _startTimer() {
    _flushTimer?.cancel();
    if (_enabled && _flushIntervalMs > 0) {
      _flushTimer = Timer.periodic(
        Duration(milliseconds: _flushIntervalMs),
        (_) => flush(),
      );
    }
  }

  /// Get batching statistics.
  BatcherStatistics get statistics => BatcherStatistics(
        messagesBatched: _messagesBatched,
        batchesSent: _batchesSent,
        messagesCoalesced: _messagesCoalesced,
        pendingCount: _pendingMessages.length,
      );

  /// Reset statistics.
  void resetStatistics() {
    _messagesBatched = 0;
    _batchesSent = 0;
    _messagesCoalesced = 0;
  }

  /// Dispose the batcher and cancel any pending operations.
  void dispose() {
    _flushTimer?.cancel();
    _pendingMessages.clear();
  }
}

class _BatchedMessage {
  final String target;
  final String method;
  final dynamic data;
  final DateTime timestamp;

  _BatchedMessage({
    required this.target,
    required this.method,
    required this.data,
    required this.timestamp,
  });
}

/// Batching statistics.
class BatcherStatistics {
  final int messagesBatched;
  final int batchesSent;
  final int messagesCoalesced;
  final int pendingCount;

  BatcherStatistics({
    required this.messagesBatched,
    required this.batchesSent,
    required this.messagesCoalesced,
    required this.pendingCount,
  });

  double get averageMessagesPerBatch =>
      batchesSent > 0 ? messagesBatched / batchesSent : 0;

  @override
  String toString() => 'Batched=$messagesBatched, Sent=$batchesSent, '
      'Coalesced=$messagesCoalesced, Pending=$pendingCount, '
      'Avg/Batch=${averageMessagesPerBatch.toStringAsFixed(1)}';
}

/// Message throttler for rate-limited communication.
///
/// Limits the rate of messages sent to Unity to prevent overwhelming
/// the communication channel.
///
/// Example:
/// ```dart
/// final throttler = UnityMessageThrottler(controller);
///
/// // Configure rate limit (60 messages per second)
/// throttler.setRate('Player:position', 60);
///
/// // Send throttled messages
/// throttler.send('Player', 'position', data); // Rate limited
/// ```
class UnityMessageThrottler {
  final UnityController _controller;

  final Map<String, _ThrottleConfig> _configs = {};
  final Map<String, DateTime> _lastSendTimes = {};
  final Map<String, dynamic> _pendingValues = {};

  UnityMessageThrottler(this._controller);

  /// Set rate limit for a target:method combination.
  void setRate(
    String key,
    int messagesPerSecond, {
    ThrottleStrategy strategy = ThrottleStrategy.keepLatest,
  }) {
    _configs[key] = _ThrottleConfig(
      rateHz: messagesPerSecond,
      strategy: strategy,
      intervalMs: messagesPerSecond > 0 ? 1000 ~/ messagesPerSecond : 0,
    );
  }

  /// Send a message with throttling.
  Future<void> send(String target, String method, dynamic data) async {
    final key = '$target:$method';
    final config = _configs[key];

    if (config == null || config.rateHz <= 0) {
      // No throttle configured - send immediately
      await _sendImmediate(target, method, data);
      return;
    }

    final now = DateTime.now();
    final lastSend = _lastSendTimes[key];

    if (lastSend == null ||
        now.difference(lastSend).inMilliseconds >= config.intervalMs) {
      // Allowed to send
      _lastSendTimes[key] = now;
      _pendingValues.remove(key);
      await _sendImmediate(target, method, data);
    } else {
      // Throttled - apply strategy
      switch (config.strategy) {
        case ThrottleStrategy.drop:
          // Drop the message
          break;
        case ThrottleStrategy.keepLatest:
          // Store for later
          _pendingValues[key] = _PendingMessage(target, method, data);
          break;
        case ThrottleStrategy.keepFirst:
          // Only store if not already pending
          _pendingValues.putIfAbsent(
              key, () => _PendingMessage(target, method, data));
          break;
      }
    }
  }

  /// Flush any pending throttled messages.
  Future<void> flush() async {
    final pending = Map<String, _PendingMessage>.from(
      _pendingValues.map((k, v) => MapEntry(k, v as _PendingMessage)),
    );
    _pendingValues.clear();

    for (final msg in pending.values) {
      await _sendImmediate(msg.target, msg.method, msg.data);
    }
  }

  Future<void> _sendImmediate(
      String target, String method, dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        await _controller.sendJsonMessage(target, method, data);
      } else if (data is String) {
        await _controller.sendMessage(target, method, data);
      } else {
        await _controller.sendJsonMessage(target, method, {'value': data});
      }
    } catch (e) {
      debugPrint('UnityMessageThrottler: Send failed: $e');
    }
  }
}

class _ThrottleConfig {
  final int rateHz;
  final ThrottleStrategy strategy;
  final int intervalMs;

  _ThrottleConfig({
    required this.rateHz,
    required this.strategy,
    required this.intervalMs,
  });
}

class _PendingMessage {
  final String target;
  final String method;
  final dynamic data;

  _PendingMessage(this.target, this.method, this.data);
}

/// Strategy for handling throttled messages.
enum ThrottleStrategy {
  /// Drop excess messages entirely
  drop,

  /// Keep only the latest value (replace pending)
  keepLatest,

  /// Keep only the first value (ignore subsequent)
  keepFirst,
}

/// Extension methods for UnityController with performance utilities.
extension UnityControllerPerformance on UnityController {
  /// Create a message batcher for this controller.
  UnityMessageBatcher createBatcher({
    int maxBatchSize = 50,
    int flushIntervalMs = 16,
  }) {
    final batcher = UnityMessageBatcher(this);
    batcher.configure(
      maxBatchSize: maxBatchSize,
      flushIntervalMs: flushIntervalMs,
    );
    return batcher;
  }

  /// Create a message throttler for this controller.
  UnityMessageThrottler createThrottler() {
    return UnityMessageThrottler(this);
  }
}
