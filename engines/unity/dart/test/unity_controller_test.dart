import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnityController', () {
    late UnityController controller;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Set up mock method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.xraph.gameframework/engine_1'),
        (MethodCall call) async {
          methodCalls.add(call);

          switch (call.method) {
            case 'events#setup':
              return true;
            case 'engine#create':
              return true;
            case 'engine#isReady':
              return true;
            case 'engine#isPaused':
              return false;
            case 'engine#isLoaded':
              return true;
            case 'engine#isInBackground':
              return false;
            case 'engine#sendMessage':
              return null;
            case 'engine#pause':
              return null;
            case 'engine#resume':
              return null;
            case 'engine#unload':
              return null;
            case 'engine#quit':
              return null;
            case 'streaming#setCachePath':
              return true;
            default:
              return null;
          }
        },
      );

      controller = UnityController(1);
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.xraph.gameframework/engine_1'),
        null,
      );
    });

    test('should have correct engine type', () {
      expect(controller.engineType, equals(GameEngineType.unity));
    });

    test('should have engine version', () {
      expect(controller.engineVersion, isNotNull);
      expect(controller.engineVersion.isNotEmpty, isTrue);
    });

    test('isReady should call method channel', () async {
      // Wait for event setup
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await controller.isReady();

      expect(result, isTrue);
      expect(
        methodCalls.any((call) => call.method == 'engine#isReady'),
        isTrue,
      );
    });

    test('isPaused should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await controller.isPaused();

      expect(result, isFalse);
      expect(
        methodCalls.any((call) => call.method == 'engine#isPaused'),
        isTrue,
      );
    });

    test('isLoaded should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await controller.isLoaded();

      expect(result, isTrue);
      expect(
        methodCalls.any((call) => call.method == 'engine#isLoaded'),
        isTrue,
      );
    });

    test('isInBackground should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await controller.isInBackground();

      expect(result, isFalse);
      expect(
        methodCalls.any((call) => call.method == 'engine#isInBackground'),
        isTrue,
      );
    });

    test('create should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await controller.create();

      expect(result, isTrue);
      expect(
        methodCalls.any((call) => call.method == 'engine#create'),
        isTrue,
      );
    });

    test('sendMessage should call method channel with correct arguments',
        () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.sendMessage('GameManager', 'StartGame', 'level1');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'engine#sendMessage',
      );

      expect(call.arguments['target'], equals('GameManager'));
      expect(call.arguments['method'], equals('StartGame'));
      expect(call.arguments['data'], equals('level1'));
    });

    test('sendJsonMessage should serialize data', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.sendJsonMessage('Player', 'SetStats', {
        'health': 100,
        'score': 500,
      });

      final call = methodCalls.firstWhere(
        (c) => c.method == 'engine#sendMessage',
      );

      expect(call.arguments['target'], equals('Player'));
      expect(call.arguments['method'], equals('SetStats'));
      expect(call.arguments['data'], isNotNull);
    });

    test('pause should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.pause();

      expect(
        methodCalls.any((call) => call.method == 'engine#pause'),
        isTrue,
      );
    });

    test('resume should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.resume();

      expect(
        methodCalls.any((call) => call.method == 'engine#resume'),
        isTrue,
      );
    });

    test('unload should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.unload();

      expect(
        methodCalls.any((call) => call.method == 'engine#unload'),
        isTrue,
      );
    });

    test('quit should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.quit();

      expect(
        methodCalls.any((call) => call.method == 'engine#quit'),
        isTrue,
      );
    });

    test('setStreamingCachePath should call method channel', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.setStreamingCachePath('/cache/streaming');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'streaming#setCachePath',
      );

      expect(call.arguments['path'], equals('/cache/streaming'));
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
  });

  group('UnityEnginePlugin', () {
    test('should register factory', () {
      UnityEnginePlugin.initialize();

      final registry = GameEngineRegistry.instance;
      expect(registry.isEngineRegistered(GameEngineType.unity), isTrue);
    });
  });

  group('createUnityController', () {
    test('should create UnityController instance', () {
      const config = GameEngineConfig();
      final controller = createUnityController(1, config);

      expect(controller, isA<UnityController>());
      controller.dispose();
    });
  });
}
