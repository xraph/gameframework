/// Tests for the Unity WebGL controller behavior.
///
/// NOTE: The web controller uses dart:html and dart:js which require a browser
/// environment. These tests verify the controller's logic, interface contract,
/// and message queuing behavior through the public API. Full integration tests
/// require running with `flutter test --platform chrome`.
///
/// For browser-based integration tests, see the example_web/ directory.
@TestOn('browser')
library unity_controller_web_test;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/src/unity_controller_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnityControllerWeb', () {
    late UnityControllerWeb controller;

    setUp(() {
      const config = GameEngineConfig(
        engineSpecificConfig: {
          'buildUrl': 'http://localhost/unity',
          'loaderUrl': 'http://localhost/unity/Build.loader.js',
        },
      );
      controller = UnityControllerWeb(99, config);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should have correct engine type', () {
      expect(controller.engineType, equals(GameEngineType.unity));
    });

    test('should have correct engine version', () {
      expect(controller.engineVersion, contains('WebGL'));
    });

    test('should start as not ready', () async {
      expect(await controller.isReady(), isFalse);
    });

    test('should start as not paused', () async {
      expect(await controller.isPaused(), isFalse);
    });

    test('should start as not loaded', () async {
      expect(await controller.isLoaded(), isFalse);
    });

    test('should provide message stream', () {
      expect(controller.messageStream, isA<Stream<GameEngineMessage>>());
    });

    test('should provide scene load stream', () {
      expect(controller.sceneLoadStream, isA<Stream<GameSceneLoaded>>());
    });

    test('should provide event stream', () {
      expect(controller.eventStream, isA<Stream<GameEngineEvent>>());
    });

    test('should provide progress stream', () {
      expect(controller.progressStream, isA<Stream<double>>());
    });

    test('should have containerId with viewId', () {
      expect(controller.containerId, equals('unity-container-99'));
    });

    test('should have container element', () {
      expect(controller.container, isNotNull);
      expect(controller.container!.id, equals('unity-container-99'));
    });

    group('Message Queuing', () {
      test('should queue messages when not ready', () async {
        // Send a message before Unity is ready
        await controller.sendMessage('GameManager', 'StartGame', 'level1');

        expect(controller.queuedMessageCount, equals(1));
      });

      test('should queue multiple messages', () async {
        await controller.sendMessage('Target1', 'Method1', 'Data1');
        await controller.sendMessage('Target2', 'Method2', 'Data2');
        await controller.sendMessage('Target3', 'Method3', 'Data3');

        expect(controller.queuedMessageCount, equals(3));
      });

      test('should drop oldest messages when queue is full', () async {
        // Fill the queue beyond max (100)
        for (int i = 0; i < 105; i++) {
          await controller.sendMessage('Target', 'Method', 'Data$i');
        }

        // Should be capped at max queue size
        expect(controller.queuedMessageCount, equals(100));
      });
    });

    group('Lifecycle', () {
      test('setStreamingCachePath should be no-op on web', () async {
        // Should not throw
        await controller.setStreamingCachePath('/some/path');
      });

      test('dispose should clean up', () {
        controller.dispose();

        // Disposing again should not throw
        controller.dispose();
      });
    });
  });

  group('createUnityController (web)', () {
    test('should create UnityControllerWeb instance', () {
      const config = GameEngineConfig(
        engineSpecificConfig: {
          'buildUrl': 'http://localhost/unity',
          'loaderUrl': 'http://localhost/unity/Build.loader.js',
        },
      );
      final controller = createUnityController(1, config);

      expect(controller, isA<UnityControllerWeb>());
      controller.dispose();
    });
  });
}
