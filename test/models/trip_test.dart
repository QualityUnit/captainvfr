import 'package:flutter_test/flutter_test.dart';
import 'package:captainvfr/models/trip.dart';
import 'package:captainvfr/models/flight_plan.dart';

void main() {
  group('Trip Model', () {
    test('creates trip with required fields', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        createdAt: DateTime(2024, 1, 1),
        flightPlanIds: ['plan-1', 'plan-2'],
      );

      expect(trip.id, 'trip-1');
      expect(trip.name, 'Test Trip');
      expect(trip.createdAt, DateTime(2024, 1, 1));
      expect(trip.flightPlanIds, ['plan-1', 'plan-2']);
      expect(trip.modifiedAt, isNull);
      expect(trip.aircraftId, isNull);
    });

    test('creates trip with optional fields', () {
      final modifiedDate = DateTime(2024, 1, 2);
      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: modifiedDate,
        flightPlanIds: ['plan-1'],
        aircraftId: 'aircraft-1',
      );

      expect(trip.modifiedAt, modifiedDate);
      expect(trip.aircraftId, 'aircraft-1');
    });

    test('calculates total distance correctly', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        createdAt: DateTime.now(),
        flightPlanIds: ['plan-1', 'plan-2', 'plan-3'],
      );

      final flightPlans = [
        FlightPlan(
          id: 'plan-1',
          name: 'Leg 1',
          createdAt: DateTime.now(),
          waypoints: [
            Waypoint(
              id: 'wp1',
              latitude: 0.0,
              longitude: 0.0,
              altitude: 1000,
              name: 'Start',
            ),
            Waypoint(
              id: 'wp2',
              latitude: 1.0,
              longitude: 1.0,
              altitude: 2000,
              name: 'End',
            ),
          ],
        ),
        FlightPlan(
          id: 'plan-2',
          name: 'Leg 2',
          createdAt: DateTime.now(),
          waypoints: [
            Waypoint(
              id: 'wp3',
              latitude: 1.0,
              longitude: 1.0,
              altitude: 2000,
              name: 'Start',
            ),
            Waypoint(
              id: 'wp4',
              latitude: 2.0,
              longitude: 2.0,
              altitude: 3000,
              name: 'End',
            ),
          ],
        ),
        // plan-3 is not in the list, simulating a missing plan
        FlightPlan(
          id: 'plan-4',
          name: 'Not in trip',
          createdAt: DateTime.now(),
          waypoints: [],
        ),
      ];

      final totalDistance = trip.getTotalDistance(flightPlans);
      
      // Should only include plan-1 and plan-2
      expect(totalDistance, greaterThan(0));
      expect(totalDistance, lessThan(200)); // Roughly 2 * 60 NM for 1 degree changes
    });

    test('calculates total flight time correctly', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        createdAt: DateTime.now(),
        flightPlanIds: ['plan-1', 'plan-2'],
      );

      final flightPlans = [
        FlightPlan(
          id: 'plan-1',
          name: 'Leg 1',
          createdAt: DateTime.now(),
          waypoints: [
            Waypoint(
              id: 'wp1',
              latitude: 0.0,
              longitude: 0.0,
              altitude: 1000,
              name: 'Start',
            ),
            Waypoint(
              id: 'wp2',
              latitude: 1.0,
              longitude: 1.0,
              altitude: 2000,
              name: 'End',
            ),
          ],
          cruiseSpeed: 120, // 120 knots
        ),
        FlightPlan(
          id: 'plan-2',
          name: 'Leg 2',
          createdAt: DateTime.now(),
          waypoints: [
            Waypoint(
              id: 'wp3',
              latitude: 1.0,
              longitude: 1.0,
              altitude: 2000,
              name: 'Start',
            ),
            Waypoint(
              id: 'wp4',
              latitude: 2.0,
              longitude: 2.0,
              altitude: 3000,
              name: 'End',
            ),
          ],
          cruiseSpeed: 120,
        ),
      ];

      final totalTime = trip.getTotalFlightTime(flightPlans);
      
      // Should be sum of both flight times
      expect(totalTime, greaterThan(0));
      expect(totalTime, lessThan(120)); // Less than 2 hours for these short distances
    });

    test('handles missing flight plans gracefully', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        createdAt: DateTime.now(),
        flightPlanIds: ['plan-1', 'plan-missing', 'plan-2'],
      );

      final flightPlans = [
        FlightPlan(
          id: 'plan-1',
          name: 'Leg 1',
          createdAt: DateTime.now(),
          waypoints: [],
        ),
        FlightPlan(
          id: 'plan-2',
          name: 'Leg 2',
          createdAt: DateTime.now(),
          waypoints: [],
        ),
      ];

      // Should not throw when plan-missing is not found
      expect(() => trip.getTotalDistance(flightPlans), returnsNormally);
      expect(() => trip.getTotalFlightTime(flightPlans), returnsNormally);
      
      final distance = trip.getTotalDistance(flightPlans);
      final time = trip.getTotalFlightTime(flightPlans);
      
      expect(distance, 0.0);
      expect(time, 0.0);
    });

    test('returns correct leg count', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        createdAt: DateTime.now(),
        flightPlanIds: [],
      );

      expect(trip.legCount, 0);

      trip.flightPlanIds.add('plan-1');
      expect(trip.legCount, 1);

      trip.flightPlanIds.addAll(['plan-2', 'plan-3']);
      expect(trip.legCount, 3);
    });

    test('empty trip returns zero totals', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Empty Trip',
        createdAt: DateTime.now(),
        flightPlanIds: [],
      );

      final flightPlans = <FlightPlan>[];

      expect(trip.getTotalDistance(flightPlans), 0.0);
      expect(trip.getTotalFlightTime(flightPlans), 0.0);
      expect(trip.legCount, 0);
    });
  });
}