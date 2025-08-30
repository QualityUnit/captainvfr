import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import '../models/airspace.dart';
import '../models/airspace_profile.dart';
import '../models/flight_plan.dart';
import '../models/trip.dart';
import 'spatial_airspace_service.dart';
import 'terrain_elevation_service.dart';

class FlightPathAnalyzer {
  final SpatialAirspaceService _airspaceService;
  final TerrainElevationService _terrainService = TerrainElevationService();
  static const Distance _distance = Distance();
  
  FlightPathAnalyzer(this._airspaceService);
  
  /// Analyze a single flight plan or a complete trip with multiple legs
  Future<AirspaceProfile> analyzeFlightPath({
    required List<FlightPlan> flightPlans,
    Trip? trip,
  }) async {
    if (flightPlans.isEmpty) {
      return AirspaceProfile(
        profilePoints: [],
        airspaceCrossings: [],
        totalDistanceNm: 0,
        maxAltitudeFt: 0,
        minAltitudeFt: 0,
        legCount: 0,
        legStartDistances: [],
      );
    }
    
    List<ProfilePoint> allProfilePoints = [];
    List<AirspaceCrossing> allAirspaceCrossings = [];
    List<double> legStartDistances = [];
    double cumulativeDistance = 0;
    double maxAlt = 0;
    double minAlt = double.infinity;
    
    // Process each flight plan (leg)
    for (int legIndex = 0; legIndex < flightPlans.length; legIndex++) {
      final flightPlan = flightPlans[legIndex];
      if (flightPlan.waypoints.isEmpty) continue;
      
      legStartDistances.add(cumulativeDistance);
      
      // Generate profile points for this leg
      final legPoints = _generateProfilePoints(
        flightPlan: flightPlan,
        startDistance: cumulativeDistance,
        legIndex: legIndex,
        isFirstLeg: legIndex == 0,
        isLastLeg: legIndex == flightPlans.length - 1,
      );
      
      allProfilePoints.addAll(legPoints);
      
      // Update min/max altitudes
      for (final point in legPoints) {
        maxAlt = math.max(maxAlt, point.altitudeFt);
        minAlt = math.min(minAlt, point.altitudeFt);
      }
      
      // Analyze airspace crossings for this leg
      final legCrossings = await _analyzeAirspaceCrossings(
        profilePoints: legPoints,
        legIndex: legIndex,
      );
      
      allAirspaceCrossings.addAll(legCrossings);
      
      // Update cumulative distance
      cumulativeDistance += flightPlan.totalDistance;
    }
    
    // Sort crossings by entry distance
    allAirspaceCrossings.sort((a, b) => a.entryDistanceNm.compareTo(b.entryDistanceNm));
    
    // Populate terrain elevation data for all profile points
    await _populateTerrainElevation(allProfilePoints);
    
    return AirspaceProfile(
      profilePoints: allProfilePoints,
      airspaceCrossings: allAirspaceCrossings,
      totalDistanceNm: cumulativeDistance,
      maxAltitudeFt: maxAlt,
      minAltitudeFt: minAlt == double.infinity ? 0 : minAlt,
      legCount: flightPlans.length,
      legStartDistances: legStartDistances,
    );
  }
  
  /// Generate profile points along a flight plan
  List<ProfilePoint> _generateProfilePoints({
    required FlightPlan flightPlan,
    required double startDistance,
    required int legIndex,
    required bool isFirstLeg,
    required bool isLastLeg,
  }) {
    List<ProfilePoint> points = [];
    
    if (flightPlan.waypoints.isEmpty) return points;
    
    double currentDistance = startDistance;
    
    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];
      final isFirst = i == 0;
      final isLast = i == flightPlan.waypoints.length - 1;
      
      // Add waypoint as a profile point
      points.add(ProfilePoint(
        distanceNm: currentDistance,
        altitudeFt: waypoint.altitude.toDouble(),
        position: LatLng(waypoint.latitude, waypoint.longitude),
        waypointId: waypoint.id,
        waypointName: waypoint.name,
        legIndex: legIndex,
        isLegStart: isFirst,
        isLegEnd: isLast,
      ));
      
