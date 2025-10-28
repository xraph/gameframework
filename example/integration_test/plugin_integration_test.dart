// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://docs.flutter.dev/cookbook/testing/integration/introduction

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gameframework/gameframework.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GameEngineRegistry is accessible', (WidgetTester tester) async {
    final registry = GameEngineRegistry.instance;
    expect(registry, isNotNull);
  });

  testWidgets('PlatformInfo is accessible', (WidgetTester tester) async {
    final platform = PlatformInfo.platform;
    expect(platform, isNotNull);
    expect(platform.platformName, isNotNull);
  });

  testWidgets('Framework version is valid', (WidgetTester tester) async {
    expect(gameFrameworkVersion, isNotNull);
    expect(gameFrameworkVersion.isNotEmpty, true);
  });
}
