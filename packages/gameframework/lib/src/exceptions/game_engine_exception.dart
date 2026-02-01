import '../models/game_engine_type.dart';

/// Base exception for game framework errors
class GameEngineException implements Exception {
  const GameEngineException(
    this.message, {
    this.engineType,
    this.engineVersion,
    this.metadata,
    this.stackTrace,
  });

  final String message;
  final GameEngineType? engineType;
  final String? engineVersion;
  final Map<String, dynamic>? metadata;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('GameEngineException: $message');
    if (engineType != null) {
      buffer.write(' [Engine: ${engineType!.engineName}]');
    }
    if (engineVersion != null) {
      buffer.write(' [Version: $engineVersion]');
    }
    return buffer.toString();
  }
}

/// Exception for engine version incompatibility
class EngineVersionException extends GameEngineException {
  EngineVersionException(
    super.message,
    GameEngineType type,
    String version,
  ) : super(
          engineType: type,
          engineVersion: version,
        );
}

/// Exception for communication errors between Flutter and engine
class EngineCommunicationException extends GameEngineException {
  EngineCommunicationException(
    super.message, {
    required this.target,
    required this.method,
    super.engineType,
  });

  final String target;
  final String method;

  @override
  String toString() {
    return 'EngineCommunicationException: $message '
        '[Target: $target, Method: $method]';
  }
}

/// Exception thrown when engine is not ready for operations
class EngineNotReadyException extends GameEngineException {
  EngineNotReadyException(GameEngineType type)
      : super(
          'Engine ${type.name} is not ready. '
          'Call controller.create() or set runImmediately: true',
          engineType: type,
        );
}

/// Exception thrown when trying to run multiple engines simultaneously
class MultipleEnginesException extends GameEngineException {
  MultipleEnginesException(
    this.activeEngine,
    this.requestedEngine,
  ) : super(
          'Engine ${activeEngine.name} is already active. '
          'Only one engine can run at a time. '
          'Unload the current engine before loading ${requestedEngine.name}.',
        );

  final GameEngineType activeEngine;
  final GameEngineType requestedEngine;
}

/// Exception thrown when engine plugin is not registered
class EngineNotRegisteredException extends GameEngineException {
  EngineNotRegisteredException(GameEngineType type)
      : super(
          'Engine ${type.name} is not registered. '
          'Make sure to call ${type.name}EnginePlugin.initialize() '
          'before using the engine.',
          engineType: type,
        );
}
