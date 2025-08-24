import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import '../services/tiled_data_loader.dart';
import '../config/environment.dart';

/// Service for loading and querying terrain elevation data
/// Combines high-precision Sonny's LiDAR data (Europe) with global SRTM coverage
class TerrainElevationService {
  static const String sonnyDataDir = 'elevation_data/sonny_lidar';
  static const String srtmDataDir = 'elevation_data/srtm';
  static const String cacheDir = 'elevation_data/cache';
  
  final _logger = Logger(level: Level.info);
  final Map<String, ElevationTile> _tileCache = {};
  final int _maxCacheSize = 50; // Maximum tiles in memory
  
  // Elevation data sources in priority order
  static const List<ElevationSource> dataSources = [
    ElevationSource.sonnyLidar,  // Highest accuracy (Europe)
    ElevationSource.srtm,         // Global coverage
    ElevationSource.openElevation, // Online fallback
  ];

  /// Get elevation at a specific point
  Future<double?> getElevation(LatLng point) async {
    // Try each data source in priority order
    for (final source in dataSources) {
      final elevation = await _getElevationFromSource(point, source);
      if (elevation != null) {
        return elevation;
      }
    }
    
    _logger.w('No elevation data available for $point');
    return null;
  }

  /// Get elevation profile along a path
  Future<List<ElevationPoint>> getElevationProfile(
    List<LatLng> path, {
    double? sampleDistance, // meters between samples
  }) async {
    final profile = <ElevationPoint>[];
    
    if (path.isEmpty) return profile;
    
    // Calculate total distance
    double totalDistance = 0;
    for (int i = 1; i < path.length; i++) {
      totalDistance += const Distance().as(
        LengthUnit.Meter,
        path[i - 1],
        path[i],
      );
    }
    
    // Determine sampling strategy
    final samples = sampleDistance != null
        ? (totalDistance / sampleDistance).ceil()
        : path.length;
    
    // Sample elevation along path
    double currentDistance = 0;
    for (int i = 0; i < samples; i++) {
      final t = i / (samples - 1);
      final point = _interpolatePoint(path, t);
      final elevation = await getElevation(point);
      
      profile.add(ElevationPoint(
        position: point,
        elevation: elevation ?? 0,
        distance: currentDistance,
        dataSource: _getDataSourceForPoint(point),
      ));
      
      if (sampleDistance != null) {
        currentDistance += sampleDistance;
      }
    }
    
    return profile;
  }

