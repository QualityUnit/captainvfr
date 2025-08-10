import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import '../l10n/app_localizations.dart';
import '../widgets/sensor_notification_widget.dart';

/// Service to check sensor availability and manage notifications
class SensorAvailabilityService extends ChangeNotifier {
  static final SensorAvailabilityService _instance = SensorAvailabilityService._internal();
  factory SensorAvailabilityService() => _instance;
  SensorAvailabilityService._internal();

  final List<SensorNotificationData> _notifications = [];
  bool _hasCheckedSensors = false;
  
  List<SensorNotificationData> get notifications => List.unmodifiable(_notifications);
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Check all sensors and generate notifications for unavailable ones
  Future<void> checkSensorAvailability(AppLocalizations l10n) async {
    if (_hasCheckedSensors) return;
    _hasCheckedSensors = true;
    
    _notifications.clear();

    // Check platform
    if (kIsWeb) {
      _addWebPlatformNotifications(l10n);
    } else {
      await _checkMobileSensors(l10n);
    }

    if (_notifications.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Add notifications for web platform limitations
  void _addWebPlatformNotifications(AppLocalizations l10n) {
    _notifications.addAll([
      SensorNotificationData(
        id: 'web_accelerometer',
        sensorName: l10n.accelerometerNotAvailable,
        message: l10n.vibrationMeasurementNotSupportedWeb,
        icon: Icons.vibration,
      ),
      SensorNotificationData(
        id: 'web_barometer',
        sensorName: l10n.barometerNotAvailable, 
        message: l10n.altitudePressureSensorsNotAvailableWeb,
        icon: Icons.speed,
      ),
      SensorNotificationData(
        id: 'web_offline_maps',
        sensorName: l10n.offlineMapsNotAvailable,
        message: l10n.offlineMapsNotSupportedWeb,
        icon: Icons.map,
      ),
    ]);
  }

  /// Add notifications for macOS platform limitations
  void _addMacOSNotifications(AppLocalizations l10n) {
    _notifications.addAll([
      SensorNotificationData(
        id: 'macos_accelerometer',
        sensorName: l10n.accelerometerNotAvailable,
        message: l10n.vibrationMeasurementNotSupported('macOS'),
        icon: Icons.vibration,
      ),
      SensorNotificationData(
        id: 'macos_barometer',
        sensorName: l10n.barometerNotAvailable, 
        message: l10n.altitudeSensorsNotAvailable('macOS'),
        icon: Icons.speed,
      ),
    ]);
  }

  /// Check mobile platform sensors
  Future<void> _checkMobileSensors(AppLocalizations l10n) async {
    // Check GPS/Location
    await _checkLocationSensor(l10n);
    
    // Check accelerometer (not available on macOS)
    if (!Platform.isMacOS) {
      await _checkAccelerometer(l10n);
    }
    
    // Check barometer (platform specific)
    if (Platform.isIOS || Platform.isAndroid) {
      await _checkBarometer(l10n);
    }
    
    // Add macOS-specific notifications
    if (Platform.isMacOS) {
      _addMacOSNotifications(l10n);
    }
  }

  /// Check if location services are available
  Future<void> _checkLocationSensor(AppLocalizations l10n) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _notifications.add(
          SensorNotificationData(
            id: 'location_disabled',
            sensorName: l10n.locationServicesDisabled,
            message: l10n.enableLocationServices,
            icon: Icons.location_off,
          ),
        );
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        _notifications.add(
          SensorNotificationData(
            id: 'location_permission',
            sensorName: l10n.locationPermissionRequired,
            message: permission == LocationPermission.deniedForever
                ? l10n.locationPermissionDeniedPermanently
                : l10n.locationPermissionNeededForNavigation,
            icon: Icons.location_disabled,
          ),
        );
      }
    } catch (e) {
      // Location service check failed
      _notifications.add(
        SensorNotificationData(
          id: 'location_error',
          sensorName: l10n.locationServiceError,
          message: l10n.unableToAccessLocationServices,
          icon: Icons.error_outline,
        ),
      );
    }
  }

  /// Check if accelerometer is available
  Future<void> _checkAccelerometer(AppLocalizations l10n) async {
    try {
      // Try to get a single accelerometer reading
      final stream = accelerometerEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Accelerometer not responding'),
      );
    } catch (e) {
      _notifications.add(
        SensorNotificationData(
          id: 'accelerometer_unavailable',
          sensorName: l10n.accelerometerNotAvailable,
          message: l10n.vibrationMeasurementFeaturesDisabled,
          icon: Icons.vibration,
        ),
      );
    }
  }

  /// Check if barometer is available
  Future<void> _checkBarometer(AppLocalizations l10n) async {
    try {
      // Check if we have pressure sensor permission on Android
      if (Platform.isAndroid) {
        final status = await perm.Permission.sensors.status;
        if (!status.isGranted) {
          _notifications.add(
            SensorNotificationData(
              id: 'barometer_permission',
              sensorName: l10n.barometerPermissionRequired,
              message: l10n.sensorPermissionNeededForAltitude,
              icon: Icons.speed,
            ),
          );
          return;
        }
      }

      // Try to get a barometer reading
      final stream = barometerEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Barometer not responding'),
      );
    } catch (e) {
      _notifications.add(
        SensorNotificationData(
          id: 'barometer_unavailable',
          sensorName: l10n.barometerNotAvailable,
          message: l10n.pressureAltitudeFeaturesLimited,
          icon: Icons.speed,
        ),
      );
    }
  }

  /// Dismiss a notification
  void dismissNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Clear all notifications
  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Reset to allow re-checking sensors
  void reset() {
    _hasCheckedSensors = false;
    _notifications.clear();
    notifyListeners();
  }
}