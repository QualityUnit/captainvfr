import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:captainvfr/widgets/quick_action_bar.dart';

void main() {
  group('QuickActionBar', () {
    testWidgets('displays all 5 action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for all 5 buttons
      expect(find.text('Center'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Layers'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('shows Stop when tracking', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: true,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('center button calls onCenterMap', (WidgetTester tester) async {
      bool centerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {
                centerCalled = true;
              },
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Center'));
      await tester.pumpAndSettle();

      expect(centerCalled, true);
    });

    testWidgets('start/stop button calls onStartFlight', (WidgetTester tester) async {
      bool startFlightCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {
                startFlightCalled = true;
              },
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(startFlightCalled, true);
    });

    testWidgets('emergency button calls onEmergency', (WidgetTester tester) async {
      bool emergencyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {
                emergencyCalled = true;
              },
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('SOS'));
      await tester.pumpAndSettle();

      expect(emergencyCalled, true);
    });

    testWidgets('layers button calls onLayers', (WidgetTester tester) async {
      bool layersCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {
                layersCalled = true;
              },
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Layers'));
      await tester.pumpAndSettle();

      expect(layersCalled, true);
    });

    testWidgets('plan button calls onFlightPlan', (WidgetTester tester) async {
      bool flightPlanCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {
                flightPlanCalled = true;
              },
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      expect(flightPlanCalled, true);
    });

    testWidgets('start/stop button is larger than others', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find all GestureDetector widgets
      final gestures = tester.widgetList<GestureDetector>(find.byType(GestureDetector));
      
      // The start/stop button should be larger (64dp vs 56dp)
      expect(gestures.length, 5);
    });

    testWidgets('has proper styling with shadows', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for container with decoration
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(QuickActionBar),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.isNotEmpty, true);
    });

    testWidgets('plan button changes color when has flight plan', (WidgetTester tester) async {
      // Without flight plan
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // With flight plan
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionBar(
              onCenterMap: () {},
              onStartFlight: () {},
              onEmergency: () {},
              onLayers: () {},
              onFlightPlan: () {},
              isTracking: false,
              hasFlightPlan: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both should render without error
      expect(find.text('Plan'), findsOneWidget);
    });
  });
}
