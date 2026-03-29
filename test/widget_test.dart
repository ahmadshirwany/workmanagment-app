// This is a basic Flutter widget test for the Discipline Tracker app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:discipline_tracker/main.dart';

void main() {
  testWidgets('Discipline Tracker app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for initial build and async operations
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify that the app loads with the bottom navigation bar
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Verify the app title in MaterialApp
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, 'Discipline Tracker');

    // Verify that the Scaffold is present
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });

  testWidgets('Bottom navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for initial build
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Find the bottom navigation bar
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Test that we can navigate (if there are multiple items)
    final bottomNavBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    // Verify there are multiple navigation items (should be 8 screens)
    expect(bottomNavBar.items.length, greaterThan(1));
    expect(bottomNavBar.items.length, equals(8));
  });

  testWidgets('App initializes with MaterialApp', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const MyApp());

    // Verify MaterialApp exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
