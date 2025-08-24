import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/safesky_beacon.dart';
import '../config/environment.dart';

/// Utility class for aircraft collision detection calculations
class CollisionDetection {
  static const Distance _distance = Distance();
  
  /// Calculate distance between two points in kilometers
  static double calculateDistance(LatLng point1, LatLng point2) {
    return _distance.as(LengthUnit.Kilometer, point1, point2);
  }
  
  /// Check if a beacon poses a collision risk
  static CollisionRisk assessCollisionRisk({
    required SafeSkyBeacon beacon,
    required LatLng currentPosition,
    required double currentAltitudeFt,
  }) {
    // Calculate horizontal distance
    final beaconPosition = LatLng(beacon.latitude, beacon.longitude);
    final distanceKm = calculateDistance(currentPosition, beaconPosition);
    
    // Calculate altitude difference
    final altitudeDiff = (beacon.altitudeFt - currentAltitudeFt).abs();
    
    // Check collision thresholds
    if (distanceKm < Environment.collisionDangerDistanceKm && 
        altitudeDiff < Environment.collisionDangerAltitudeFt) {
      return CollisionRisk.danger;
    }
    
    if (distanceKm < Environment.collisionWarningDistanceKm && 
        altitudeDiff < Environment.collisionWarningAltitudeFt) {
      return CollisionRisk.warning;
    }
    
    return CollisionRisk.none;
  }
  
  /// Calculate relative bearing from current position to beacon
  static double calculateRelativeBearing({
    required LatLng from,
    required LatLng to,
    required double currentHeading,
  }) {
    final bearing = _distance.bearing(from, to);
    return (bearing - currentHeading + 360) % 360;
  }
  
  /// Predict future position of beacon based on current velocity
  static LatLng predictFuturePosition({
    required SafeSkyBeacon beacon,
    required Duration timeAhead,
  }) {
    if (beacon.groundSpeed <= 0) {
      return LatLng(beacon.latitude, beacon.longitude);
    }
    
    // Convert ground speed from knots to m/s
    final speedMs = beacon.groundSpeed * 0.514444;
    
    // Calculate distance traveled
    final distanceM = speedMs * timeAhead.inSeconds;
    
    // Convert course to radians
    final courseRad = beacon.course * (math.pi / 180);
    
    // Calculate new position
    final R = 6371000; // Earth's radius in meters
    final lat1 = beacon.latitude * (math.pi / 180);
    final lon1 = beacon.longitude * (math.pi / 180);
    
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(distanceM / R) +
      math.cos(lat1) * math.sin(distanceM / R) * math.cos(courseRad)
    );
    
    final lon2 = lon1 + math.atan2(
      math.sin(courseRad) * math.sin(distanceM / R) * math.cos(lat1),
      math.cos(distanceM / R) - math.sin(lat1) * math.sin(lat2)
    );
    
    return LatLng(
      lat2 * (180 / math.pi),
      lon2 * (180 / math.pi),
    );
  }
  
  /// Check if two aircraft are on converging paths
  static bool areConverging({
    required SafeSkyBeacon beacon1,
    required SafeSkyBeacon beacon2,
    double thresholdDegrees = 30,
  }) {
    // Calculate the difference in courses
    double courseDiff = (beacon1.course - beacon2.course).abs().toDouble();
    if (courseDiff > 180) {
      courseDiff = 360 - courseDiff;
    }
    
    // If courses are within threshold, they might be converging
    return courseDiff < thresholdDegrees;
  }
  
  /// Calculate time to closest point of approach (CPA)
  static Duration? timeToClosestApproach({
    required SafeSkyBeacon beacon1,
    required SafeSkyBeacon beacon2,
  }) {
    // This is a simplified calculation
    // For accurate CPA, complex vector calculations would be needed
    
    if (beacon1.groundSpeed <= 0 || beacon2.groundSpeed <= 0) {
      return null;
    }
    
    // Calculate relative velocity
    final relativeSpeed = math.sqrt(
      math.pow(beacon1.groundSpeed, 2) + 
      math.pow(beacon2.groundSpeed, 2) - 
      2 * beacon1.groundSpeed * beacon2.groundSpeed * 
      math.cos((beacon1.course - beacon2.course) * math.pi / 180)
    );
    
    if (relativeSpeed <= 0) {
      return null;
    }
    
    // Calculate current distance
    final currentDistance = calculateDistance(
      LatLng(beacon1.latitude, beacon1.longitude),
      LatLng(beacon2.latitude, beacon2.longitude),
    );
    
    // Simplified time to CPA (this is an approximation)
    final timeSec = (currentDistance * 1000) / (relativeSpeed * 0.514444);
    
    return Duration(seconds: timeSec.round());
  }
}

/// Collision risk levels
enum CollisionRisk {
  none,
  warning,
  danger,
}

/// Extension for collision risk colors
extension CollisionRiskExtension on CollisionRisk {
  bool get isRisk => this != CollisionRisk.none;
  
  String get label {
    switch (this) {
      case CollisionRisk.none:
        return 'Safe';
      case CollisionRisk.warning:
        return 'Caution';
      case CollisionRisk.danger:
        return 'Danger';
    }
  }
}