import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'unreal_controller.dart';

/// Message batcher for high-frequency Unreal Engine communication.
///
/// Coalesces multiple messages into single batched transmissions
/// to reduce overhead for high-frequency updates.
///
/// Example:
/// ```dart
/// final batcher = UnrealMessageBatcher(controller);
/// batcher.configure(maxBatchSize: 50, flushIntervalMs: 16);
///
/// // In update loop - messages are batched automatically
/// batcher.queue('Player', 'position', {'x': 1.0, 'y': 2.0});
/// ```
class UnrealMessageBatcher {
  final UnrealController _controller;

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
  int _bytesSent = 0;

  UnrealMessageBatcher(this._controller);

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

  /// Queue with specific coalesce key (for different data with same target/method).
  void queueWithKey(
      String target, String method, dynamic data, String coalesceKey) {
    if (!_enabled) {
      _sendImmediate(target, method, data);
      return;
    }

    if (_enableCoalescing) {
      for (int i = _pendingMessages.length - 1; i >= 0; i--) {
        final existing = _pendingMessages[i];
        if (existing.coalesceKey == coalesceKey) {
          _pendingMessages[i] = _BatchedMessage(
            target: target,
            method: method,
            data: data,
            timestamp: DateTime.now(),
            coalesceKey: coalesceKey,
          );
          _messagesCoalesced++;
          return;
        }
      }
    }

    _pendingMessages.add(_BatchedMessage(
      target: target,
      method: method,
      data: data,
      timestamp: DateTime.now(),
      coalesceKey: coalesceKey,
    ));
    _messagesBatched++;

    if (_pendingMessages.length >= _maxBatchSize) {
      flush();
    }
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
      String jsonString;
      if (data is Map<String, dynamic>) {
        jsonString = jsonEncode(data);
        await _controller.sendJsonMessage(target, method, data);
      } else if (data is String) {
        jsonString = data;
        await _controller.sendMessage(target, method, data);
      } else {
        jsonString = jsonEncode({'value': data});
        await _controller.sendJsonMessage(target, method, {'value': data});
      }
      _bytesSent += jsonString.length;
    } catch (e) {
      debugPrint('UnrealMessageBatcher: Send failed: $e');
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

      final jsonString = jsonEncode(batchData);
      _bytesSent += jsonString.length;

      await _controller.sendJsonMessage('_batch', 'onBatch', batchData);
    } catch (e) {
      debugPrint('UnrealMessageBatcher: Batch send failed: $e');

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
        bytesSent: _bytesSent,
      );

  /// Reset statistics.
  void resetStatistics() {
    _messagesBatched = 0;
    _batchesSent = 0;
    _messagesCoalesced = 0;
    _bytesSent = 0;
  }

  /// Get pending message count.
  int get pendingCount => _pendingMessages.length;

  /// Whether batching is enabled.
  bool get isEnabled => _enabled;

  /// Current batch size limit.
  int get maxBatchSize => _maxBatchSize;

  /// Current flush interval in milliseconds.
  int get flushIntervalMs => _flushIntervalMs;

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
  final String? coalesceKey;

  _BatchedMessage({
    required this.target,
    required this.method,
    required this.data,
    required this.timestamp,
    this.coalesceKey,
  });
}

/// Batching statistics.
class BatcherStatistics {
  final int messagesBatched;
  final int batchesSent;
  final int messagesCoalesced;
  final int pendingCount;
  final int bytesSent;

  BatcherStatistics({
    required this.messagesBatched,
    required this.batchesSent,
    required this.messagesCoalesced,
    required this.pendingCount,
    required this.bytesSent,
  });

  double get averageMessagesPerBatch =>
      batchesSent > 0 ? messagesBatched / batchesSent : 0;

  double get coalescingEfficiency =>
      messagesBatched > 0 ? messagesCoalesced / messagesBatched : 0;

  @override
  String toString() => 'Batched=$messagesBatched, Sent=$batchesSent, '
      'Coalesced=$messagesCoalesced, Pending=$pendingCount, '
      'Bytes=$bytesSent, Avg/Batch=${averageMessagesPerBatch.toStringAsFixed(1)}';
}
