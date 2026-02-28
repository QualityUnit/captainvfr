import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:captainvfr/widgets/emergency_panel.dart';
import 'package:captainvfr/services/flight_service.dart';
import 'package:captainvfr/services/airport_service.dart';
import 'package:captainvfr/services/display_mode_service.dart';
import 'package:captainvfr/models/flight_point.dart';
import 'package:captainvfr/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Mock services
class MockFlightService extends ChangeNotifier implements FlightService {
  @override
  List<FlightPoint> get flightPath => [
    FlightPoint(
      latitude: 40.0,
      longitude: -74.0,
      altitude: 1000.0,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      speed: 120.0,
      heading: 270.0,
    ),
  ];
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAirportService implements AirportService {
  @override
  Future<List<dynamic>> getAirportsInBounds(dynamic sw, dynamic ne) async {
    return [];
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDisplayModeService extends ChangeNotifier implements DisplayModeService {
  @override
  Color getCriticalColor() => Colors.red;
  
  @override
  Color getPrimaryTextColor() => Colors.white;
  
  @override
  Color getSuccessColor() => Colors.green;
  
  @override
  Color getWarningColor() => Colors.yellow;
  
  @override
  TextStyle getLabelStyle() => const TextStyle(fontSize: 12);
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EmergencyPanel', () {
    late MockFlightService flightService;
    late MockAirportService airportService;
    late MockDisplayModeService displayModeService;

    setUp(() {
      flightService = MockFlightService();
      airportService = MockAirportService();
      displayModeService = MockDisplayModeService();
    });

    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<FlightService>.value(value: flightService),
            Provider<AirportService>.value(value: airportService),
            ChangeNotifierProvider<DisplayModeService>.value(value: displayModeService),
          ],
          child: Scaffold(
            body: EmergencyPanel(
              onClose: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('displays emergency header', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays emergency frequency', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY FREQUENCY'), findsOneWidget);
      expect(find.text('121.5 MHz'), findsOneWidget);
      expect(find.text('International Distress Frequency'), findsOneWidget);
    });

    testWidgets('displays current position', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('CURRENT POSITION'), findsOneWidget);
      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);
      expect(find.textContaining('Altitude:'), findsOneWidget);
    });

    testWidgets('displays nearest airports section', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('NEAREST AIRPORTS'), findsOneWidget);
    });

    testWidgets('displays emergency checklist', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY CHECKLIST'), findsOneWidget);
      expect(find.text('1. Aviate - Maintain aircraft control'), findsOneWidget);
      expect(find.text('2. Navigate - Fly to nearest suitable airport'), findsOneWidget);
      expect(find.text('3. Communicate - Contact ATC on 121.5 MHz'), findsOneWidget);
      expect(find.text('4. Squawk 7700 (Emergency transponder code)'), findsOneWidget);
      expect(find.text('5. Prepare for emergency landing if needed'), findsOneWidget);
    });

    testWidgets('has copy buttons for frequency and position', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('COPY FREQUENCY'), findsOneWidget);
      expect(find.text('COPY POSITION'), findsOneWidget);
    });

    testWidgets('close button calls onClose callback', (WidgetTester tester) async {
      bool closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<FlightService>.value(value: flightService),
              Provider<AirportService>.value(value: airportService),
              ChangeNotifierProvider<DisplayModeService>.value(value: displayModeService),
            ],
            child: Scaffold(
              body: EmergencyPanel(
                onClose: () {
                  closeCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(closeCalled, true);
    });

    testWidgets('has red theme for urgency', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the main container
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EmergencyPanel),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      // Should have red-ish color for emergency
      expect(decoration.color!.red, greaterThan(200));
    });
  });
}
