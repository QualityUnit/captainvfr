# Coding Conventions

This document is the authoritative reference for coding standards in Captain VFR. Both human developers and AI coding agents must follow these rules.

## Naming Conventions

### Files

**Dart source files**: `snake_case.dart`
- Examples: `flight_service.dart`, `airport_marker.dart`, `map_screen.dart`

**Generated files**: `*.g.dart` suffix for code generation output
- Examples: `aircraft.g.dart`, `flight_plan.g.dart`

**Test files**: `*_test.dart` suffix, co-located with source or in `test/` directory
- Examples: `flight_service_test.dart`, `csv_parsing_test.dart`

### Variables and Functions

**camelCase** for all variables, functions, and methods.
```dart
final airportService = AirportService();
double calculateDistance(LatLng from, LatLng to) { }
```

### Classes, Types, and Enums

**PascalCase** for classes, types, enums, and type parameters.
```dart
class FlightService extends ChangeNotifier { }
enum FlightPhase { preflight, taxi, takeoff, cruise, landing }
```

### Constants

**lowerCamelCase** for constants (Dart convention, not UPPER_SNAKE_CASE).
```dart
const double maxDistanceKm = 100.0;
const String baseUrl = 'https://api.example.com';
```

### Private Members

Prefix with underscore for private members.
```dart
class AirportService {
  List<Airport> _airports = [];
  bool _isLoading = false;
}
```

## Import Organization

Order imports in four groups, separated by blank lines:

1. Dart SDK imports (`dart:*`)
2. Flutter framework imports (`package:flutter/*`)
3. External package imports (`package:*`)
4. Internal imports (relative paths)

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/airport.dart';
import '../services/cache_service.dart';
import 'tiled_data_loader.dart';
```

Use `as` prefix for namespace conflicts (e.g., `dart:math as math`).

## Code Organization

### Service Classes

Services use singleton pattern with private constructor:
```dart
class AirportService {
  static final AirportService _instance = AirportService._internal();
  factory AirportService() => _instance;
  AirportService._internal();
}
```

Services that notify UI extend `ChangeNotifier`:
```dart
class FlightService extends ChangeNotifier {
  void updateState() {
    // ... update internal state
    notifyListeners();
  }
}
```

### Model Classes

Models use `json_serializable` for JSON serialization:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'airport.g.dart';

@JsonSerializable()
class Airport {
  final String icao;
  final String name;
  
  Airport({required this.icao, required this.name});
  
  factory Airport.fromJson(Map<String, dynamic> json) => _$AirportFromJson(json);
  Map<String, dynamic> toJson() => _$AirportToJson(this);
}
```

Run `dart run build_runner build` to generate `.g.dart` files.

### Hive Adapters

Models persisted to Hive use type adapters:
```dart
import 'package:hive/hive.dart';

part 'flight.g.dart';

@HiveType(typeId: 0)
class Flight {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime startTime;
}
```

Register adapters in `main.dart`:
```dart
Hive.registerAdapter(FlightAdapter());
```

## Error Handling

### Service Methods

Return `null` or empty collections on error, log with `debugPrint`:
```dart
Future<List<Airport>> fetchAirports() async {
  try {
    final response = await http.get(url);
    return parseAirports(response.body);
  } catch (e) {
    debugPrint('Error fetching airports: $e');
    return [];
  }
}
```

### UI Error Display

Show user-friendly messages via `ScaffoldMessenger`:
```dart
try {
  await service.performAction();
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.errorMessage)),
    );
  }
}
```

### Platform-Specific Code

Check platform before using platform-specific APIs:
```dart
if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
  final status = await Permission.location.request();
}
```

Return `null` for unsupported platforms:
```dart
class BarometerService {
  Stream<double>? get pressureStream {
    if (kIsWeb) return null;
    return _pressureController.stream;
  }
}
```

## Internationalization

Use `AppLocalizations` for all user-facing strings:
```dart
Text(AppLocalizations.of(context)!.flightPlanTitle)
```

Add new strings to `lib/l10n/app_en.arb` (English master), then translate to other languages.

