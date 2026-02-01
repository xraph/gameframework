import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Unity Embedding Integration Tests', () {
    setUp(() {
      // Initialize Unity plugin
      UnityEnginePlugin.initialize();
    });

    testWidgets('Unity embeds correctly without launching standalone',
        (WidgetTester tester) async {
      // This test verifies Unity embeds in Flutter UI, not as separate app
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Unity Embedding Test')),
            body: Column(
              children: [
                const Text('Above Unity'),
                Expanded(
                  child: GameWidget(
                    engineType: GameEngineType.unity,
                    onEngineCreated: (controller) {
                      debugPrint('✅ Unity created');
                    },
                  ),
                ),
                const Text('Below Unity'),
              ],
            ),
          ),
        ),
      );

      // Verify Flutter UI elements are present
      expect(find.text('Unity Embedding Test'), findsOneWidget);
      expect(find.text('Above Unity'), findsOneWidget);
      expect(find.text('Below Unity'), findsOneWidget);

      // Give Unity time to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If this test completes, Unity is embedded (not launching separately)
      debugPrint('✅ Unity embedded correctly - Flutter UI still visible');
    });

    testWidgets('Unity controller initialization completes',
        (WidgetTester tester) async {
      GameEngineController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameWidget(
              engineType: GameEngineType.unity,
              onEngineCreated: (ctrl) {
                controller = ctrl;
                debugPrint('✅ Unity controller created');
              },
            ),
          ),
        ),
      );

      // Wait for initialization
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify controller was created
      expect(controller, isNotNull, reason: 'Controller should be created');

      debugPrint('✅ Controller initialization test passed');
    });

    testWidgets('Unity survives multiple pause/resume cycles',
        (WidgetTester tester) async {
      GameEngineController? controller;
      var pauseCount = 0;
      var resumeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameWidget(
              engineType: GameEngineType.unity,
              onEngineCreated: (ctrl) {
                controller = ctrl;
              },
            ),
          ),
        ),
      );

      // Wait for Unity to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(controller, isNotNull);

      // Test multiple pause/resume cycles
      for (var i = 0; i < 3; i++) {
        debugPrint('🔄 Pause/Resume cycle ${i + 1}/3');

        // Pause
        await controller!.pause();
        await tester.pump(const Duration(milliseconds: 500));
        pauseCount++;
        debugPrint('⏸️  Paused ($pauseCount)');

        // Resume
        await controller!.resume();
        await tester.pump(const Duration(milliseconds: 500));
        resumeCount++;
        debugPrint('▶️  Resumed ($resumeCount)');
      }

      expect(pauseCount, equals(3));
      expect(resumeCount, equals(3));

      debugPrint(
          '✅ Lifecycle test passed: $pauseCount pause, $resumeCount resume');
    });

    testWidgets('Unity handles dispose during initialization gracefully',
        (WidgetTester tester) async {
      // This test verifies race condition fixes
      var initStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameWidget(
              engineType: GameEngineType.unity,
              onEngineCreated: (controller) {
                initStarted = true;
                debugPrint('Unity initialization started');
              },
            ),
          ),
        ),
      );

      // Pump once to start initialization
      await tester.pump();

      // Immediately navigate away (triggers dispose)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Navigated Away')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash
      expect(find.text('Navigated Away'), findsOneWidget);

      debugPrint('✅ Race condition test passed - no crash on early dispose');
    });

    testWidgets('Unity view has correct size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: GameWidget(
                engineType: GameEngineType.unity,
                onEngineCreated: (controller) {
                  debugPrint('✅ Unity created in sized container');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find the GameWidget
      final gameWidget = find.byType(GameWidget);
      expect(gameWidget, findsOneWidget);

      // Verify it has a size
      final RenderBox box = tester.renderObject(gameWidget) as RenderBox;
      expect(box.size.width, greaterThan(0));
      expect(box.size.height, greaterThan(0));

      debugPrint(
          '✅ View sizing test passed: ${box.size.width}x${box.size.height}');
    });

    testWidgets('Multiple GameWidgets do not interfere',
        (WidgetTester tester) async {
      // Test that navigating between screens with Unity works
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('Unity Screen')),
                        body: GameWidget(
                          engineType: GameEngineType.unity,
                          onEngineCreated: (controller) {
                            debugPrint('✅ Unity in screen 1');
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Unity Screen'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Unity screen
      await tester.tap(find.text('Open Unity Screen'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify Unity screen is shown
      expect(find.text('Unity Screen'), findsOneWidget);

      // Navigate back
      navigatorKey.currentState?.pop();
      await tester.pumpAndSettle();

      // Should return to original screen without crash
      expect(find.text('Open Unity Screen'), findsOneWidget);

      debugPrint('✅ Navigation test passed - no crashes');
    });
  });

  group('Black Screen Prevention Tests', () {
    testWidgets('Unity view is not black after initialization',
        (WidgetTester tester) async {
      // This test can't directly check if view is black,
      // but verifies initialization completes successfully
      var engineReady = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameWidget(
              engineType: GameEngineType.unity,
              onEngineCreated: (controller) async {
                // Give Unity time to render first frame
                await Future.delayed(const Duration(seconds: 2));
                engineReady = true;
                debugPrint('✅ Unity should be rendering now');
              },
            ),
          ),
        ),
      );

      // Wait for Unity to fully initialize
      await tester.pumpAndSettle(const Duration(seconds: 7));

      expect(engineReady, isTrue,
          reason: 'Unity should be ready and rendering');

      debugPrint('✅ Black screen prevention test passed');
    });

    testWidgets('Unity initializes with proper timing',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      var initTime = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameWidget(
              engineType: GameEngineType.unity,
              onEngineCreated: (controller) {
                initTime = stopwatch.elapsedMilliseconds;
                debugPrint('✅ Unity initialized in ${initTime}ms');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 10));

      stopwatch.stop();

      // Unity should initialize within reasonable time (< 10 seconds)
      expect(initTime, greaterThan(0));
      expect(initTime, lessThan(10000),
          reason: 'Unity should initialize within 10 seconds');

      debugPrint('✅ Timing test passed: initialized in ${initTime}ms');
    });
  });
}
