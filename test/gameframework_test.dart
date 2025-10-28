import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework/gameframework.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameEngineType', () {
    test('should have correct engine names', () {
      expect(GameEngineType.unity.engineName, 'Unity');
      expect(GameEngineType.unreal.engineName, 'Unreal Engine');
    });

    test('should have correct identifiers', () {
      expect(GameEngineType.unity.identifier, 'unity');
      expect(GameEngineType.unreal.identifier, 'unreal');
    });
  });

  group('GameEngineConfig', () {
    test('should create with default values', () {
      const config = GameEngineConfig();
      expect(config.fullscreen, false);
      expect(config.hideStatusBar, false);
      expect(config.runImmediately, false);
      expect(config.unloadOnDispose, false);
      expect(config.enableDebugLogs, true);
      expect(config.targetFrameRate, null);
      expect(config.engineSpecificConfig, null);
    });

    test('should create with custom values', () {
      const config = GameEngineConfig(
        fullscreen: true,
        runImmediately: true,
        targetFrameRate: 60,
        engineSpecificConfig: {'test': 'value'},
      );
      expect(config.fullscreen, true);
      expect(config.runImmediately, true);
      expect(config.targetFrameRate, 60);
      expect(config.engineSpecificConfig, {'test': 'value'});
    });

    test('should serialize to map', () {
      const config = GameEngineConfig(
        fullscreen: true,
        runImmediately: false,
        targetFrameRate: 60,
      );
      final map = config.toMap();
      expect(map['fullscreen'], true);
      expect(map['runImmediately'], false);
      expect(map['targetFrameRate'], 60);
    });

    test('should copy with updated values', () {
      const config = GameEngineConfig(fullscreen: false);
      final updated = config.copyWith(fullscreen: true, targetFrameRate: 30);
      expect(updated.fullscreen, true);
      expect(updated.targetFrameRate, 30);
    });
  });

  group('GameEngineMessage', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();
      final message = GameEngineMessage(
        data: 'test data',
        timestamp: timestamp,
      );
      expect(message.data, 'test data');
      expect(message.timestamp, timestamp);
      expect(message.metadata, null);
    });

    test('should create with metadata', () {
      final message = GameEngineMessage(
        data: 'test',
        timestamp: DateTime.now(),
        metadata: {'key': 'value'},
      );
      expect(message.metadata, {'key': 'value'});
    });

    test('should parse JSON data', () {
      final message = GameEngineMessage(
        data: '{"score": 100, "stars": 3}',
        timestamp: DateTime.now(),
      );
      final json = message.asJson();
      expect(json, isNotNull);
      expect(json!['score'], 100);
      expect(json['stars'], 3);
    });

    test('should handle invalid JSON gracefully', () {
      final message = GameEngineMessage(
        data: 'not valid json',
        timestamp: DateTime.now(),
      );
      final json = message.asJson();
      expect(json, isNull);
    });

    test('should serialize to map', () {
      final timestamp = DateTime.now();
      final message = GameEngineMessage(
        data: 'test',
        timestamp: timestamp,
        metadata: {'key': 'value'},
      );
      final map = message.toMap();
      expect(map['data'], 'test');
      expect(map['timestamp'], timestamp.millisecondsSinceEpoch);
      expect(map['metadata'], {'key': 'value'});
    });

    test('should create from map', () {
      final timestamp = DateTime.now();
      final map = {
        'data': 'test data',
        'timestamp': timestamp.millisecondsSinceEpoch,
        'metadata': {'key': 'value'},
      };
      final message = GameEngineMessage.fromMap(map);
      expect(message.data, 'test data');
      expect(message.timestamp.millisecondsSinceEpoch,
          timestamp.millisecondsSinceEpoch);
      expect(message.metadata, {'key': 'value'});
    });
  });

  group('GameSceneLoaded', () {
    test('should create with required fields', () {
      const scene = GameSceneLoaded(
        name: 'Level1',
        buildIndex: 1,
        isLoaded: true,
        isValid: true,
      );
      expect(scene.name, 'Level1');
      expect(scene.buildIndex, 1);
      expect(scene.isLoaded, true);
      expect(scene.isValid, true);
      expect(scene.metadata, null);
    });

    test('should create with metadata', () {
      const scene = GameSceneLoaded(
        name: 'MainMenu',
        buildIndex: 0,
        isLoaded: true,
        isValid: true,
        metadata: {'difficulty': 'easy'},
      );
      expect(scene.metadata, {'difficulty': 'easy'});
    });

    test('should serialize to map', () {
      const scene = GameSceneLoaded(
        name: 'MainMenu',
        buildIndex: 0,
        isLoaded: true,
        isValid: true,
        metadata: {'difficulty': 'easy'},
      );
      final map = scene.toMap();
      expect(map['name'], 'MainMenu');
      expect(map['buildIndex'], 0);
      expect(map['isLoaded'], true);
      expect(map['isValid'], true);
      expect(map['metadata'], {'difficulty': 'easy'});
    });

    test('should create from map', () {
      final map = {
        'name': 'Level2',
        'buildIndex': 2,
        'isLoaded': true,
        'isValid': true,
        'metadata': {'enemies': 10},
      };
      final scene = GameSceneLoaded.fromMap(map);
      expect(scene.name, 'Level2');
      expect(scene.buildIndex, 2);
      expect(scene.isLoaded, true);
      expect(scene.isValid, true);
      expect(scene.metadata, {'enemies': 10});
    });
  });

  group('GameEngineEvent', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();
      final event = GameEngineEvent(
        type: GameEngineEventType.created,
        timestamp: timestamp,
      );
      expect(event.type, GameEngineEventType.created);
      expect(event.timestamp, timestamp);
      expect(event.message, null);
      expect(event.error, null);
    });

    test('should create with message', () {
      final event = GameEngineEvent(
        type: GameEngineEventType.error,
        timestamp: DateTime.now(),
        message: 'Test error',
      );
      expect(event.type, GameEngineEventType.error);
      expect(event.message, 'Test error');
    });

    test('should create with error object', () {
      final error = Exception('Test exception');
      final event = GameEngineEvent(
        type: GameEngineEventType.error,
        timestamp: DateTime.now(),
        error: error,
      );
      expect(event.error, error);
    });

    test('should have all event types', () {
      expect(GameEngineEventType.created, isNotNull);
      expect(GameEngineEventType.loaded, isNotNull);
      expect(GameEngineEventType.paused, isNotNull);
      expect(GameEngineEventType.resumed, isNotNull);
      expect(GameEngineEventType.unloaded, isNotNull);
      expect(GameEngineEventType.destroyed, isNotNull);
      expect(GameEngineEventType.error, isNotNull);
    });

    test('should serialize to map', () {
      final timestamp = DateTime.now();
      final event = GameEngineEvent(
        type: GameEngineEventType.paused,
        timestamp: timestamp,
        message: 'Game paused',
      );
      final map = event.toMap();
      expect(map['type'], 'paused');
      expect(map['timestamp'], timestamp.millisecondsSinceEpoch);
      expect(map['message'], 'Game paused');
    });

    test('should create from map', () {
      final timestamp = DateTime.now();
      final map = {
        'type': 'resumed',
        'timestamp': timestamp.millisecondsSinceEpoch,
        'message': 'Game resumed',
      };
      final event = GameEngineEvent.fromMap(map);
      expect(event.type, GameEngineEventType.resumed);
      expect(event.timestamp.millisecondsSinceEpoch,
          timestamp.millisecondsSinceEpoch);
      expect(event.message, 'Game resumed');
    });

    test('should handle invalid event type', () {
      final map = {
        'type': 'invalid',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final event = GameEngineEvent.fromMap(map);
      expect(event.type, GameEngineEventType.error);
    });
  });

  group('GameEngineException', () {
    test('should create base exception', () {
      const exception = GameEngineException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.engineType, null);
      expect(exception.engineVersion, null);
    });

    test('should create exception with engine type', () {
      const exception = GameEngineException(
        'Test error',
        engineType: GameEngineType.unity,
      );
      expect(exception.engineType, GameEngineType.unity);
      expect(exception.toString(), contains('Unity'));
    });

    test('should create engine version exception', () {
      final exception = EngineVersionException(
        'Version mismatch',
        GameEngineType.unity,
        '2022.3.0',
      );
      expect(exception, isA<GameEngineException>());
      expect(exception.engineType, GameEngineType.unity);
      expect(exception.engineVersion, '2022.3.0');
      expect(exception.toString(), contains('Unity'));
      expect(exception.toString(), contains('2022.3.0'));
    });

    test('should create communication exception', () {
      final exception = EngineCommunicationException(
        'Failed to send message',
        target: 'Player',
        method: 'Jump',
        engineType: GameEngineType.unity,
      );
      expect(exception, isA<GameEngineException>());
      expect(exception.target, 'Player');
      expect(exception.method, 'Jump');
      expect(exception.toString(), contains('Player'));
      expect(exception.toString(), contains('Jump'));
    });

    test('should create engine not ready exception', () {
      final exception = EngineNotReadyException(GameEngineType.unity);
      expect(exception, isA<GameEngineException>());
      expect(exception.engineType, GameEngineType.unity);
      expect(exception.toString(), contains('not ready'));
    });

    test('should create multiple engines exception', () {
      final exception = MultipleEnginesException(
        GameEngineType.unity,
        GameEngineType.unreal,
      );
      expect(exception, isA<GameEngineException>());
      expect(exception.activeEngine, GameEngineType.unity);
      expect(exception.requestedEngine, GameEngineType.unreal);
      expect(exception.toString(), contains('already active'));
    });

    test('should create engine not registered exception', () {
      final exception = EngineNotRegisteredException(GameEngineType.unreal);
      expect(exception, isA<GameEngineException>());
      expect(exception.engineType, GameEngineType.unreal);
      expect(exception.toString(), contains('not registered'));
    });
  });

  group('GameEngineRegistry', () {
    late GameEngineRegistry registry;

    setUp(() {
      registry = GameEngineRegistry.instance;
    });

    test('should be singleton', () {
      final registry1 = GameEngineRegistry.instance;
      final registry2 = GameEngineRegistry.instance;
      expect(registry1, same(registry2));
    });

    test('should check if engine is registered', () {
      // By default, no engines should be registered in tests
      expect(registry.isEngineRegistered(GameEngineType.unity), false);
      expect(registry.isEngineRegistered(GameEngineType.unreal), false);
    });
  });

  group('PlatformInfo', () {
    test('should provide platform details', () {
      final platform = PlatformInfo.platform;
      expect(platform, isNotNull);
      expect(platform.platformName, isNotNull);
      expect(platform.isMobile || platform.isDesktop || platform.isWeb, true);
    });

    test('should identify supported engines', () {
      final platform = PlatformInfo.platform;
      final supported = platform.supportedEngines;
      expect(supported, isA<List<String>>());
    });

    test('should have platform flags', () {
      final platform = PlatformInfo.platform;
      // At least one should be true
      final hasFlag = platform.isAndroid ||
          platform.isIOS ||
          platform.isWeb ||
          platform.isWindows ||
          platform.isMacOS ||
          platform.isLinux;
      expect(hasFlag, true);
    });

    test('should check Unity support', () {
      final platform = PlatformInfo.platform;
      expect(platform.supportsUnity, isA<bool>());
    });

    test('should check Unreal support', () {
      final platform = PlatformInfo.platform;
      expect(platform.supportsUnreal, isA<bool>());
    });
  });

  group('Framework Version', () {
    test('should have valid version', () {
      expect(gameFrameworkVersion, isNotNull);
      expect(gameFrameworkVersion.isNotEmpty, true);
      expect(gameFrameworkVersion, '0.4.0');
    });
  });
}
