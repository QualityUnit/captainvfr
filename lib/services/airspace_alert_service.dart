import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'spatial_airspace_service.dart';
import 'flight_service.dart';
import '../models/airspace.dart';

/// Service for airspace proximity alerts
class AirspaceAlertService extends ChangeNotifier {
  final SpatialAirspaceService _airspaceService;
  final FlightService _flightService;
  
  Timer? _checkTimer;
  List<AirspaceAlert> _activeAlerts = [];
  
  // Alert distances (in nautical miles)
  static const double criticalDistance = 1.0;
  static const double warningDistance = 3.0;
  static const double cautionDistance = 5.0;
  
  AirspaceAlertService(this._airspaceService, this._flightService) {
    _startMonitoring();
  }
  
  List<AirspaceAlert> get activeAlerts => _activeAlerts;
  
  void _startMonitoring() {
    // Check airspace proximity every 5 seconds during flight
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_flightService.isTracking) {
        _checkAirspaceProximity();
      }
    });
  }
  
  Future<void> _checkAirspaceProximity() async {
    final flightPath = _flightService.flightPath;
    if (flightPath.isEmpty) return;
    
    final currentPoint = flightPath.last;
    final position = LatLng(currentPoint.latitude, currentPoint.longitude);
    final altitude = currentPoint.altitude;
    
    try {
      // Get nearby airspaces
      final nearbyAirspaces = await _airspaceService.getAirspacesNear(
        position,
        radiusNm: cautionDistance,
      );
      
      final newAlerts = <AirspaceAlert>[];
      
      for (final airspace in nearbyAirspaces) {
        // Check if altitude is within airspace vertical limits
        if (!_isAltitudeInRange(altitude, airspace)) {
          continue;
        }
        
        // Calculate distance to airspace boundary
        final distance = _calculateDistanceToAirspace(position, airspace);
        
        // Determine alert level based on distance
        AirspaceAlertLevel? alertLevel;
        String? message;
        
        if (distance < criticalDistance) {
          alertLevel = AirspaceAlertLevel.critical;
          message = 'ENTERING ${airspace.name} (${airspace.type})';
        } else if (distance < warningDistance) {
          alertLevel = AirspaceAlertLevel.warning;
          final timeToEntry = _estimateTimeToEntry(distance);
          message = '${airspace.name} in ${timeToEntry}min (${airspace.type})';
        } else if (distance < cautionDistance) {
          alertLevel = AirspaceAlertLevel.caution;
          message = 'Approaching ${airspace.name} (${airspace.type})';
        }
        
        if (alertLevel != null && message != null) {
          newAlerts.add(AirspaceAlert(
            level: alertLevel,
            message: message,
            airspace: airspace,
            distance: distance,
            position: position,
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // Update alerts if changed
      if (!_alertsEqual(newAlerts, _activeAlerts)) {
        _activeAlerts = newAlerts;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking airspace proximity: $e');
    }
  }
  
  bool _isAltitudeInRange(double altitude, Airspace airspace) {
    // Convert altitude to feet MSL for comparison
    final altitudeFt = altitude;
    
    // Check lower limit
    if (airspace.lowerLimit != null) {
      final lowerFt = _parseAltitude(airspace.lowerLimit!);
      if (lowerFt != null && altitudeFt < lowerFt) {
        return false;
      }
    }
    
    // Check upper limit
    if (airspace.upperLimit != null) {
      final upperFt = _parseAltitude(airspace.upperLimit!);
      if (upperFt != null && altitudeFt > upperFt) {
        return false;
      }
    }
    
    return true;
  }
  
  double? _parseAltitude(String altitudeStr) {
    // Parse altitude strings like "SFC", "5000 FT", "FL180", etc.
    if (altitudeStr.toUpperCase() == 'SFC' || altitudeStr.toUpperCase() == 'GND') {
      return 0.0;
    }
    
    if (altitudeStr.toUpperCase().startsWith('FL')) {
      final flightLevel = int.tryParse(altitudeStr.substring(2));
      return flightLevel != null ? flightLevel * 100.0 : null;
    }
    
    final match = RegExp(r'(\d+)').firstMatch(altitudeStr);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    
    return null;
  }
  
  double _calculateDistanceToAirspace(LatLng position, Airspace airspace) {
    // Simplified distance calculation to airspace center
    // In a real implementation, this would calculate distance to nearest boundary
    const distance = Distance();
    final center = LatLng(airspace.latitude, airspace.longitude);
    final distanceMeters = distance.as(LengthUnit.Meter, position, center);
    return distanceMeters / 1852.0; // Convert to nautical miles
  }
  
  int _estimateTimeToEntry(double distanceNm) {
    // Estimate time to entry based on current ground speed
    final speedKts = _flightService.currentSpeed;
    if (speedKts <= 0) return 99;
    
    final timeHours = distanceNm / speedKts;
    return (timeHours * 60).round();
  }
  
  bool _alertsEqual(List<AirspaceAlert> a, List<AirspaceAlert> b) {
    if (a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if (a[i].airspace.id != b[i].airspace.id ||
          a[i].level != b[i].level) {
        return false;
      }
    }
    
    return true;
  }
  
  void clearAlerts() {
    _activeAlerts = [];
    notifyListeners();
  }
  
  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

enum AirspaceAlertLevel {
  critical,
  warning,
  caution,
}

class AirspaceAlert {
  final AirspaceAlertLevel level;
  final String message;
  final Airspace airspace;
  final double distance;
  final LatLng position;
  final DateTime timestamp;
  
  AirspaceAlert({
    required this.level,
    required this.message,
    required this.airspace,
    required this.distance,
    required this.position,
    required this.timestamp,
  });
}
