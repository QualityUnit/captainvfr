import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:captainvfr/widgets/flight_hud.dart';
import 'package:captainvfr/services/flight_service.dart';
import 'package:captainvfr/services/display_mode_service.dart';
import 'package:captainvfr/services/settings_service.dart';

// Mock services
class MockFlightService extends ChangeNotifier implements FlightService {
  @override
  List<dynamic> get flightPath => [];
  
  @override
  bool get isTracking => false;
  
  @override
  double get currentSpeed => 120.0;
  
  @override
  double? get currentHeading => 270.0;
  
  @override
  double get verticalSpeed => 500.0;
  
  @override
  List<dynamic> get flightSegments => [];
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDisplayModeService extends ChangeNotifier implements DisplayModeService {
  @override
  Color getPrimaryTextColor() => Colors.white;
  
  @override
  Color getSuccessColor() => Colors.green;
  
  @override
  Color getWarningColor() => Colors.yellow;
  
  @override
  Color getCriticalColor() => Colors.red;
  
  @override
  TextStyle getLabelStyle() => const TextStyle(fontSize: 12, color: Colors.white70);
  
  @override
  TextStyle getCriticalDataStyle() => const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white);
  
  @override
  TextStyle getSecondaryDataStyle() => const TextStyle(fontSize: 18, color: Colors.white);
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsService extends ChangeNotifier implements SettingsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FlightHUD', () {
    late MockFlightService flightService;
    late MockDisplayModeService displayModeService;
    late MockSettingsService settingsService;

    setUp(() {
      flightService = MockFlightService();
      displayModeService = MockDisplayModeService();
      settingsService = MockSettingsService();
    });

    Widget createTestWidget({required bool isExpanded}) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<FlightService>.value(value: flightService),
            ChangeNotifierProvider<DisplayModeService>.value(value: displayModeService),
            ChangeNotifierProvider<SettingsService>.value(value: settingsService),
          ],
          child: Scaffold(
            body: FlightHUD(
              isExpanded: isExpanded,
              onToggle: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('displays collapsed view correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isExpanded: false));
      await tester.pumpAndSettle();

      // Check for collapsed view elements
      expect(find.text('ALT'), findsOneWidget);
      expect(find.text('SPD'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('displays expanded view correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isExpanded: true));
      await tester.pumpAndSettle();

      // Check for expanded view elements
      expect(find.text('ALTITUDE'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);
      expect(find.text('HEADING'), findsOneWidget);
      expect(find.text('V/S'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('BAT'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('toggles between collapsed and expanded', (WidgetTester tester) async {
      bool isExpanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<FlightService>.value(value: flightService),
              ChangeNotifierProvider<DisplayModeService>.value(value: displayModeService),
              ChangeNotifierProvider<SettingsService>.value(value: settingsService),
            ],
            child: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: FlightHUD(
                    isExpanded: isExpanded,
                    onToggle: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('ALT'), findsOneWidget);
      expect(find.text('ALTITUDE'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(FlightHUD));
      await tester.pumpAndSettle();

      // Now expanded
      expect(find.text('ALTITUDE'), findsOneWidget);
      expect(find.text('ALT'), findsNothing);
    });

    testWidgets('displays flight data correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isExpanded: true));
      await tester.pumpAndSettle();

      // Check for speed value (120 kts from mock)
      expect(find.text('120'), findsOneWidget);
      
      // Check for heading value (270° from mock)
      expect(find.text('270°'), findsOneWidget);
      
      // Check for vertical speed (500 fpm from mock)
      expect(find.text('+500'), findsOneWidget);
    });

    testWidgets('shows time in UTC and local', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isExpanded: true));
      await tester.pumpAndSettle();

      // Check for UTC and LOCAL labels
      expect(find.textContaining('UTC'), findsOneWidget);
      expect(find.textContaining('LOCAL'), findsOneWidget);
    });

    testWidgets('has proper styling and layout', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isExpanded: true));
      await tester.pumpAndSettle();

      // Check for container with proper decoration
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FlightHUD),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.boxShadow, isNotNull);
    });
  });
}
