import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'terrain_elevation_service.dart';
import 'flight_service.dart';

/// Service for terrain proximity alerts
class TerrainAlertService extends ChangeNotifier {
  final TerrainElevationService _terrainService;
  final FlightService _flightService;
  
  Timer? _checkTimer;
  TerrainAlert? _currentAlert;
  
  // Alert thresholds (in feet)
  static const double criticalClearance = 500.0;
  static const double warningClearance = 1000.0;
  static const double cautionClearance = 2000.0;
  
  TerrainAlertService(this._terrainService, this._flightService) {
    _startMonitoring();
  }
  
  TerrainAlert? get currentAlert => _currentAlert;
  
  void _startMonitoring() {
    // Check terrain clearance every 2 seconds during flight
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_flightService.isTracking) {
        _checkTerrainClearance();
      }
    });
  }
  
  Future<void> _checkTerrainClearance() async {
    final flightPath = _flightService.flightPath;
    if (flightPath.isEmpty) return;
    
    final currentPoint = flightPath.last;
    final position = LatLng(currentPoint.latitude, currentPoint.longitude);
    final altitude = currentPoint.altitude;
    
    try {
      // Get terrain elevation at current position
      final terrainElevation = await _terrainService.getElevation(
        position.latitude,
        position.longitude,
      );
      
      if (terrainElevation == null) return;
      
      // Calculate clearance (AGL - Above Ground Level)
      final clearance = altitude - terrainElevation;
      
      // Determine alert level
      TerrainAlertLevel? alertLevel;
      String? message;
      
      if (clearance < criticalClearance) {
        alertLevel = TerrainAlertLevel.critical;
        message = 'TERRAIN! PULL UP! Clearance: ${clearance.toInt()} ft';
      } else if (clearance < warningClearance) {
        alertLevel = TerrainAlertLevel.warning;
        message = 'Terrain Warning: ${clearance.toInt()} ft clearance';
      } else if (clearance < cautionClearance) {
        alertLevel = TerrainAlertLevel.caution;
        message = 'Terrain Caution: ${clearance.toInt()} ft clearance';
      }
      
      if (alertLevel != null && message != null) {
        _currentAlert = TerrainAlert(
          level: alertLevel,
          message: message,
          clearance: clearance,
          terrainElevation: terrainElevation,
          altitude: altitude,
          position: position,
          timestamp: DateTime.now(),
        );
        notifyListeners();
      } else if (_currentAlert != null) {
        // Clear alert if clearance is safe
        _currentAlert = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking terrain clearance: $e');
    }
  }
  
  void clearAlert() {
    _currentAlert = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

enum TerrainAlertLevel {
  critical,
  warning,
  caution,
}

class TerrainAlert {
  final TerrainAlertLevel level;
  final String message;
  final double clearance;
  final double terrainElevation;
  final double altitude;
  final LatLng position;
  final DateTime timestamp;
  
  TerrainAlert({
    required this.level,
    required this.message,
    required this.clearance,
    required this.terrainElevation,
    required this.altitude,
    required this.position,
    required this.timestamp,
  });
}
