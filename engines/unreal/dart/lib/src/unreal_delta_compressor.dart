import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Delta compressor for efficient state synchronization.
///
/// Computes and applies delta changes between state objects to minimize
/// data transmission for high-frequency updates.
///
/// Example:
/// ```dart
/// final compressor = UnrealDeltaCompressor();
///
/// // Compute delta between states
/// final current = {'x': 10, 'y': 20, 'health': 100};
/// final previous = {'x': 10, 'y': 15, 'health': 100};
/// final delta = compressor.computeDelta(current, previous);
/// // Result: {'y': 20} - only changed value
///
/// // Apply delta to base state
/// final updated = compressor.applyDelta(previous, delta);
/// // Result: {'x': 10, 'y': 20, 'health': 100}
/// ```
class UnrealDeltaCompressor {
  /// State history for tracking previous states by key
  final Map<String, Map<String, dynamic>> _stateHistory = {};

  /// Maximum history entries to keep per key
  int _maxHistorySize = 10;

  /// Whether to track nested objects recursively
  bool _deepComparison = true;

  /// Minimum savings ratio to apply delta (0.0 - 1.0)
  double _minimumSavingsRatio = 0.2;

  // Statistics
  int _deltasComputed = 0;
  int _deltasApplied = 0;
  int _bytesSaved = 0;

  /// Configure the delta compressor.
  void configure({
    int? maxHistorySize,
    bool? deepComparison,
    double? minimumSavingsRatio,
  }) {
    if (maxHistorySize != null) _maxHistorySize = maxHistorySize;
    if (deepComparison != null) _deepComparison = deepComparison;
    if (minimumSavingsRatio != null) {
      _minimumSavingsRatio = minimumSavingsRatio.clamp(0.0, 1.0);
    }
  }

  // ============================================================
  // MARK: - Delta Computation
  // ============================================================

  /// Compute the delta between current and previous state.
  ///
  /// Returns only the fields that have changed, added, or removed.
  /// Unchanged fields are not included in the delta.
  ///
  /// Special markers:
  /// - `_removed`: List of keys that were removed
  /// - `_null`: List of keys that were set to null
  Map<String, dynamic> computeDelta(
    Map<String, dynamic> current,
    Map<String, dynamic> previous,
  ) {
    _deltasComputed++;
    return _computeDeltaRecursive(current, previous, 0);
  }

  Map<String, dynamic> _computeDeltaRecursive(
    Map<String, dynamic> current,
    Map<String, dynamic> previous,
    int depth,
  ) {
    final delta = <String, dynamic>{};
    final removed = <String>[];
    final nulled = <String>[];

    // Find changed and added keys
    for (final entry in current.entries) {
      final key = entry.key;
      final currentValue = entry.value;

      if (!previous.containsKey(key)) {
        // New key added
        delta[key] = currentValue;
      } else {
        final previousValue = previous[key];

        if (currentValue == null && previousValue != null) {
          // Value set to null
          nulled.add(key);
        } else if (_hasChanged(currentValue, previousValue, depth)) {
          // Value changed
          if (_deepComparison &&
              currentValue is Map<String, dynamic> &&
              previousValue is Map<String, dynamic>) {
            // Recursively compute nested delta
            final nestedDelta = _computeDeltaRecursive(
              currentValue,
              previousValue,
              depth + 1,
            );
            if (nestedDelta.isNotEmpty) {
              delta[key] = nestedDelta;
            }
          } else {
            delta[key] = currentValue;
          }
        }
      }
    }

    // Find removed keys
    for (final key in previous.keys) {
      if (!current.containsKey(key)) {
        removed.add(key);
      }
    }

    // Add markers for removed/nulled keys
    if (removed.isNotEmpty) {
      delta['_removed'] = removed;
    }
    if (nulled.isNotEmpty) {
      delta['_null'] = nulled;
    }

    return delta;
  }

  bool _hasChanged(dynamic current, dynamic previous, int depth) {
    if (current == null && previous == null) return false;
    if (current == null || previous == null) return true;
    if (current.runtimeType != previous.runtimeType) return true;

    if (current is Map && previous is Map) {
      if (_deepComparison && depth < 5) {
        // Deep comparison for nested maps
        if (current.length != previous.length) return true;
        for (final key in current.keys) {
          if (!previous.containsKey(key)) return true;
          if (_hasChanged(current[key], previous[key], depth + 1)) return true;
        }
        return false;
      }
      // Shallow comparison
      return !mapEquals(current, previous);
    }

    if (current is List && previous is List) {
      if (current.length != previous.length) return true;
      for (int i = 0; i < current.length; i++) {
        if (_hasChanged(current[i], previous[i], depth + 1)) return true;
      }
      return false;
    }

    return current != previous;
  }

  // ============================================================
  // MARK: - Delta Application
  // ============================================================

  /// Apply a delta to a base state to produce the updated state.
  ///
  /// Handles `_removed` and `_null` markers properly.
  Map<String, dynamic> applyDelta(
    Map<String, dynamic> base,
    Map<String, dynamic> delta,
  ) {
    _deltasApplied++;
    return _applyDeltaRecursive(Map<String, dynamic>.from(base), delta);
  }