## State Management

### Provider Pattern

Provide services at app root in `main.dart`:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => FlightService()),
    Provider(create: (_) => AirportService()),
  ],
  child: MyApp(),
)
```

Consume in widgets:
```dart
final flightService = Provider.of<FlightService>(context);
// or
final flightService = context.watch<FlightService>();
```

### StatefulWidget Lifecycle

Dispose subscriptions and controllers:
```dart
@override
void dispose() {
  _subscription?.cancel();
  _controller.dispose();
  super.dispose();
}
```

Check `mounted` before calling `setState`:
```dart
void updateData() async {
  final data = await fetchData();
  if (mounted) {
    setState(() => _data = data);
  }
}
```

## Performance

### Avoid Rebuilds

Use `const` constructors where possible:
```dart
const Text('Static text')
const SizedBox(height: 16)
```

Use `Consumer` or `Selector` to limit rebuild scope:
```dart
Consumer<FlightService>(
  builder: (context, service, child) => Text(service.altitude.toString()),
)
```

### Lazy Loading

Load data on-demand, not in constructor:
```dart
class AirportService {
  Future<void> loadAirports() async {
    if (_airports.isNotEmpty) return; // Already loaded
    _airports = await _fetchAirports();
  }
}
```

### Spatial Indexing

Use spatial indexing for large datasets:
```dart
final nearbyAirports = _airports.where((a) => 
  a.position.distanceTo(center) < radiusKm
).toList();
```

## Testing Conventions

### Test File Structure

Mirror source structure in `test/` directory:
```
lib/services/flight_service.dart
test/services/flight_service_test.dart
```

### Test Naming

Use `group` and `test` with descriptive names:
```dart
void main() {
  group('FlightService', () {
    test('should start flight tracking', () {
      // Arrange
      final service = FlightService();
      
      // Act
      service.startFlight();
      
      // Assert
      expect(service.isTracking, true);
    });
  });
}
```

### Mocking

Use `mockito` for service mocks:
```dart
@GenerateMocks([AirportService])
void main() {
  test('should fetch airports', () async {
    final mock = MockAirportService();
    when(mock.fetchAirports()).thenAnswer((_) async => []);
  });
}
```

## Git Workflow

### Branch Naming

`<type>/<short-description>` where type is:
```
feat/     - New feature
fix/      - Bug fix
refactor/ - Code restructuring
docs/     - Documentation
chore/    - Maintenance (deps, config)
test/     - Test additions
```

Examples: `feat/terrain-warnings`, `fix/cache-invalidation`

### Commit Messages

[Conventional Commits](https://www.conventionalcommits.org/) format:
```
feat: add terrain warning overlay
fix: handle null weather data
refactor: extract flight calculations to separate class
docs: update architecture documentation
chore: upgrade flutter_map to 8.2.1
test: add flight service altitude tests
```

### PR Guidelines

- Keep PRs focused on single concern
- Include screenshots for UI changes
- Update documentation if architecture changes
- Ensure tests pass before requesting review

## Code Review Standards

### Automated Checks

Before submitting PR:
- Run `flutter analyze` (no errors)
- Run `flutter test` (all tests pass)
- Run `dart format .` (consistent formatting)
- Run `dart run build_runner build` if models changed

### Human Review Focus

Reviewers should focus on:
- **Architecture**: Does this fit the service-oriented pattern?
- **Performance**: Will this cause UI jank or memory leaks?
- **Offline support**: Does this work without network?
- **Platform compatibility**: Tested on iOS/Android/Web?
- **Internationalization**: Are strings translated?
- **Error handling**: Graceful degradation on failure?

### Review Tiers

| Tier | Scope | Required Checks |
|---|---|---|
| **Tier 1** (low) | Docs, comments, constants | analyze, format |
| **Tier 2** (medium) | Features, refactors | analyze, format, test |
| **Tier 3** (high) | Core services, data processing | analyze, format, test, manual-review |

Core services: `flight_service.dart`, `cache_service.dart`, `tiled_data_loader.dart`, `terrain_elevation_service.dart`
