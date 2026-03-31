// This is a basic Flutter widget test for the Discipline Tracker app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:discipline_tracker/main.dart';

void main() {
  testWidgets('Discipline Tracker app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify that the app loads with the current tab navigation.
    expect(find.byType(TabBar), findsOneWidget);

    // Verify the app title in MaterialApp.
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, 'Discipline Tracker');

    // Verify that a Scaffold is present.
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });

  testWidgets('Tab navigation test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TabBar), findsOneWidget);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));

    // Verify the expected number of tabs in current UI.
    expect(tabBar.tabs.length, greaterThan(1));
    expect(tabBar.tabs.length, equals(10));

    // Verify key tabs are visible.
    expect(find.text('Daily Tasks'), findsWidgets);
    expect(find.text('Stats'), findsWidgets);
    expect(find.text('Challenge'), findsWidgets);
  });

  testWidgets('App initializes with MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
