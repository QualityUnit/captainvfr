import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:captainvfr/widgets/flight_tracking_panel.dart';
import 'package:captainvfr/services/flight_service.dart';
import 'package:captainvfr/services/aircraft_settings_service.dart';
import 'package:captainvfr/services/barometer_service.dart';
import 'package:captainvfr/services/heading_service.dart';
import 'package:captainvfr/services/settings_service.dart';
import 'package:captainvfr/services/flight_plan_service.dart';
import 'package:captainvfr/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for the services
@GenerateMocks([
  FlightService,
  AircraftSettingsService,
  BarometerService,
  HeadingService,
  SettingsService,
  FlightPlanService,
])
import 'flight_tracking_panel_test.mocks.dart';

void main() {
  group('FlightTrackingPanel Widget Tests', () {
    late MockFlightService mockFlightService;
    late MockAircraftSettingsService mockAircraftSettingsService;
    late MockBarometerService mockBarometerService;
    late MockHeadingService mockHeadingService;
    late MockSettingsService mockSettingsService;
    late MockFlightPlanService mockFlightPlanService;

    setUp(() {
      mockFlightService = MockFlightService();
      mockAircraftSettingsService = MockAircraftSettingsService();
      mockBarometerService = MockBarometerService();
      mockHeadingService = MockHeadingService();
      mockSettingsService = MockSettingsService();
      mockFlightPlanService = MockFlightPlanService();

      // Setup default mock behaviors
      when(mockFlightService.isTracking).thenReturn(false);
      when(mockFlightService.currentSpeed).thenReturn(0.0);
      when(mockFlightService.barometricAltitude).thenReturn(0.0);
      when(mockFlightService.currentHeading).thenReturn(0.0);
      when(mockFlightService.flightPath).thenReturn([]);
      when(mockFlightService.flights).thenReturn([]);

      when(mockAircraftSettingsService.selectedAircraft).thenReturn(null);
      when(mockAircraftSettingsService.aircrafts).thenReturn([]);

      when(mockHeadingService.currentHeading).thenReturn(0.0);
      when(mockHeadingService.isRunning).thenReturn(false);
      when(mockHeadingService.hasError).thenReturn(false);

      when(mockSettingsService.units).thenReturn('metric');

      when(mockFlightPlanService.currentFlightPlan).thenReturn(null);
      when(mockFlightPlanService.isPlanning).thenReturn(false);
    });

    Widget createTestWidget({Widget? child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FlightService>.value(value: mockFlightService),
          ChangeNotifierProvider<AircraftSettingsService>.value(value: mockAircraftSettingsService),
          ChangeNotifierProvider<BarometerService>.value(value: mockBarometerService),
          ChangeNotifierProvider<HeadingService>.value(value: mockHeadingService),
          ChangeNotifierProvider<SettingsService>.value(value: mockSettingsService),
          ChangeNotifierProvider<FlightPlanService>.value(value: mockFlightPlanService),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
          ],
          home: Scaffold(
            body: Stack(
              children: [
                child ?? const FlightTrackingPanel(),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('Panel initially shows in collapsed state', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check that the panel exists
      expect(find.byType(FlightTrackingPanel), findsOneWidget);

      // Check that the handle is visible with compass icon
      expect(find.byIcon(Icons.explore), findsOneWidget);

      // Check that the expanded content is not visible
      expect(find.text('ALT'), findsNothing);
      expect(find.text('SPEED'), findsNothing);
    });

    testWidgets('Panel expands when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the handle
      final handleFinder = find.byIcon(Icons.explore);
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      // Check that expanded content is now visible
      expect(find.text('ALT'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);
    });

    testWidgets('Panel collapses when expanded and tapped again', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand the panel
      final handleFinder = find.byIcon(Icons.explore);
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      // Verify it's expanded
      expect(find.text('ALT'), findsOneWidget);

      // Collapse the panel
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      // Verify it's collapsed
      expect(find.text('ALT'), findsNothing);
    });

    testWidgets('Panel shows tracking indicator when tracking is active', (WidgetTester tester) async {
      // Setup tracking state
      when(mockFlightService.isTracking).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for tracking text
      expect(find.text('TRACKING'), findsOneWidget);
    });

    testWidgets('Panel shows FLIGHT DATA when not tracking', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for default text
      expect(find.text('FLIGHT DATA'), findsOneWidget);
    });

    testWidgets('Panel can be dragged to expand', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the handle
      final handleFinder = find.byIcon(Icons.explore);
      
      // Perform upward drag
      await tester.drag(handleFinder, const Offset(0, -100));
      await tester.pumpAndSettle();

      // Check that expanded content is now visible
      expect(find.text('ALT'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);
    });

    testWidgets('Panel can be dragged to collapse', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand first
      final handleFinder = find.byIcon(Icons.explore);
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      // Verify it's expanded
      expect(find.text('ALT'), findsOneWidget);

      // Perform downward drag
      await tester.drag(handleFinder, const Offset(0, 100));
      await tester.pumpAndSettle();

      // Check that expanded content is hidden
      expect(find.text('ALT'), findsNothing);
    });

    testWidgets('Tracking button appears when panel is expanded', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially, tracking button should not be visible
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // Expand the panel
      final handleFinder = find.byIcon(Icons.explore);
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      // Now tracking button should be visible
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('Tracking button shows stop icon when tracking', (WidgetTester tester) async {
      when(mockFlightService.isTracking).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand the panel
      final handleFinder = find.byIcon(Icons.explore);
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      // Should show stop icon when tracking
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('Panel respects safe area padding', (WidgetTester tester) async {
      // Test with safe area padding
      final mediaQuery = MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 34.0), // iPhone X style safe area
        ),
        child: const FlightTrackingPanel(),
      );

      await tester.pumpWidget(createTestWidget(child: mediaQuery));
      await tester.pumpAndSettle();

      // Panel should still be visible and functional
      expect(find.byType(FlightTrackingPanel), findsOneWidget);
      expect(find.byIcon(Icons.explore), findsOneWidget);
    });
  });
}