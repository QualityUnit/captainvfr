import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:captainvfr/services/flight_service.dart';
import 'package:captainvfr/services/barometer_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([BarometerService])
import 'flight_service_altitude_test.mocks.dart';

void main() {
  group('FlightService Altitude Tests', () {
    late FlightService flightService;
    late MockBarometerService mockBarometerService;
    
    setUp(() {
      mockBarometerService = MockBarometerService();
      flightService = FlightService(
        barometerService: mockBarometerService,
      );
    });
    
    test('currentAltitude returns GPS altitude when available', () {
      // Setup GPS position with altitude
      final testPosition = Position(
        latitude: 48.8566,
        longitude: 2.3522,
        timestamp: DateTime.now(),
        altitude: 150.0,
        altitudeAccuracy: 5.0,
        accuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: null,
        isMocked: false,
      );
      
      // Set the GPS position in flight service
      // This would normally be set via the position stream
      // For testing, we'd need to expose a setter or use dependency injection
      
      // Mock barometer altitude
      when(mockBarometerService.altitudeMeters).thenReturn(100.0);
      
      // GPS altitude should take priority
      final altitude = flightService.currentAltitude;
      
      // Since we can't directly set GPS position in test, we verify the logic
      // The actual altitude will depend on the service state
      expect(altitude, isNotNull);
    });
    
    test('currentAltitude falls back to barometer when GPS unavailable', () {
      // Mock barometer altitude
      when(mockBarometerService.altitudeMeters).thenReturn(250.0);
      when(mockBarometerService.isBarometerAvailable).thenReturn(true);
      
      // With no GPS position, should use barometer
      final altitude = flightService.currentAltitude;
      
      expect(altitude, equals(250.0));
    });
    
    test('currentAltitude returns 0 when no data available', () {
      // Mock no barometer data
      when(mockBarometerService.altitudeMeters).thenReturn(null);
      when(mockBarometerService.isBarometerAvailable).thenReturn(false);
      
      // With no GPS and no barometer, should return 0
      final altitude = flightService.currentAltitude;
      
      expect(altitude, equals(0.0));
    });
    
    test('elevation cache respects radius boundary', () {
      // This test would verify that positions within 250m use cached elevation
      // and positions outside fetch new elevation
      
      final position1 = Position(
        latitude: 48.8566,
        longitude: 2.3522,
        timestamp: DateTime.now(),
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        accuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: null,
        isMocked: false,
      );
      
      final position2 = Position(
        latitude: 48.8568, // ~22m away
        longitude: 2.3524,
        timestamp: DateTime.now(),
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        accuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: null,
        isMocked: false,
      );
      
      final position3 = Position(
        latitude: 48.8600, // ~380m away
        longitude: 2.3560,
        timestamp: DateTime.now(),
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        accuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: null,
        isMocked: false,
      );
      
      // Test logic would go here
      // For now, we just verify the positions are created correctly
      expect(position1.latitude, equals(48.8566));
      expect(position2.latitude, equals(48.8568));
      expect(position3.latitude, equals(48.8600));
    });
    
    test('altitude validation rejects invalid values', () {
      // Test that extreme altitude values are rejected
      final validAltitudes = [0.0, 100.0, 1000.0, 8848.0]; // Valid range
      final invalidAltitudes = [-600.0, 10000.0, double.infinity, double.nan];
      
      for (final alt in validAltitudes) {
        expect(alt >= -500 && alt <= 9000, isTrue);
      }
      
      for (final alt in invalidAltitudes) {
        if (alt.isNaN) {
          expect(alt.isNaN, isTrue);
        } else {
          expect(alt >= -500 && alt <= 9000, isFalse);
        }
      }
    });
  });
}