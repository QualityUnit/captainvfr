import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:captainvfr/widgets/gesture_hints_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GestureHintsOverlay', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('displays gesture hints', (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureHintsOverlay(
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // Wait for animation
      await tester.pumpAndSettle();

      // Check for title
      expect(find.text('Map Gestures'), findsOneWidget);

      // Check for gesture hints
      expect(find.text('Drag'), findsOneWidget);
      expect(find.text('Pan the map'), findsOneWidget);
      expect(find.text('Pinch'), findsOneWidget);
      expect(find.text('Zoom in/out'), findsOneWidget);
      expect(find.text('Tap'), findsOneWidget);
      expect(find.text('Select airports, waypoints, airspaces'), findsOneWidget);
      expect(find.text('Tap (Planning)'), findsOneWidget);
      expect(find.text('Add waypoint to flight plan'), findsOneWidget);

      // Check for dismiss instruction
      expect(find.text('Tap anywhere to dismiss'), findsOneWidget);

      expect(dismissed, false);
    });

    testWidgets('dismisses on tap', (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureHintsOverlay(
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // Wait for animation
      await tester.pumpAndSettle();

      // Tap to dismiss
      await tester.tap(find.byType(GestureHintsOverlay));
      await tester.pumpAndSettle();

      expect(dismissed, true);
    });

    testWidgets('auto-dismisses after 5 seconds', (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureHintsOverlay(
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // Initial pump
      await tester.pump();

      expect(dismissed, false);

      // Wait for auto-dismiss timer (5 seconds)
      await tester.pump(const Duration(seconds: 5));
      
      // Pump animation frames
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(dismissed, true);
    });

    test('shouldShow returns true when not shown before', () async {
      SharedPreferences.setMockInitialValues({});
      final shouldShow = await GestureHintsOverlay.shouldShow();
      expect(shouldShow, true);
    });

    test('shouldShow returns false when shown before', () async {
      SharedPreferences.setMockInitialValues({
        'gesture_hints_shown': true,
      });
      final shouldShow = await GestureHintsOverlay.shouldShow();
      expect(shouldShow, false);
    });

    test('markAsShown sets the flag', () async {
      SharedPreferences.setMockInitialValues({});
      
      // Initially should show
      var shouldShow = await GestureHintsOverlay.shouldShow();
      expect(shouldShow, true);

      // Mark as shown
      await GestureHintsOverlay.markAsShown();

      // Should not show anymore
      shouldShow = await GestureHintsOverlay.shouldShow();
      expect(shouldShow, false);
    });

    testWidgets('has proper fade animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureHintsOverlay(
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Check for FadeTransition
      expect(find.byType(FadeTransition), findsOneWidget);

      // Pump a few frames to see animation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('displays all gesture icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureHintsOverlay(
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for main icon
      expect(find.byIcon(Icons.touch_app), findsWidgets);
      expect(find.byIcon(Icons.pan_tool), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.add_location), findsOneWidget);
    });
  });
}
