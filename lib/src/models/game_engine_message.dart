import 'dart:convert';

/// Base class for messages from the game engine
class GameEngineMessage {
  const GameEngineMessage({
    required this.data,
    required this.timestamp,
    this.metadata,
  });

  /// The message data as a string
  final String data;

  /// When the message was received
  final DateTime timestamp;

  /// Optional metadata about the message
  final Map<String, dynamic>? metadata;

  /// Try to parse the message as JSON
  /// Returns null if parsing fails
  Map<String, dynamic>? asJson() {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Create from platform map
  factory GameEngineMessage.fromMap(Map<String, dynamic> map) {
    return GameEngineMessage(
      data: map['data'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'GameEngineMessage('
        'data: $data, '
        'timestamp: $timestamp, '
        'metadata: $metadata'
        ')';
  }
}
