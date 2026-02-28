// Legacy terrain elevation service - REPLACED BY SRTM SERVICE
// This file is kept for compatibility but redirects to the new SRTM service

import 'dart:io';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'srtm_elevation_service.dart';

/// Legacy terrain elevation service - now uses SRTM backend
/// Provides backward compatibility while using modern SRTM data
class TerrainElevationService {
  static final SrtmElevationService _srtmService = SrtmElevationService();
  static bool _initialized = false;
  
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _srtmService.initialize();
      _initialized = true;
    }
  }
  
  static String? _cacheDir;
  
  static Future<String> get cacheDir async {
    if (_cacheDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = path.join(appDir.path, 'srtm_cache');
      final dir = Directory(_cacheDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    return _cacheDir!;
  }
  
  // Elevation data sources - now using SRTM
  static const List<ElevationSource> dataSources = [
    ElevationSource.srtm,  // SRTM-based elevation for aviation safety
  ];

  /// Get elevation at a specific point
  /// Uses 30m SRTM data for precise elevation queries
  static Future<double?> getElevation(LatLng point) async {
    await _ensureInitialized();
    return await _srtmService.getElevation(
      point.latitude, 
      point.longitude,
      resolution: ElevationResolution.precise,
    );
  }
  
  /// Get elevation for map visualization (uses 500m data for performance)
  static Future<double?> getElevationForVisualization(LatLng point) async {
    await _ensureInitialized();
    return await _srtmService.getElevation(
      point.latitude, 
      point.longitude,
      resolution: ElevationResolution.visualization,
    );
  }

  /// Get elevation profile along a path
  static Future<List<ElevationPoint>> getElevationProfile(
    List<LatLng> path, {
    double? sampleDistance, // meters between samples
  }) async {
    final profile = <ElevationPoint>[];
    
    if (path.isEmpty) return profile;
    
    await _ensureInitialized();
    
    // Batch process elevations for better performance
    final points = path.map((p) => (lat: p.latitude, lon: p.longitude)).toList();
    final elevations = await _srtmService.getElevationBatch(
      points,
      resolution: ElevationResolution.precise, // Use precise data for flight planning
    );
    
    // Build profile with distances
    double currentDistance = 0;
    for (int i = 0; i < path.length; i++) {
      if (i > 0) {
        currentDistance += const Distance().as(
          LengthUnit.Meter,
          path[i - 1],
          path[i],
        );
      }
      
      final elevation = elevations[i];
      
      profile.add(ElevationPoint(
        position: path[i],
        elevation: elevation ?? 0,
        distance: currentDistance,
        dataSource: ElevationSource.srtm,
      ));
    }
    
    return profile;
  }

  /// Get terrain clearance for current position and altitude
  static Future<TerrainClearance> getTerrainClearance(
    LatLng position,
    double altitudeFt,
  ) async {
    var terrainElevation = await getElevation(position);
    terrainElevation ??= 0.0;  // Default to sea level if no data
    
    final terrainFt = terrainElevation * 3.28084; // Convert meters to feet
    final clearance = altitudeFt - terrainFt;
    
    // Determine warning level based on clearance
    TerrainWarningLevel warningLevel;
    if (clearance < 100) {
      warningLevel = TerrainWarningLevel.critical;
    } else if (clearance < 500) {
      warningLevel = TerrainWarningLevel.warning;
    } else if (clearance < 1000) {
      warningLevel = TerrainWarningLevel.caution;
    } else {
      warningLevel = TerrainWarningLevel.safe;
    }
    
    return TerrainClearance(
      terrainElevationFt: terrainFt,
      aircraftAltitudeFt: altitudeFt,
      clearanceFt: clearance,
      warningLevel: warningLevel,
    );
  }

  /// Get terrain danger zones within viewport based on current altitude
  /// Uses 500m SRTM data for fast visualization performance
  static Future<List<TerrainDangerZone>> getTerrainDangerZones(
    LatLngBounds viewport,
    double currentAltitudeFt, {
    double gridResolution = 0.01, // degrees
  }) async {
    await _ensureInitialized();
    final zones = <TerrainDangerZone>[];
    
    // Sample terrain in grid pattern
    final latSteps = ((viewport.north - viewport.south) / gridResolution).ceil();
    final lonSteps = ((viewport.east - viewport.west) / gridResolution).ceil();
    
    // Collect all points for batch processing
    final points = <({double lat, double lon})>[];
    for (int latStep = 0; latStep <= latSteps; latStep++) {
      for (int lonStep = 0; lonStep <= lonSteps; lonStep++) {
        final lat = viewport.south + (latStep * gridResolution);
        final lon = viewport.west + (lonStep * gridResolution);
        points.add((lat: lat, lon: lon));
      }
    }
    
    // Batch process elevations using 500m data for fast visualization
    final elevations = await _srtmService.getElevationBatch(
      points,
      resolution: ElevationResolution.visualization,
    );
    
    // Process all elevations and check for danger zones
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final elevation = elevations[i];
      
      if (elevation != null) {
        final terrainFt = elevation * 3.28084; // Convert meters to feet
        final clearance = currentAltitudeFt - terrainFt;
        
        // Determine warning level based on clearance
        TerrainWarningLevel warningLevel;
        if (clearance < 100) {
          warningLevel = TerrainWarningLevel.critical;
        } else if (clearance < 500) {
          warningLevel = TerrainWarningLevel.warning;
        } else if (clearance < 1000) {
          warningLevel = TerrainWarningLevel.caution;
        } else {
          warningLevel = TerrainWarningLevel.safe;
        }
        
        // Add danger zones (exclude safe areas)
        if (warningLevel != TerrainWarningLevel.safe) {
          zones.add(TerrainDangerZone(
            position: LatLng(point.lat, point.lon),
            terrainElevationFt: terrainFt,
            warningLevel: warningLevel,
            clearanceFt: clearance,
          ));
        }
      }
    }
    
    return zones;
  }


  /// Clear tile cache
  static Future<void> clearCache() async {
    await _srtmService.clearCache();
  }
  
  /// Clear all cached elevation data (delegates to SRTM service)
  static Future<void> clearAllCaches() async {
    await _srtmService.clearCache();
  }
  
  /// Get total cache size in bytes (delegates to SRTM service)
  static Future<int> getCacheSize() async {
    try {
      await _ensureInitialized();
      final stats = _srtmService.getCacheStats();
      final cacheDir = stats['cache_directory'] as String? ?? '';
      
      if (cacheDir.isEmpty) return 0;
      
      int totalSize = 0;
      final dir = Directory(cacheDir);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              totalSize += stat.size;
            } catch (e) {
              // Skip files we can't read
            }
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Get cache file count (delegates to SRTM service) 
  static Future<int> getCacheFileCount() async {
    try {
      await _ensureInitialized();
      final stats = _srtmService.getCacheStats();
      return (stats['cache_30m'] ?? 0) + (stats['cache_500m'] ?? 0);
    } catch (e) {
      return 0;
    }
  }

  /// Preload tiles for a route
  static Future<void> preloadRoute(List<LatLng> route) async {
    // For SRTM service, data is downloaded on demand - no preloading needed
  }

  /// Calculate minimum safe altitude for a route
  /// Returns MSA in feet with specified safety margin
  static Future<MinimumSafeAltitude> calculateMSA(
    List<LatLng> route, {
    double corridorWidthNm = 5.0, // Width of corridor to check (nautical miles)
    double safetyMarginFt = 1000.0, // Safety margin above terrain
    double sampleDistanceNm = 1.0, // Distance between sample points
  }) async {
    if (route.isEmpty) {
      return MinimumSafeAltitude(
        msaFt: 0,
        maxTerrainFt: 0,
        criticalPoint: null,
        criticalIndex: -1,
      );
    }
    
    double maxTerrainElevation = 0;
    LatLng? criticalPoint;
    int criticalIndex = -1;
    
    // Sample points along the route
    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      
      // Calculate segment distance (convert km to nautical miles)
      final segmentDistanceKm = const Distance().as(
        LengthUnit.Kilometer,
        start,
        end,
      );
      final segmentDistance = segmentDistanceKm * 0.539957; // km to nautical miles
      
      // Number of samples for this segment
      final samples = (segmentDistance / sampleDistanceNm).ceil();
      
      for (int s = 0; s <= samples; s++) {
        final t = samples > 0 ? s / samples : 0.0;
        
        // Interpolate position along segment
        final samplePoint = LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t,
        );
        
        // Check terrain in corridor around this point
        final corridorElevation = await _getMaxElevationInRadius(
          samplePoint,
          corridorWidthNm,
        );
        
        if (corridorElevation != null && corridorElevation > maxTerrainElevation) {
          maxTerrainElevation = corridorElevation;
          criticalPoint = samplePoint;
          criticalIndex = i;
        }
      }
    }
    
    // Convert to feet and add safety margin
    final maxTerrainFt = maxTerrainElevation * 3.28084;
    final msaFt = maxTerrainFt + safetyMarginFt;
    
    // Round up to nearest 100ft
    final roundedMsaFt = ((msaFt / 100).ceil() * 100).toDouble();
    
    return MinimumSafeAltitude(
      msaFt: roundedMsaFt,
      maxTerrainFt: maxTerrainFt,
      criticalPoint: criticalPoint,
      criticalIndex: criticalIndex,
      safetyMarginFt: safetyMarginFt,
      corridorWidthNm: corridorWidthNm,
    );
  }

  /// Get maximum elevation within a radius of a point
  static Future<double?> _getMaxElevationInRadius(
    LatLng center,
    double radiusNm,
  ) async {
    // Convert radius to degrees (approximate)
    final radiusDeg = radiusNm / 60.0; // 1 degree ≈ 60 nautical miles
    
    // Sample in a grid pattern (3x3 grid)
    double? maxElevation;
    
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final samplePoint = LatLng(
          center.latitude + (dy * radiusDeg / 2),
          center.longitude + (dx * radiusDeg / 2),
        );
        
        final elevation = await getElevation(samplePoint);
        if (elevation != null) {
          maxElevation = maxElevation == null 
            ? elevation 
            : math.max(maxElevation, elevation);
        }
      }
    }
    
    return maxElevation;
  }
}