      // Add intermediate points between waypoints for smooth profile
      if (i < flightPlan.waypoints.length - 1) {
        final nextWaypoint = flightPlan.waypoints[i + 1];
        final segmentPoints = _interpolateSegment(
          startWaypoint: waypoint,
          endWaypoint: nextWaypoint,
          startDistance: currentDistance,
          legIndex: legIndex,
        );
        points.addAll(segmentPoints);
        
        // Calculate distance to next waypoint
        double segmentDistanceMeters = _distance.distance(
          LatLng(waypoint.latitude, waypoint.longitude),
          LatLng(nextWaypoint.latitude, nextWaypoint.longitude),
        );
        double segmentDistance = segmentDistanceMeters / 1852.0; // Convert meters to nautical miles
        currentDistance += segmentDistance;
      }
    }
    
    return points;
  }
  
  /// Interpolate points between two waypoints
  List<ProfilePoint> _interpolateSegment({
    required Waypoint startWaypoint,
    required Waypoint endWaypoint,
    required double startDistance,
    required int legIndex,
  }) {
    List<ProfilePoint> points = [];
    
    final startPos = LatLng(startWaypoint.latitude, startWaypoint.longitude);
    final endPos = LatLng(endWaypoint.latitude, endWaypoint.longitude);
    
    double segmentDistanceMeters = _distance.distance(
      startPos,
      endPos,
    );
    double segmentDistance = segmentDistanceMeters / 1852.0; // Convert meters to nautical miles
    
    // Dynamic sampling interval based on segment length
    // For short segments (< 10nm), sample every 2nm
    // For medium segments (10-50nm), sample every 3nm  
    // For long segments (> 50nm), sample every 5nm
    double sampleInterval = 2.0;
    if (segmentDistance > 50) {
      sampleInterval = 5.0;
    } else if (segmentDistance > 10) {
      sampleInterval = 3.0;
    }
    
    if (segmentDistance <= sampleInterval) {
      return points; // Segment too short to interpolate
    }
    
    int numSamples = (segmentDistance / sampleInterval).floor();
    double altitudeDiff = endWaypoint.altitude - startWaypoint.altitude;
    
    for (int i = 1; i <= numSamples; i++) {
      double ratio = i / (numSamples + 1);
      double distance = startDistance + segmentDistance * ratio;
      
      // Linear altitude interpolation
      double altitude = startWaypoint.altitude + altitudeDiff * ratio;
      
      // Geographic interpolation
      double lat = startPos.latitude + 
                  (endPos.latitude - startPos.latitude) * ratio;
      double lon = startPos.longitude + 
                  (endPos.longitude - startPos.longitude) * ratio;
      
      points.add(ProfilePoint(
        distanceNm: distance,
        altitudeFt: altitude,
        position: LatLng(lat, lon),
        legIndex: legIndex,
      ));
    }
    
    return points;
  }
  
  /// Analyze airspace crossings for a set of profile points
  Future<List<AirspaceCrossing>> _analyzeAirspaceCrossings({
    required List<ProfilePoint> profilePoints,
    required int legIndex,
  }) async {
    if (profilePoints.isEmpty) return [];
    
    List<AirspaceCrossing> crossings = [];
    Map<String, AirspaceCrossingBuilder> activeAirspaces = {};
    
    // Calculate bounds for the leg to query airspaces more efficiently
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;
    
    for (final point in profilePoints) {
      minLat = math.min(minLat, point.position.latitude);
      maxLat = math.max(maxLat, point.position.latitude);
      minLon = math.min(minLon, point.position.longitude);
      maxLon = math.max(maxLon, point.position.longitude);
    }
    
    // Add a small buffer to ensure we get all relevant airspaces
    const buffer = 0.05; // degrees (~5km)
    minLat -= buffer;
    maxLat += buffer;
    minLon -= buffer;
    maxLon += buffer;
    
    // Pre-load ALL airspaces in the area once - this is the key optimization
    final allAirspacesInArea = await _airspaceService.getAirspacesInBounds(
      LatLngBounds(
        LatLng(minLat, minLon),
        LatLng(maxLat, maxLon),
      ),
    );
    
    // Process each point to detect airspace entries and exits
    for (int i = 0; i < profilePoints.length; i++) {
      final point = profilePoints[i];
      
      // Instead of querying the service for each point, filter the pre-loaded airspaces
      // This is MUCH faster as it avoids repeated tile loading and spatial index queries
      final airspacesAtPoint = _filterAirspacesAtPoint(
        allAirspacesInArea,
        point.position,
      );
      
      // Track which airspaces we're currently in
      Set<String> currentAirspaceIds = airspacesAtPoint.map((a) => a.id).toSet();
      
      // Check for exits (airspaces we were in but are no longer)
      List<String> toRemove = [];
      for (final entry in activeAirspaces.entries) {
        if (!currentAirspaceIds.contains(entry.key)) {
          // We've exited this airspace
          final builder = entry.value;
          builder.exitDistanceNm = point.distanceNm;
          builder.exitAltitudeFt = point.altitudeFt;
          builder.exitPosition = point.position;
          
          // Create the crossing
          final crossing = builder.build();
          if (crossing != null) {
            crossings.add(crossing);
          }
          toRemove.add(entry.key);
        }
      }
      
      // Remove exited airspaces
      for (final id in toRemove) {
        activeAirspaces.remove(id);
      }
      
      // Check for entries (new airspaces)
      for (final airspace in airspacesAtPoint) {
        if (!activeAirspaces.containsKey(airspace.id)) {
          // We've entered a new airspace
          activeAirspaces[airspace.id] = AirspaceCrossingBuilder(
            airspace: airspace,
            entryDistanceNm: point.distanceNm,
            entryAltitudeFt: point.altitudeFt,
            entryPosition: point.position,
            legIndex: legIndex,
          );
        }
      }
    }
    
    // Handle any remaining active airspaces (exit at end of leg)
    if (profilePoints.isNotEmpty) {
      final lastPoint = profilePoints.last;
      for (final builder in activeAirspaces.values) {
        builder.exitDistanceNm = lastPoint.distanceNm;
        builder.exitAltitudeFt = lastPoint.altitudeFt;
        builder.exitPosition = lastPoint.position;
        
        final crossing = builder.build();
        if (crossing != null) {
          crossings.add(crossing);
        }
      }
    }
    
    return crossings;
  }
  
  /// Filter airspaces to find those containing a specific point
  /// This is much faster than querying the spatial index for each point
  List<Airspace> _filterAirspacesAtPoint(List<Airspace> allAirspaces, LatLng point) {
    return allAirspaces.where((airspace) {
      // Check if the point is within the airspace's geometry
      if (airspace.geometry.isNotEmpty) {
        return _isPointInPolygon(point, airspace.geometry);
      }
      return false;
    }).toList();
  }
  
  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    int vertexCount = polygon.length;
    
    for (int i = 0; i < vertexCount; i++) {
      LatLng vertex1 = polygon[i];
      LatLng vertex2 = polygon[(i + 1) % vertexCount];
      
      // Check if point is on the same latitude band as the edge
      if ((vertex1.latitude <= point.latitude && point.latitude < vertex2.latitude) ||
          (vertex2.latitude <= point.latitude && point.latitude < vertex1.latitude)) {
        // Calculate the longitude of intersection
        double intersectLon = vertex1.longitude +
            (point.latitude - vertex1.latitude) *
            (vertex2.longitude - vertex1.longitude) /
            (vertex2.latitude - vertex1.latitude);
        
        if (point.longitude < intersectLon) {
          intersections++;
        }
      }
    }
    
    return intersections % 2 == 1;
  }
  
  /// Populate terrain elevation data for profile points
  Future<void> _populateTerrainElevation(List<ProfilePoint> points) async {
    // Fetch all elevations in parallel for better performance
    final futures = <Future<double?>>[];
    for (final point in points) {
      futures.add(_terrainService.getElevation(point.position));
    }
    
    final elevations = await Future.wait(futures);
    
    // Create new points with terrain data
    for (int i = 0; i < points.length; i++) {
      final elevation = elevations[i];
      if (elevation != null) {
        final terrainFt = elevation * 3.28084;
        final oldPoint = points[i];
        
        // Replace with new point that includes terrain elevation
        points[i] = ProfilePoint(
          distanceNm: oldPoint.distanceNm,
          altitudeFt: oldPoint.altitudeFt,
          position: oldPoint.position,
          waypointId: oldPoint.waypointId,
          waypointName: oldPoint.waypointName,
          legIndex: oldPoint.legIndex,
          isLegStart: oldPoint.isLegStart,
          isLegEnd: oldPoint.isLegEnd,
          terrainElevationFt: terrainFt,
        );
      }
    }
  }
}

/// Helper class to build airspace crossings
class AirspaceCrossingBuilder {
  final Airspace airspace;
  final double entryDistanceNm;
  final double entryAltitudeFt;
  final LatLng entryPosition;
  final int legIndex;
  double? exitDistanceNm;
  double? exitAltitudeFt;
  LatLng? exitPosition;
  
  AirspaceCrossingBuilder({
    required this.airspace,
    required this.entryDistanceNm,
    required this.entryAltitudeFt,
    required this.entryPosition,
    required this.legIndex,
  });
  
  AirspaceCrossing? build() {
    if (exitDistanceNm == null || exitAltitudeFt == null || exitPosition == null) {
      return null;
    }
    
    final crossing = AirspaceCrossing(
      airspace: airspace,
      entryDistanceNm: entryDistanceNm,
      exitDistanceNm: exitDistanceNm!,
      entryAltitudeFt: entryAltitudeFt,
      exitAltitudeFt: exitAltitudeFt!,
      entryPosition: entryPosition,
      exitPosition: exitPosition!,
      legIndex: legIndex,
    );
    
    // Check for altitude conflicts
    crossing.isConflict;
    
    return crossing;
  }
}