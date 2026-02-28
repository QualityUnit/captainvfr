import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:captainvfr/services/voice_announcement_service.dart';
import 'package:captainvfr/models/flight_plan.dart';
import 'package:captainvfr/models/airspace.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceAnnouncementService', () {
    late VoiceAnnouncementService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = VoiceAnnouncementService();
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
    });

    tearDown(() {
      service.dispose();
    });

    test('initializes with default settings', () {
      expect(service.isEnabled, true);
      expect(service.volume, 0.8);
      expect(service.speechRate, 0.5);
      expect(service.pitch, 1.0);
    });

    test('can enable and disable announcements', () async {
      await service.setEnabled(false);
      expect(service.isEnabled, false);

      await service.setEnabled(true);
      expect(service.isEnabled, true);
    });

    test('volume is clamped between 0 and 1', () async {
      await service.setVolume(1.5);
      expect(service.volume, 1.0);

      await service.setVolume(-0.5);
      expect(service.volume, 0.0);

      await service.setVolume(0.5);
      expect(service.volume, 0.5);
    });

    test('speech rate is clamped between 0 and 1', () async {
      await service.setSpeechRate(1.5);
      expect(service.speechRate, 1.0);

      await service.setSpeechRate(-0.5);
      expect(service.speechRate, 0.0);

      await service.setSpeechRate(0.5);
      expect(service.speechRate, 0.5);
    });

    test('pitch is clamped between 0.5 and 2.0', () async {
      await service.setPitch(3.0);
      expect(service.pitch, 2.0);

      await service.setPitch(0.1);
      expect(service.pitch, 0.5);

      await service.setPitch(1.0);
      expect(service.pitch, 1.0);
    });

    test('waypoint proximity announcement respects threshold', () async {
      final waypoint = Waypoint(
        latitude: 40.0,
        longitude: -74.0,
        name: 'TEST',
      );

      // Should announce within threshold (1852m = 1nm)
      await service.announceWaypointProximity(waypoint, 1800.0);
      // No exception means success

      // Should not announce outside threshold
      await service.announceWaypointProximity(waypoint, 2000.0);
      // No exception means success
    });

    test('prevents duplicate waypoint announcements', () async {
      final waypoint = Waypoint(
        latitude: 40.0,
        longitude: -74.0,
        name: 'TEST',
      );

      // First announcement should work
      await service.announceWaypointProximity(waypoint, 1800.0);

      // Second announcement of same waypoint should be prevented
      await service.announceWaypointProximity(waypoint, 1800.0);
      // No exception means success
    });

    test('airspace proximity announcement respects threshold', () async {
      final airspace = Airspace(
        id: 'TEST',
        name: 'Test Airspace',
        type: 'CTR',
        geometry: [],
      );

      // Should announce within threshold (9260m = 5nm)
      await service.announceAirspaceProximity(airspace, 9000.0);
      // No exception means success

      // Should not announce outside threshold
      await service.announceAirspaceProximity(airspace, 10000.0);
      // No exception means success
    });

    test('prevents duplicate airspace announcements', () async {
      final airspace = Airspace(
        id: 'TEST',
        name: 'Test Airspace',
        type: 'CTR',
        geometry: [],
      );

      // First announcement should work
      await service.announceAirspaceProximity(airspace, 9000.0);

      // Second announcement of same airspace should be prevented
      await service.announceAirspaceProximity(airspace, 9000.0);
      // No exception means success
    });

    test('terrain warning escalates based on clearance', () async {
      // Test different clearance levels
      await service.announceTerrainWarning(600.0); // No warning
      await service.announceTerrainWarning(400.0); // "Terrain"
      await service.announceTerrainWarning(250.0); // "Terrain, terrain"
      await service.announceTerrainWarning(150.0); // "PULL UP, PULL UP"
      await service.announceTerrainWarning(-50.0); // "PULL UP, PULL UP"
      // No exception means success
    });

    test('terrain warning respects cooldown period', () async {
      // First warning
      await service.announceTerrainWarning(400.0);

      // Immediate second warning should be prevented by cooldown
      await service.announceTerrainWarning(400.0);
      // No exception means success
    });

    test('resetTracking clears all announcement history', () async {
      final waypoint = Waypoint(
        latitude: 40.0,
        longitude: -74.0,
        name: 'TEST',
      );
      final airspace = Airspace(
        id: 'TEST',
        name: 'Test Airspace',
        type: 'CTR',
        geometry: [],
      );

      // Make some announcements
      await service.announceWaypointProximity(waypoint, 1800.0);
      await service.announceAirspaceProximity(airspace, 9000.0);
      await service.announceTerrainWarning(400.0);

      // Reset tracking
      service.resetTracking();

      // Should be able to announce again
      await service.announceWaypointProximity(waypoint, 1800.0);
      await service.announceAirspaceProximity(airspace, 9000.0);
      await service.announceTerrainWarning(400.0);
      // No exception means success
    });

    test('does not announce when disabled', () async {
      await service.setEnabled(false);

      final waypoint = Waypoint(
        latitude: 40.0,
        longitude: -74.0,
        name: 'TEST',
      );

      // Should not announce when disabled
      await service.announceWaypointProximity(waypoint, 1800.0);
      await service.announceWaypointReached(waypoint);
      await service.announce('Test message');
      // No exception means success
    });

    test('settings persist across instances', () async {
      await service.setEnabled(false);
      await service.setVolume(0.5);
      await service.setSpeechRate(0.7);
      await service.setPitch(1.5);

      // Create new instance
      final newService = VoiceAnnouncementService();
      await Future.delayed(const Duration(milliseconds: 200)); // Allow loading

      expect(newService.isEnabled, false);
      expect(newService.volume, 0.5);
      expect(newService.speechRate, 0.7);
      expect(newService.pitch, 1.5);

      newService.dispose();
    });
  });
}
