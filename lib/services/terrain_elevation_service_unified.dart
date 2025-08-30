import 'package:latlong2/latlong.dart';
import 'terrain_elevation_service_tin.dart';
import 'terrain_elevation_service.dart';

/// Unified terrain elevation service that uses TIN when available
/// Falls back to legacy service for areas without TIN data
class UnifiedTerrainElevationService {
  
  /// Check if a coordinate is likely ocean
  static bool _isOceanTile(double lat, double lon) {
    final intLat = lat.floor();
    final intLon = lon.floor();
    
    // Pacific Ocean - vast majority of Pacific
    if (intLon < -130 || intLon > 150) return true;
    
    // Central Pacific
    if (intLon > -180 && intLon < -160 && intLat > -60 && intLat < 60) return true;
    if (intLon > 165 && intLon < 180 && intLat > -60 && intLat < 60) return true;
    
    // Atlantic Ocean - mid-Atlantic
    if (intLon > -50 && intLon < -10 && intLat > -60 && intLat < 70) return true;
    
    // Indian Ocean 
    if (intLon > 40 && intLon < 100 && intLat < -10) return true;
    
    // Southern Ocean (around Antarctica)
    if (intLat < -60) return true;
    
    // Arctic Ocean
    if (intLat > 75) return true;
    
    // Mediterranean and smaller seas (more specific)
    if (intLon > 0 && intLon < 40 && intLat > 30 && intLat < 50) {
      // But exclude most of Europe and Middle East land
      if (intLat < 40 || (intLon > 35 && intLat > 35)) return false;
      return true;
    }
    
    return false;
  }
  final TerrainElevationServiceTIN _tinService = TerrainElevationServiceTIN();
  final TerrainElevationService _legacyService = TerrainElevationService();
  
  /// Statistics for monitoring
  int tinHits = 0;
  int legacyHits = 0;
  int misses = 0;
  
  /// Get elevation at a specific point
  /// Uses TIN service first (92% accuracy), falls back to legacy if needed
  Future<double?> getElevation(LatLng point) async {
    // Try TIN service first (best accuracy)
    final tinElevation = await _tinService.getElevation(point);
    if (tinElevation != null) {
      tinHits++;
      return tinElevation;
    }
    
    // Fall back to legacy service
    final legacyElevation = await _legacyService.getElevation(point);
    if (legacyElevation != null) {
      legacyHits++;
      return legacyElevation;
    }
    
    // Check if this is likely ocean area (return 0m sea level)
    if (_isOceanTile(point.latitude, point.longitude)) {
      return 0.0;
    }
    
    misses++;
    return null;
  }
  
  /// Get elevation profile along a path
  Future<List<double?>> getElevationProfile(
    List<LatLng> path, {
    int pointsPerSegment = 10,
  }) async {
    // Try TIN service first
    final tinProfile = await _tinService.getElevationProfile(
      path,
      pointsPerSegment: pointsPerSegment,
    );
    
    // Check if TIN has good coverage
    final validCount = tinProfile.where((e) => e != null).length;
    if (validCount > tinProfile.length * 0.7) {
      // Good coverage, use TIN
      return tinProfile;
    }
    
    // Poor TIN coverage, try legacy
    final legacyProfile = await _legacyService.getElevationProfile(
      path,
      pointsPerSegment: pointsPerSegment,
    );
    
    // Merge profiles, preferring TIN where available, use 0m for ocean
    final mergedProfile = <double?>[];
    
    // Generate path points for ocean detection
    final pathPoints = <LatLng>[];
    for (int i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];
      
      for (int j = 0; j <= pointsPerSegment; j++) {
        final t = j / pointsPerSegment;
        final lat = start.latitude + (end.latitude - start.latitude) * t;
        final lng = start.longitude + (end.longitude - start.longitude) * t;
        pathPoints.add(LatLng(lat, lng));
      }
    }
    
    for (int i = 0; i < tinProfile.length && i < legacyProfile.length && i < pathPoints.length; i++) {
      final elevation = tinProfile[i] ?? legacyProfile[i];
      
      // If no elevation data and it's ocean, use 0m
      if (elevation == null && _isOceanTile(pathPoints[i].latitude, pathPoints[i].longitude)) {
        mergedProfile.add(0.0);
      } else {
        mergedProfile.add(elevation);
      }
    }
    
    return mergedProfile;
  }
  
  /// Get terrain clearance for a point at given altitude
  Future<double?> getTerrainClearance(LatLng point, double altitude) async {
    final elevation = await getElevation(point);
    if (elevation == null) return null;
    
    // Convert altitude from feet to meters if needed
    final altitudeMeters = altitude * 0.3048; // Assuming altitude is in feet
    return altitudeMeters - elevation;
  }
  
  /// Check if terrain warning is needed
  Future<bool> needsTerrainWarning(
    LatLng point, 
    double altitude, {
    double minClearance = 150, // meters
  }) async {
    final clearance = await getTerrainClearance(point, altitude);
    if (clearance == null) return false;
    
    return clearance < minClearance;
  }
  
  /// Clear caches
  void clearCache() {
    _tinService.clearCache();
    _legacyService.clearCache();
  }
  
  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    final total = tinHits + legacyHits + misses;
    return {
      'tin_hits': tinHits,
      'tin_percentage': total > 0 ? (tinHits / total * 100).toStringAsFixed(1) : '0.0',
      'legacy_hits': legacyHits,
      'legacy_percentage': total > 0 ? (legacyHits / total * 100).toStringAsFixed(1) : '0.0',
      'misses': misses,
      'miss_percentage': total > 0 ? (misses / total * 100).toStringAsFixed(1) : '0.0',
      'total_requests': total,
      'accuracy_mode': tinHits > legacyHits ? 'TIN (92% accuracy)' : 'Legacy',
    };
  }
  
  /// Get service info
  String getServiceInfo() {
    final stats = getStatistics();
    return 'Elevation Service: ${stats['accuracy_mode']}\n'
           'Coverage: TIN ${stats['tin_percentage']}%, Legacy ${stats['legacy_percentage']}%';
  }
}

/// Global singleton instance
final terrainElevationService = UnifiedTerrainElevationService();