// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gameframework_example/main.dart';

void main() {
  testWidgets('App loads and displays title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed in AppBar.
    expect(
      find.widgetWithText(AppBar, 'Flutter Game Framework'),
      findsOneWidget,
    );

    // Verify that the games icon is present.
    expect(
      find.byIcon(Icons.games),
      findsOneWidget,
    );
  });

  testWidgets('App displays Unity example button', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that Unity Example button is displayed.
    expect(
      find.text('Unity Example'),
      findsOneWidget,
    );
  });
}