/// Elevation data source types
enum ElevationSource {
  srtm, // SRTM elevation data for aviation safety
}

/// Terrain warning levels
enum TerrainWarningLevel {
  safe,      // > 1000ft clearance
  caution,   // 500-1000ft clearance
  warning,   // 100-500ft clearance
  critical,  // < 100ft clearance
  noData,    // No elevation data available
}

/// Elevation point along a path
class ElevationPoint {
  final LatLng position;
  final double elevation; // meters
  final double distance;  // meters from start
  final ElevationSource? dataSource;

  ElevationPoint({
    required this.position,
    required this.elevation,
    required this.distance,
    this.dataSource,
  });
  
  double get elevationFt => elevation * 3.28084;
}

/// Terrain clearance information
class TerrainClearance {
  final double terrainElevationFt;
  final double aircraftAltitudeFt;
  final double clearanceFt;
  final TerrainWarningLevel warningLevel;

  TerrainClearance({
    required this.terrainElevationFt,
    required this.aircraftAltitudeFt,
    required this.clearanceFt,
    required this.warningLevel,
  });
}

/// Terrain danger zone
class TerrainDangerZone {
  final LatLng position;
  final double terrainElevationFt;
  final TerrainWarningLevel warningLevel;
  final double clearanceFt;

  TerrainDangerZone({
    required this.position,
    required this.terrainElevationFt,
    required this.warningLevel,
    required this.clearanceFt,
  });
}

/// Minimum safe altitude calculation result
class MinimumSafeAltitude {
  final double msaFt;              // Minimum safe altitude in feet
  final double maxTerrainFt;       // Maximum terrain elevation found
  final LatLng? criticalPoint;     // Location of highest terrain
  final int criticalIndex;         // Route segment index with highest terrain
  final double safetyMarginFt;     // Safety margin used
  final double corridorWidthNm;    // Corridor width checked

  MinimumSafeAltitude({
    required this.msaFt,
    required this.maxTerrainFt,
    this.criticalPoint,
    required this.criticalIndex,
    this.safetyMarginFt = 1000.0,
    this.corridorWidthNm = 5.0,
  });

  /// Check if a given altitude is safe
  bool isAltitudeSafe(double altitudeFt) => altitudeFt >= msaFt;

  /// Get clearance for a given altitude
  double getClearance(double altitudeFt) => altitudeFt - maxTerrainFt;
}