  Map<String, dynamic> _applyDeltaRecursive(
    Map<String, dynamic> base,
    Map<String, dynamic> delta,
  ) {
    // Handle removed keys
    if (delta.containsKey('_removed')) {
      final removed = delta['_removed'];
      if (removed is List) {
        for (final key in removed) {
          base.remove(key.toString());
        }
      }
    }

    // Handle nulled keys
    if (delta.containsKey('_null')) {
      final nulled = delta['_null'];
      if (nulled is List) {
        for (final key in nulled) {
          base[key.toString()] = null;
        }
      }
    }

    // Apply changed values
    for (final entry in delta.entries) {
      final key = entry.key;
      if (key == '_removed' || key == '_null') continue;

      final deltaValue = entry.value;

      if (_deepComparison &&
          deltaValue is Map<String, dynamic> &&
          base[key] is Map<String, dynamic>) {
        // Recursively apply nested delta
        base[key] = _applyDeltaRecursive(
          Map<String, dynamic>.from(base[key] as Map<String, dynamic>),
          deltaValue,
        );
      } else {
        base[key] = deltaValue;
      }
    }

    return base;
  }

  // ============================================================
  // MARK: - State History Management
  // ============================================================

  /// Compute delta using stored history and update history.
  ///
  /// Returns the delta if beneficial, otherwise returns the full state.
  /// Also stores the current state in history for future comparisons.
  DeltaResult computeDeltaWithHistory(
    String key,
    Map<String, dynamic> currentState,
  ) {
    final previousState = _stateHistory[key];

    if (previousState == null) {
      // No history - store and return full state
      _storeState(key, currentState);
      return DeltaResult(
        data: currentState,
        isDelta: false,
        originalSize: _estimateSize(currentState),
        resultSize: _estimateSize(currentState),
      );
    }

    final delta = computeDelta(currentState, previousState);

    // Calculate if delta is beneficial
    final originalSize = _estimateSize(currentState);
    final deltaSize = _estimateSize(delta);
    final savings = 1.0 - (deltaSize / originalSize);

    // Store current state for next comparison
    _storeState(key, currentState);

    if (savings >= _minimumSavingsRatio && delta.isNotEmpty) {
      _bytesSaved += (originalSize - deltaSize).round();
      return DeltaResult(
        data: delta,
        isDelta: true,
        originalSize: originalSize,
        resultSize: deltaSize,
      );
    } else {
      // Delta not beneficial, send full state
      return DeltaResult(
        data: currentState,
        isDelta: false,
        originalSize: originalSize,
        resultSize: originalSize,
      );
    }
  }

  void _storeState(String key, Map<String, dynamic> state) {
    _stateHistory[key] = Map<String, dynamic>.from(state);

    // Prune old keys if too many
    if (_stateHistory.length > _maxHistorySize * 2) {
      // Keep only the most recently used keys
      final keysToRemove = _stateHistory.keys
          .take(_stateHistory.length - _maxHistorySize)
          .toList();
      for (final k in keysToRemove) {
        _stateHistory.remove(k);
      }
    }
  }

  /// Get stored state from history.
  Map<String, dynamic>? getStoredState(String key) {
    return _stateHistory[key];
  }

  /// Clear state history for a key.
  void clearHistory(String key) {
    _stateHistory.remove(key);
  }

  /// Clear all state history.
  void clearAllHistory() {
    _stateHistory.clear();
  }

  // ============================================================
  // MARK: - Utilities
  // ============================================================

  double _estimateSize(Map<String, dynamic> data) {
    return jsonEncode(data).length.toDouble();
  }

  /// Check if a value represents a delta (contains delta markers).
  bool isDelta(Map<String, dynamic> data) {
    return data.containsKey('_removed') ||
        data.containsKey('_null') ||
        data.containsKey('_delta');
  }

  /// Wrap data as a delta message for transmission.
  Map<String, dynamic> wrapAsDelta(Map<String, dynamic> delta) {
    return {
      '_delta': true,
      '_timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': delta,
    };
  }

  /// Unwrap a delta message.
  Map<String, dynamic>? unwrapDelta(Map<String, dynamic> wrapped) {
    if (wrapped['_delta'] == true && wrapped.containsKey('data')) {
      return wrapped['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  // ============================================================
  // MARK: - Statistics
  // ============================================================

  /// Get compression statistics.
  DeltaStatistics get statistics => DeltaStatistics(
        deltasComputed: _deltasComputed,
        deltasApplied: _deltasApplied,
        bytesSaved: _bytesSaved,
        historyEntries: _stateHistory.length,
      );

  /// Reset statistics.
  void resetStatistics() {
    _deltasComputed = 0;
    _deltasApplied = 0;
    _bytesSaved = 0;
  }
}

/// Result of delta computation.
class DeltaResult {
  /// The resulting data (either delta or full state)
  final Map<String, dynamic> data;

  /// Whether the result is a delta (true) or full state (false)
  final bool isDelta;

  /// Original state size estimate
  final double originalSize;

  /// Result size estimate
  final double resultSize;

  DeltaResult({
    required this.data,
    required this.isDelta,
    required this.originalSize,
    required this.resultSize,
  });

  /// Compression ratio (0.0 = no compression, 1.0 = fully compressed)
  double get compressionRatio => 1.0 - (resultSize / originalSize);

  /// Savings as percentage
  double get savingsPercent => compressionRatio * 100;

  @override
  String toString() => isDelta
      ? 'Delta(${savingsPercent.toStringAsFixed(1)}% savings)'
      : 'FullState(${originalSize.toInt()} bytes)';
}

/// Statistics for delta compression.
class DeltaStatistics {
  final int deltasComputed;
  final int deltasApplied;
  final int bytesSaved;
  final int historyEntries;

  DeltaStatistics({
    required this.deltasComputed,
    required this.deltasApplied,
    required this.bytesSaved,
    required this.historyEntries,
  });

  @override
  String toString() =>
      'DeltaStats(computed=$deltasComputed, applied=$deltasApplied, '
      'saved=${bytesSaved}B, history=$historyEntries)';
}
