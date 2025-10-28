/// Lifecycle events from the game engine
enum GameEngineEventType {
  /// Engine was created and initialized
  created,

  /// Engine finished loading
  loaded,

  /// Engine was paused
  paused,

  /// Engine was resumed
  resumed,

  /// Engine was unloaded
  unloaded,

  /// Engine was destroyed
  destroyed,

  /// An error occurred
  error,
}

/// Event representing a change in engine lifecycle
class GameEngineEvent {
  const GameEngineEvent({
    required this.type,
    required this.timestamp,
    this.message,
    this.error,
  });

  /// The type of event
  final GameEngineEventType type;

  /// When the event occurred
  final DateTime timestamp;

  /// Optional message describing the event
  final String? message;

  /// Optional error object if type is error
  final Object? error;

  /// Create from platform map
  factory GameEngineEvent.fromMap(Map<String, dynamic> map) {
    return GameEngineEvent(
      type: _parseEventType(map['type'] as String?),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      message: map['message'] as String?,
      error: map['error'],
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'message': message,
      'error': error?.toString(),
    };
  }

  static GameEngineEventType _parseEventType(String? typeString) {
    if (typeString == null) return GameEngineEventType.error;

    try {
      return GameEngineEventType.values.firstWhere(
        (e) => e.name == typeString,
        orElse: () => GameEngineEventType.error,
      );
    } catch (_) {
      return GameEngineEventType.error;
    }
  }

  @override
  String toString() {
    return 'GameEngineEvent('
        'type: ${type.name}, '
        'timestamp: $timestamp, '
        'message: $message, '
        'error: $error'
        ')';
  }
}
