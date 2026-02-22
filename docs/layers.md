# Layer Boundaries

Captain VFR does not currently enforce strict architectural layers. The codebase follows a service-oriented architecture where UI components directly consume services. This document proposes a layered structure to improve maintainability as the project grows.

## Current Organization

The existing directory structure provides implicit boundaries:

```
lib/
├── screens/          # Presentation layer (UI)
├── widgets/          # Presentation layer (reusable UI)
├── services/         # Business logic layer
├── models/           # Domain layer
├── utils/            # Cross-cutting utilities
├── constants/        # Cross-cutting constants
├── config/           # Configuration
└── adapters/         # Infrastructure (serialization)
```

**Observed patterns:**
- Screens and widgets depend on services and models
- Services depend on models and other services
- Models have no dependencies (pure data)
- Utils and constants are used everywhere

**Issues with current structure:**
- No enforcement of dependency direction
- Services can become tightly coupled
- Difficult to test UI without services
- Business logic can leak into widgets

## Proposed Layer Structure

### Layer 1: Domain (Core)

**Purpose**: Pure business entities and rules, no external dependencies.

**Contents**:
- `lib/models/` - Domain entities (Airport, Flight, Airspace, etc.)
- Domain logic that doesn't require external services

**Rules**:
- No dependencies on other layers
- No Flutter framework imports
- No platform-specific code
- Pure Dart classes with business rules

**Example**:
```dart
// lib/models/flight.dart
class Flight {
  final String id;
  final DateTime startTime;
  final List<FlightPoint> points;
  
  Duration get duration => /* calculate from points */;
  double get totalDistance => /* calculate from points */;
}
```

### Layer 2: Application (Services)

**Purpose**: Business logic, use cases, and orchestration.

**Contents**:
- `lib/services/` - Service classes that implement use cases
- Orchestration of domain entities
- External API integration
- Caching and persistence logic

**Rules**:
- Can depend on Domain layer
- Can depend on Infrastructure layer (adapters)
- Should not depend on Presentation layer
- Should not import Flutter widgets

**Example**:
```dart
// lib/services/flight_service.dart
class FlightService {
  final LocationTracker _locationTracker;
  final FlightRepository _repository;
  
  Future<Flight> startFlight() async {
    final flight = Flight.create();
    await _locationTracker.start();
    return flight;
  }
}
```

### Layer 3: Presentation (UI)

**Purpose**: User interface and user interaction.

**Contents**:
- `lib/screens/` - Full-page UI components
- `lib/widgets/` - Reusable UI components
- UI state management (Provider, ChangeNotifier)

**Rules**:
- Can depend on Application layer (services)
- Can depend on Domain layer (models)
- Should not contain business logic
- Should delegate to services for data operations

**Example**:
```dart
// lib/screens/map_screen.dart
class MapScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    final flightService = context.watch<FlightService>();
    return FlightMap(flight: flightService.currentFlight);
  }
}
```

### Layer 4: Infrastructure (Cross-cutting)

**Purpose**: Technical concerns that support other layers.

**Contents**:
- `lib/adapters/` - Serialization adapters (Hive, JSON)
- `lib/utils/` - Helper functions (calculations, formatting)
- `lib/constants/` - App-wide constants
- `lib/config/` - Configuration and environment

**Rules**:
- Can be used by any layer
- Should not contain business logic
- Should be stateless and pure functions where possible

**Example**:
```dart
// lib/utils/geo_calculations.dart
double calculateDistance(LatLng from, LatLng to) {
  // Haversine formula implementation
}
```

## Dependency Direction

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│      (screens, widgets)             │
└──────────────┬──────────────────────┘
               │ depends on
               ▼
┌─────────────────────────────────────┐
│        Application Layer            │
│          (services)                 │
└──────────────┬──────────────────────┘
               │ depends on
               ▼
┌─────────────────────────────────────┐
│          Domain Layer               │
│          (models)                   │
└─────────────────────────────────────┘
               ▲
               │ used by all
┌──────────────┴──────────────────────┐
│      Infrastructure Layer           │
│   (adapters, utils, constants)      │
└─────────────────────────────────────┘
```

**Key principle**: Dependencies flow downward. Lower layers never import from higher layers.

## Migration Strategy

To evolve toward this layered architecture:

### Phase 1: Enforce Domain Purity
1. Audit `lib/models/` for service dependencies
2. Extract business logic from services into domain models
3. Remove Flutter imports from models
4. Add lint rules to prevent upward dependencies

### Phase 2: Separate Service Concerns
1. Split large services (e.g., `flight_service.dart`) into focused services
2. Extract data access into repository pattern
3. Move API clients to separate classes
4. Introduce service interfaces for testing

### Phase 3: Clean Presentation Layer
1. Extract business logic from widgets into services
2. Use ViewModels or Controllers for complex UI state
3. Limit Provider usage to service injection, not state
4. Move UI calculations to services

### Phase 4: Formalize Infrastructure
1. Create `lib/infrastructure/` directory
2. Move adapters, utils, constants into infrastructure
3. Define clear contracts for cross-cutting concerns
4. Document when to use infrastructure vs domain logic

## Testing Strategy by Layer

### Domain Layer Tests
- Unit tests for business logic
- No mocking required (pure functions)
- Fast execution

```dart
test('Flight duration calculation', () {
  final flight = Flight(points: [/* test data */]);
  expect(flight.duration, Duration(hours: 2));
});
```

### Application Layer Tests
- Unit tests with mocked dependencies
- Test service orchestration
- Test error handling and edge cases

```dart
test('FlightService starts tracking', () async {
  final mockTracker = MockLocationTracker();
  final service = FlightService(tracker: mockTracker);
  
  await service.startFlight();
  
  verify(mockTracker.start()).called(1);
});
```

### Presentation Layer Tests
- Widget tests for UI components
- Integration tests for user flows
- Mock services, not domain models

```dart
testWidgets('MapScreen displays flight', (tester) async {
  final mockService = MockFlightService();
  when(mockService.currentFlight).thenReturn(testFlight);
  
  await tester.pumpWidget(
    Provider.value(value: mockService, child: MapScreen()),
  );
  
  expect(find.text('Flight Active'), findsOneWidget);
});
```

## Benefits of Layered Architecture

1. **Testability**: Each layer can be tested independently
2. **Maintainability**: Clear boundaries reduce coupling
3. **Scalability**: Easy to add features without breaking existing code
4. **Team collaboration**: Developers can work on different layers in parallel
5. **Platform independence**: Domain layer can be shared across platforms

## Current Violations to Address

Based on code analysis, these patterns violate proposed layers:

1. **Services importing widgets**: Some services import Flutter widgets for UI logic
2. **Models with service dependencies**: Some models call services directly
3. **Widgets with business logic**: Complex calculations in widget build methods
4. **Circular dependencies**: Services depending on each other without interfaces

Addressing these will require gradual refactoring, prioritizing high-impact areas first (e.g., `flight_service.dart`, `map_screen.dart`).
