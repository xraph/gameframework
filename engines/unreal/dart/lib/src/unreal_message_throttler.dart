import 'dart:async';
import 'package:flutter/foundation.dart';
import 'unreal_controller.dart';
import 'unreal_message_batcher.dart';

// Re-export batcher for convenience when using throttler
export 'unreal_message_batcher.dart'
    show UnrealMessageBatcher, BatcherStatistics;

/// Message throttler for rate-limited Unreal Engine communication.
///
/// Limits the rate of messages sent to Unreal to prevent overwhelming
/// the communication channel.
///
/// Example:
/// ```dart
/// final throttler = UnrealMessageThrottler(controller);
///
/// // Configure rate limit (60 messages per second)
/// throttler.setRate('Player:position', 60);
///
/// // Send throttled messages
/// throttler.send('Player', 'position', data); // Rate limited
/// ```
class UnrealMessageThrottler {
  final UnrealController _controller;

  final Map<String, _ThrottleConfig> _configs = {};
  final Map<String, DateTime> _lastSendTimes = {};
  final Map<String, _PendingMessage> _pendingValues = {};
  Timer? _flushTimer;

  // Statistics
  int _messagesThrottled = 0;
  int _messagesDropped = 0;
  int _messagesSent = 0;

  UnrealMessageThrottler(this._controller) {
    // Start background flush timer for pending messages
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: 16), // ~60fps
      (_) => _flushPending(),
    );
  }

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

  /// Set rate limit using target and method separately.
  void setRateFor(
    String target,
    String method,
    int messagesPerSecond, {
    ThrottleStrategy strategy = ThrottleStrategy.keepLatest,
  }) {
    setRate('$target:$method', messagesPerSecond, strategy: strategy);
  }

  /// Remove rate limit for a key.
  void removeRate(String key) {
    _configs.remove(key);
    _lastSendTimes.remove(key);
    _pendingValues.remove(key);
  }

  /// Send a message with throttling.
  Future<void> send(String target, String method, dynamic data) async {
    final key = '$target:$method';
    final config = _configs[key];

    if (config == null || config.rateHz <= 0) {
      // No throttle configured - send immediately
      await _sendImmediate(target, method, data);
      _messagesSent++;
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
      _messagesSent++;
    } else {
      // Throttled - apply strategy
      _messagesThrottled++;
      switch (config.strategy) {
        case ThrottleStrategy.drop:
          // Drop the message
          _messagesDropped++;
          break;
        case ThrottleStrategy.keepLatest:
          // Store for later (replaces any pending)
          _pendingValues[key] = _PendingMessage(target, method, data);
          break;
        case ThrottleStrategy.keepFirst:
          // Only store if not already pending
          _pendingValues.putIfAbsent(
              key, () => _PendingMessage(target, method, data));
          break;
        case ThrottleStrategy.queue:
          // Queue for later (would need a list, simplified to keepLatest)
          _pendingValues[key] = _PendingMessage(target, method, data);
          break;
      }
    }
  }

  /// Flush any pending throttled messages that are now eligible.
  Future<void> _flushPending() async {
    final now = DateTime.now();
    final keysToFlush = <String>[];

    for (final entry in _pendingValues.entries) {
      final key = entry.key;
      final config = _configs[key];
      final lastSend = _lastSendTimes[key];

      if (config == null) {
        keysToFlush.add(key);
        continue;
      }

      if (lastSend == null ||
          now.difference(lastSend).inMilliseconds >= config.intervalMs) {
        keysToFlush.add(key);
      }
    }

    for (final key in keysToFlush) {
      final msg = _pendingValues.remove(key);
      if (msg != null) {
        _lastSendTimes[key] = now;
        await _sendImmediate(msg.target, msg.method, msg.data);
        _messagesSent++;
      }
    }
  }

  /// Manually flush all pending throttled messages immediately.
  Future<void> flush() async {
    final pending = Map<String, _PendingMessage>.from(_pendingValues);
    _pendingValues.clear();

    for (final msg in pending.values) {
      await _sendImmediate(msg.target, msg.method, msg.data);
      _messagesSent++;
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
      debugPrint('UnrealMessageThrottler: Send failed: $e');
    }
  }

  /// Get throttling statistics.
  ThrottlerStatistics get statistics => ThrottlerStatistics(
        messagesSent: _messagesSent,
        messagesThrottled: _messagesThrottled,
        messagesDropped: _messagesDropped,
        pendingCount: _pendingValues.length,
        configuredRates: _configs.length,
      );

  /// Reset statistics.
  void resetStatistics() {
    _messagesSent = 0;
    _messagesThrottled = 0;
    _messagesDropped = 0;
  }

  /// Get pending message count.
  int get pendingCount => _pendingValues.length;

  /// Get configured rate limit keys.
  Iterable<String> get configuredKeys => _configs.keys;

  /// Dispose the throttler.
  void dispose() {
    _flushTimer?.cancel();
    _pendingValues.clear();
    _configs.clear();
    _lastSendTimes.clear();
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

  /// Queue all messages for later (simplified to keepLatest)
  queue,
}

/// Throttling statistics.
class ThrottlerStatistics {
  final int messagesSent;
  final int messagesThrottled;
  final int messagesDropped;
  final int pendingCount;
  final int configuredRates;

  ThrottlerStatistics({
    required this.messagesSent,
    required this.messagesThrottled,
    required this.messagesDropped,
    required this.pendingCount,
    required this.configuredRates,
  });

  /// Throttle ratio (0.0 = no throttling, 1.0 = all throttled)
  double get throttleRatio {
    final total = messagesSent + messagesThrottled;
    return total > 0 ? messagesThrottled / total : 0.0;
  }

  /// Drop ratio of throttled messages
  double get dropRatio =>
      messagesThrottled > 0 ? messagesDropped / messagesThrottled : 0.0;

  @override
  String toString() =>
      'Sent=$messagesSent, Throttled=$messagesThrottled, Dropped=$messagesDropped, '
      'Pending=$pendingCount, ThrottleRatio=${(throttleRatio * 100).toStringAsFixed(1)}%';
}

/// Extension methods for UnrealController with performance utilities.
extension UnrealControllerPerformance on UnrealController {
  /// Create a message batcher for this controller.
  UnrealMessageBatcher createBatcher({
    int maxBatchSize = 50,
    int flushIntervalMs = 16,
  }) {
    final batcher = UnrealMessageBatcher(this);
    batcher.configure(
      maxBatchSize: maxBatchSize,
      flushIntervalMs: flushIntervalMs,
    );
    return batcher;
  }

  /// Create a message throttler for this controller.
  UnrealMessageThrottler createThrottler() {
    return UnrealMessageThrottler(this);
  }
}
