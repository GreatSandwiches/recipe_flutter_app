import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_flutter_app/main.dart';

void main() {
  group('MainApp Tests', () {
    testWidgets('Main app loads successfully', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MainApp());

      // Verify that the bottom navigation bar is present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      
      // Verify that all navigation items are present
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Navigation between tabs works', (WidgetTester tester) async {
      await tester.pumpWidget(const MainApp());

      // Tap on Favourites tab
      await tester.tap(find.text('Favourites'));
      await tester.pump();

      // Verify we're on the Favourites screen
      expect(find.text('Favourites Screen'), findsOneWidget);

      // Tap on Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();

      // Verify we're on the Profile screen
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}