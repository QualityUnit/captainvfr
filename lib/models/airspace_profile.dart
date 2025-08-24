import 'package:latlong2/latlong.dart';
import 'airspace.dart';

/// Represents a point along the flight path with altitude and airspace information
class ProfilePoint {
  final double distanceNm;  // Distance from start in nautical miles
  final double altitudeFt;  // Altitude in feet
  final LatLng position;    // Geographic position
  final String? waypointId;  // Associated waypoint ID if this is a waypoint position
  final String? waypointName; // Waypoint name for display
  final int? legIndex;      // For multi-leg trips: which leg this point belongs to (0-based)
  final bool isLegStart;    // True if this is the start of a new leg
  final bool isLegEnd;      // True if this is the end of a leg
  final double? terrainElevationFt; // Terrain elevation at this point (feet)
  
  ProfilePoint({
    required this.distanceNm,
    required this.altitudeFt,
    required this.position,
    this.waypointId,
    this.waypointName,
    this.legIndex,
    this.isLegStart = false,
    this.isLegEnd = false,
    this.terrainElevationFt,
  });
}

/// Represents an airspace that the flight path crosses
class AirspaceCrossing {
  final Airspace airspace;
  final double entryDistanceNm;  // Distance from start where we enter
  final double exitDistanceNm;   // Distance from start where we exit
  final double entryAltitudeFt;  // Altitude when entering
  final double exitAltitudeFt;   // Altitude when exiting
  final LatLng entryPosition;    // Geographic position of entry
  final LatLng exitPosition;     // Geographic position of exit
  final int? legIndex;          // For multi-leg trips: which leg this crossing occurs in
  final bool isConflict;        // True if flight altitude conflicts with airspace limits
  
  AirspaceCrossing({
    required this.airspace,
    required this.entryDistanceNm,
    required this.exitDistanceNm,
    required this.entryAltitudeFt,
    required this.exitAltitudeFt,
    required this.entryPosition,
    required this.exitPosition,
    this.legIndex,
    this.isConflict = false,
  });
  
  /// Check if the flight altitude is within the airspace vertical limits
  bool checkAltitudeConflict() {
    // Get airspace limits (may be null)
    double lowerLimitFt = airspace.lowerLimitFt ?? 0;
    double upperLimitFt = airspace.upperLimitFt ?? 99999;
    
    // Check if either entry or exit altitude is within the airspace
    return (entryAltitudeFt >= lowerLimitFt && entryAltitudeFt <= upperLimitFt) ||
           (exitAltitudeFt >= lowerLimitFt && exitAltitudeFt <= upperLimitFt);
  }
  
  /// Get the duration in the airspace (in minutes) based on ground speed
  double getDurationMinutes(double groundSpeedKnots) {
    if (groundSpeedKnots <= 0) return 0;
    double distanceNm = exitDistanceNm - entryDistanceNm;
    return (distanceNm / groundSpeedKnots) * 60;
  }
}

/// Complete airspace profile for a flight plan or trip
class AirspaceProfile {
  final List<ProfilePoint> profilePoints;
  final List<AirspaceCrossing> airspaceCrossings;
  final double totalDistanceNm;
  final double maxAltitudeFt;
  final double minAltitudeFt;
  final int legCount;  // Number of legs in the trip (1 for single flight plan)
  final List<double> legStartDistances; // Distance at start of each leg
  
  AirspaceProfile({
    required this.profilePoints,
    required this.airspaceCrossings,
    required this.totalDistanceNm,
    required this.maxAltitudeFt,
    required this.minAltitudeFt,
    this.legCount = 1,
    this.legStartDistances = const [],
  });
  
  /// Get profile points for a specific leg
  List<ProfilePoint> getPointsForLeg(int legIndex) {
    return profilePoints.where((p) => p.legIndex == legIndex).toList();
  }
  
  /// Get airspace crossings for a specific leg
  List<AirspaceCrossing> getCrossingsForLeg(int legIndex) {
    return airspaceCrossings.where((c) => c.legIndex == legIndex).toList();
  }
  
  /// Find the nearest profile point to a given distance
  ProfilePoint? findNearestPoint(double distanceNm) {
    if (profilePoints.isEmpty) return null;
    
    ProfilePoint nearest = profilePoints.first;
    double minDiff = (distanceNm - nearest.distanceNm).abs();
    
    for (final point in profilePoints) {
      double diff = (distanceNm - point.distanceNm).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = point;
      }
    }
    
    return nearest;
  }
  
  /// Get all airspaces at a specific distance along the route
  List<AirspaceCrossing> getAirspacesAtDistance(double distanceNm) {
    return airspaceCrossings.where((crossing) =>
      distanceNm >= crossing.entryDistanceNm && 
      distanceNm <= crossing.exitDistanceNm
    ).toList();
  }
  
  /// Get altitude at a specific distance (interpolated if between points)
  double? getAltitudeAtDistance(double distanceNm) {
    if (profilePoints.isEmpty) return null;
    
    // Find surrounding points
    ProfilePoint? before;
    ProfilePoint? after;
    
    for (int i = 0; i < profilePoints.length; i++) {
      if (profilePoints[i].distanceNm <= distanceNm) {
        before = profilePoints[i];
      }
      if (profilePoints[i].distanceNm >= distanceNm && after == null) {
        after = profilePoints[i];
        break;
      }
    }
    
    if (before == null) return profilePoints.first.altitudeFt;
    if (after == null) return profilePoints.last.altitudeFt;
    if (before == after) return before.altitudeFt;
    
    // Linear interpolation
    double ratio = (distanceNm - before.distanceNm) / 
                  (after.distanceNm - before.distanceNm);
    return before.altitudeFt + 
           (after.altitudeFt - before.altitudeFt) * ratio;
  }
}

/// Selection state for interactive chart
class ProfileSelection {
  final ProfilePoint selectedPoint;
  final List<AirspaceCrossing> airspacesAtPoint;
  final double? groundSpeedKnots;  // Current ground speed if tracking
  final DateTime? estimatedTime;    // ETA to this point if tracking
  
  ProfileSelection({
    required this.selectedPoint,
    required this.airspacesAtPoint,
    this.groundSpeedKnots,
    this.estimatedTime,
  });
}