  /// Get terrain clearance for current position and altitude
  Future<TerrainClearance> getTerrainClearance(
    LatLng position,
    double altitudeFt,
  ) async {
    final terrainElevation = await getElevation(position);
    
    if (terrainElevation == null) {
      return TerrainClearance(
        terrainElevationFt: 0,
        aircraftAltitudeFt: altitudeFt,
        clearanceFt: altitudeFt,
        warningLevel: TerrainWarningLevel.noData,
      );
    }
    
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
  Future<List<TerrainDangerZone>> getTerrainDangerZones(
    LatLngBounds viewport,
    double currentAltitudeFt, {
    double gridResolution = 0.01, // degrees
  }) async {
    final zones = <TerrainDangerZone>[];
    
    // Sample terrain in grid pattern
    final latSteps = ((viewport.north - viewport.south) / gridResolution).ceil();
    final lonSteps = ((viewport.east - viewport.west) / gridResolution).ceil();
    
    for (int latStep = 0; latStep <= latSteps; latStep++) {
      for (int lonStep = 0; lonStep <= lonSteps; lonStep++) {
        final lat = viewport.south + (latStep * gridResolution);
        final lon = viewport.west + (lonStep * gridResolution);
        final point = LatLng(lat, lon);
        
        final clearance = await getTerrainClearance(point, currentAltitudeFt);
        
        if (clearance.warningLevel != TerrainWarningLevel.safe &&
            clearance.warningLevel != TerrainWarningLevel.noData) {
          zones.add(TerrainDangerZone(
            position: point,
            terrainElevationFt: clearance.terrainElevationFt,
            warningLevel: clearance.warningLevel,
            clearanceFt: clearance.clearanceFt,
          ));
        }
      }
    }
    
    return zones;
  }

  /// Get elevation from specific data source
  Future<double?> _getElevationFromSource(
    LatLng point,
    ElevationSource source,
  ) async {
    switch (source) {
      case ElevationSource.sonnyLidar:
        return await _getElevationFromHgt(point, sonnyDataDir);
      
      case ElevationSource.srtm:
        return await _getElevationFromHgt(point, srtmDataDir);
      
      case ElevationSource.openElevation:
        return await _getElevationFromApi(point);
    }
  }

  /// Read elevation from HGT file (Sonny's or SRTM)
  Future<double?> _getElevationFromHgt(LatLng point, String dataDir) async {
    // Calculate tile coordinates
    final tileLat = point.latitude.floor();
    final tileLon = point.longitude.floor();
    final tileKey = '${tileLat}_$tileLon';
    
    // Check cache
    if (_tileCache.containsKey(tileKey)) {
      return _tileCache[tileKey]!.getElevation(point);
    }
    
    // Construct HGT filename
    final latPrefix = tileLat >= 0 ? 'N' : 'S';
    final lonPrefix = tileLon >= 0 ? 'E' : 'W';
    final fileName = '$latPrefix${tileLat.abs().toString().padLeft(2, '0')}'
                    '$lonPrefix${tileLon.abs().toString().padLeft(3, '0')}.hgt';
    
    // Try to find file in country subdirectories (for Sonny's data)
    File? hgtFile;
    final dataDirectory = Directory(dataDir);
    
    if (await dataDirectory.exists()) {
      // Search in subdirectories
      await for (final entity in dataDirectory.list(recursive: true)) {
        if (entity is File && path.basename(entity.path) == fileName) {
          hgtFile = entity;
          break;
        }
      }
    }
    
    if (hgtFile == null || !await hgtFile.exists()) {
      return null;
    }
    
    // Load tile into cache
    final tile = await ElevationTile.loadFromHgt(hgtFile);
    
    // Manage cache size
    if (_tileCache.length >= _maxCacheSize) {
      _tileCache.remove(_tileCache.keys.first);
    }
    
    _tileCache[tileKey] = tile;
    
    return tile.getElevation(point);
  }

  /// Get elevation from OpenElevation API (fallback)
  Future<double?> _getElevationFromApi(LatLng point) async {
    try {
      final url = 'https://api.open-elevation.com/api/v1/lookup'
                 '?locations=${point.latitude},${point.longitude}';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          return (results[0]['elevation'] as num).toDouble();
        }
      }
    } catch (e) {
      _logger.w('OpenElevation API error: $e');
    }
    
    return null;
  }

  /// Determine which data source is available for a point
  ElevationSource? _getDataSourceForPoint(LatLng point) {
    // Check if point is in Europe (roughly)
    if (point.latitude >= 35 && point.latitude <= 72 &&
        point.longitude >= -11 && point.longitude <= 40) {
      return ElevationSource.sonnyLidar;
    }
    return ElevationSource.srtm;
  }

  /// Interpolate point along path
  LatLng _interpolatePoint(List<LatLng> path, double t) {
    if (path.length < 2) return path.first;
    
    final totalLength = path.length - 1;
    final segment = (t * totalLength).floor();
    final localT = (t * totalLength) - segment;
    
    if (segment >= path.length - 1) return path.last;
    
    final p1 = path[segment];
    final p2 = path[segment + 1];
    
    return LatLng(
      p1.latitude + (p2.latitude - p1.latitude) * localT,
      p1.longitude + (p2.longitude - p1.longitude) * localT,
    );
  }

  /// Clear tile cache
  void clearCache() {
    _tileCache.clear();
  }

  /// Preload tiles for a route
  Future<void> preloadRoute(List<LatLng> route) async {
    final tiles = <String>{};
    
    for (final point in route) {
      final tileLat = point.latitude.floor();
      final tileLon = point.longitude.floor();
      tiles.add('${tileLat}_$tileLon');
    }
    
    _logger.i('Preloading ${tiles.length} elevation tiles for route');
    
    for (final tileKey in tiles) {
      final coords = tileKey.split('_');
      final lat = double.parse(coords[0]);
      final lon = double.parse(coords[1]);
      await getElevation(LatLng(lat + 0.5, lon + 0.5));
    }
  }
}

/// Elevation data source types
enum ElevationSource {
  sonnyLidar,    // High-precision LiDAR (Europe)
  srtm,          // Shuttle Radar Topography Mission
  openElevation, // Online API fallback
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

/// Elevation tile data handler
class ElevationTile {
  final int latOrigin;
  final int lonOrigin;
  final int resolution; // points per degree (3601 for 1", 1201 for 3")
  final Uint16List elevationData;

  ElevationTile({
    required this.latOrigin,
    required this.lonOrigin,
    required this.resolution,
    required this.elevationData,
  });

  /// Load tile from HGT file
  static Future<ElevationTile> loadFromHgt(File hgtFile) async {
    final fileName = path.basenameWithoutExtension(hgtFile.path);
    
    // Parse coordinates from filename
    final latMatch = RegExp(r'([NS])(\d+)').firstMatch(fileName);
    final lonMatch = RegExp(r'([EW])(\d+)').firstMatch(fileName);
    
    if (latMatch == null || lonMatch == null) {
      throw Exception('Invalid HGT filename: $fileName');
    }
    
    final lat = int.parse(latMatch.group(2)!) * 
                (latMatch.group(1) == 'S' ? -1 : 1);
    final lon = int.parse(lonMatch.group(2)!) * 
                (lonMatch.group(1) == 'W' ? -1 : 1);
    
    final bytes = await hgtFile.readAsBytes();
    
    // Determine resolution from file size
    int resolution;
    if (bytes.length == 3601 * 3601 * 2) {
      resolution = 3601; // 1 arc-second
    } else if (bytes.length == 1201 * 1201 * 2) {
      resolution = 1201; // 3 arc-seconds
    } else {
      throw Exception('Invalid HGT file size: ${bytes.length}');
    }
    
    // Convert to Uint16List (big-endian to platform endian)
    final elevationData = Uint16List(resolution * resolution);
    for (int i = 0; i < elevationData.length; i++) {
      final byteIndex = i * 2;
      elevationData[i] = (bytes[byteIndex] << 8) | bytes[byteIndex + 1];
    }
    
    return ElevationTile(
      latOrigin: lat,
      lonOrigin: lon,
      resolution: resolution,
      elevationData: elevationData,
    );
  }

  /// Get elevation at specific point
  double? getElevation(LatLng point) {
    // Check if point is within tile bounds
    if (point.latitude < latOrigin || point.latitude > latOrigin + 1 ||
        point.longitude < lonOrigin || point.longitude > lonOrigin + 1) {
      return null;
    }
    
    // Calculate indices (HGT data is stored from north to south)
    final latFraction = point.latitude - latOrigin;
    final lonFraction = point.longitude - lonOrigin;
    
    final row = ((1 - latFraction) * (resolution - 1)).round();
    final col = (lonFraction * (resolution - 1)).round();
    
    final index = row * resolution + col;
    
    if (index < 0 || index >= elevationData.length) {
      return null;
    }
    
    final elevation = elevationData[index];
    
    // Check for void data
    if (elevation == 0x8000 || elevation == 32768) {
      return null;
    }
    
    // Handle signed values
    if (elevation > 32767) {
      return (elevation - 65536).toDouble();
    }
    
    return elevation.toDouble();
  }
}