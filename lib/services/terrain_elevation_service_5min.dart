import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for loading and querying terrain elevation data
/// Uses 5' × 5' tiles bundled in 1° × 1° files for maximum accuracy
class TerrainElevationService5Min {
  static String? _cacheDir;
  
  static Future<String> get cacheDir async {
    if (_cacheDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = path.join(appDir.path, 'elevation_5min');
      // Create directory if it doesn't exist
      final dir = Directory(_cacheDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    return _cacheDir!;
  }
  
  final _logger = Logger(level: Level.info);
  final Map<String, ElevationBundle> _bundleCache = {};
  final int _maxCacheSize = 20; // Maximum bundles in memory (each has 144 tiles)
  
  // CDN configuration for 5' bundles
  static const String cdnBaseUrl = 'https://captainvfr-assets-eu.s3.eu-central-1.amazonaws.com';
  static const String elevationPath = '/assets/data/tiles/elevation_5min';
  
  // Bundle format constants
  static const int TILES_PER_DEGREE = 12; // 60' / 5' = 12
  static const double TILE_SIZE_DEGREES = 5.0 / 60.0; // 5 arc-minutes

  /// Get elevation at a specific point with 5' accuracy
  Future<double?> getElevation(LatLng point) async {
    // Determine which bundle contains this point
    final bundleLat = point.latitude.floor();
    final bundleLon = point.longitude.floor();
    final bundleKey = '${bundleLat}_$bundleLon';
    
    // Load bundle if not in cache
    ElevationBundle? bundle;
    if (_bundleCache.containsKey(bundleKey)) {
      bundle = _bundleCache[bundleKey]!;
    } else {
      bundle = await _loadBundle(bundleLat, bundleLon);
      if (bundle != null) {
        // Manage cache size
        if (_bundleCache.length >= _maxCacheSize) {
          _bundleCache.remove(_bundleCache.keys.first);
        }
        _bundleCache[bundleKey] = bundle;
      }
    }
    
    if (bundle == null) {
      _logger.w('No elevation bundle available for $point');
      return null;
    }
    
    // Get elevation from the appropriate 5' tile within the bundle
    return bundle.getElevation(point.latitude, point.longitude);
  }

  /// Get elevation profile along a path with high resolution
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
    
    // For 5' tiles, we can afford higher sampling resolution
    final samples = sampleDistance != null
        ? (totalDistance / sampleDistance).ceil()
        : math.max(path.length, (totalDistance / 100).ceil()); // Sample every 100m minimum
    
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
        accuracy: elevation != null ? ElevationAccuracy.high : ElevationAccuracy.none,
      ));
      
      if (sampleDistance != null) {
        currentDistance += sampleDistance;
      } else {
        currentDistance = totalDistance * t;
      }
    }
    
    return profile;
  }

  /// Get terrain clearance with high accuracy
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
        accuracy: ElevationAccuracy.none,
      );
    }
    
    final terrainFt = terrainElevation * 3.28084; // Convert meters to feet
    final clearance = altitudeFt - terrainFt;
    
    // More precise warning levels for 5' accuracy
    TerrainWarningLevel warningLevel;
    if (clearance < 50) {
      warningLevel = TerrainWarningLevel.critical;
    } else if (clearance < 200) {
      warningLevel = TerrainWarningLevel.warning;
    } else if (clearance < 500) {
      warningLevel = TerrainWarningLevel.caution;
    } else if (clearance < 1000) {
      warningLevel = TerrainWarningLevel.advisory;
    } else {
      warningLevel = TerrainWarningLevel.safe;
    }
    
    return TerrainClearance(
      terrainElevationFt: terrainFt,
      aircraftAltitudeFt: altitudeFt,
      clearanceFt: clearance,
      warningLevel: warningLevel,
      accuracy: ElevationAccuracy.high, // 5' tiles provide high accuracy
    );
  }

  /// Load a 1° × 1° bundle containing 144 5' × 5' tiles
  Future<ElevationBundle?> _loadBundle(int lat, int lon) async {
    // Construct bundle filename
    final latPrefix = lat >= 0 ? 'N' : 'S';
    final lonPrefix = lon >= 0 ? 'E' : 'W';
    final fileName = '$latPrefix${lat.abs().toString().padLeft(2, '0')}'
                    '$lonPrefix${lon.abs().toString().padLeft(3, '0')}.hg144';
    
    // Check local cache first
    final localCacheDir = await cacheDir;
    final cachedFile = File(path.join(localCacheDir, fileName));
    
    Uint8List? bundleData;
    
    if (await cachedFile.exists()) {
      bundleData = await cachedFile.readAsBytes();
    } else {
      // Download from CDN
      bundleData = await _downloadBundle(fileName);
      if (bundleData != null) {
        // Save to local cache
        await cachedFile.writeAsBytes(bundleData);
      }
    }
    
    if (bundleData == null) {
      return null;
    }
    
    // Parse bundle
    return ElevationBundle.fromBinary(bundleData, lat, lon);
  }

  /// Download bundle from CDN
  Future<Uint8List?> _downloadBundle(String fileName) async {
    final url = '$cdnBaseUrl$elevationPath/$fileName';
    
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        _logger.w('Failed to download bundle $fileName: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error downloading bundle $fileName: $e');
    }
    
    return null;
  }

  /// Pre-load all bundles needed for a viewport
  Future<void> preloadViewport(LatLngBounds viewport) async {
    final bundlesToLoad = <String>{};
    
    // Calculate all bundle coordinates needed
    final minLat = viewport.south.floor();
    final maxLat = viewport.north.floor();
    final minLon = viewport.west.floor();
    final maxLon = viewport.east.floor();
    
    for (int lat = minLat; lat <= maxLat; lat++) {
      for (int lon = minLon; lon <= maxLon; lon++) {
        final bundleKey = '${lat}_$lon';
        if (!_bundleCache.containsKey(bundleKey)) {
          bundlesToLoad.add(bundleKey);
        }
      }
    }
    
    if (bundlesToLoad.isEmpty) return;
    
    // Load bundles in parallel
    final futures = <Future<void>>[];
    for (final bundleKey in bundlesToLoad) {
      final coords = bundleKey.split('_');
      final lat = int.parse(coords[0]);
      final lon = int.parse(coords[1]);
      
      futures.add(_loadBundleAsync(lat, lon));
    }
    
    await Future.wait(futures);
  }
  
  /// Load a bundle asynchronously
  Future<void> _loadBundleAsync(int lat, int lon) async {
    final bundleKey = '${lat}_$lon';
    
    if (_bundleCache.containsKey(bundleKey)) return;
    
    final bundle = await _loadBundle(lat, lon);
    if (bundle != null) {
      // Manage cache size
      if (_bundleCache.length >= _maxCacheSize) {
        _bundleCache.remove(_bundleCache.keys.first);
      }
      _bundleCache[bundleKey] = bundle;
    }
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

  /// Clear all caches
  void clearCache() {
    _bundleCache.clear();
  }
  
  /// Clear all cached elevation data (both memory and disk)
  static Future<void> clearAllCaches() async {
    final service = TerrainElevationService5Min();
    service.clearCache();
    
    // Clear disk cache
    final localCacheDir = await cacheDir;
    final dir = Directory(localCacheDir);
    if (await dir.exists()) {
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.hg144')) {
          await file.delete();
        }
      }
    }
  }
}

/// Elevation bundle containing 144 5' × 5' tiles
class ElevationBundle {
  final int baseLat;
  final int baseLon;
  final List<CompressedTile?> tiles; // 144 tiles (12×12)
  
  static const int TILES_PER_DEGREE = 12;
  static const double TILE_SIZE_DEGREES = 5.0 / 60.0;
  
  ElevationBundle({
    required this.baseLat,
    required this.baseLon,
    required this.tiles,
  });
  
  /// Parse bundle from binary data
  static ElevationBundle? fromBinary(Uint8List data, int lat, int lon) {
    if (data.length < 608) return null; // Minimum size: header(32) + index(576)
    
    final buffer = ByteData.view(data.buffer);
    int offset = 0;
    
    // Read header
    final magic = String.fromCharCodes(data.sublist(0, 5));
    if (magic != 'HG144') {
      return null; // Invalid format
    }
    offset += 5;
    
    final version = data[offset++];
    if (version != 1) return null;
    
    final bundleLat = buffer.getInt16(offset, Endian.big);
    offset += 2;
    final bundleLon = buffer.getInt16(offset, Endian.big);
    offset += 2;
    final tileCount = buffer.getInt16(offset, Endian.big);
    offset += 2;
    
    // Skip reserved bytes
    offset += 20;
    
    // Read index table
    final tileOffsets = <int>[];
    for (int i = 0; i < 144; i++) {
      tileOffsets.add(buffer.getInt32(offset, Endian.big));
      offset += 4;
    }
    
    // Read tiles
    final tiles = <CompressedTile?>[];
    for (int i = 0; i < 144; i++) {
      if (tileOffsets[i] == 0) {
        tiles.add(null); // NULL tile
      } else {
        final tile = CompressedTile.fromBinary(data, tileOffsets[i]);
        tiles.add(tile);
      }
    }
    
    return ElevationBundle(
      baseLat: lat,
      baseLon: lon,
      tiles: tiles,
    );
  }
  
  /// Get elevation at specific coordinates
  double? getElevation(double lat, double lon) {
    // Find which 5' tile contains this point
    final tileRow = ((lat - baseLat) * TILES_PER_DEGREE).floor().clamp(0, 11);
    final tileCol = ((lon - baseLon) * TILES_PER_DEGREE).floor().clamp(0, 11);
    final tileIndex = tileRow * TILES_PER_DEGREE + tileCol;
    
    if (tileIndex >= tiles.length) return null;
    
    final tile = tiles[tileIndex];
    if (tile == null) return null;
    
    // Get position within the 5' tile (0-1 normalized)
    final tileLat = baseLat + tileRow * TILE_SIZE_DEGREES;
    final tileLon = baseLon + tileCol * TILE_SIZE_DEGREES;
    final normalizedX = (lon - tileLon) / TILE_SIZE_DEGREES;
    final normalizedY = (lat - tileLat) / TILE_SIZE_DEGREES;
    
    return tile.getElevation(normalizedX, normalizedY);
  }
}

/// Compressed 5' × 5' tile
class CompressedTile {
  final int minElevation;
  final int maxElevation;
  final int gridSize;
  final Uint8List compressedGrid;
  final List<Peak> peaks;
  
  CompressedTile({
    required this.minElevation,
    required this.maxElevation,
    required this.gridSize,
    required this.compressedGrid,
    required this.peaks,
  });
  
  /// Parse tile from binary data
  static CompressedTile? fromBinary(Uint8List bundleData, int tileOffset) {
    final buffer = ByteData.view(bundleData.buffer);
    int offset = tileOffset;
    
    // Read tile header
    final tileRow = bundleData[offset++];
    final tileCol = bundleData[offset++];
    final minElev = buffer.getInt16(offset, Endian.big);
    offset += 2;
    final maxElev = buffer.getInt16(offset, Endian.big);
    offset += 2;
    final gridSize = bundleData[offset++];
    final peakCount = bundleData[offset++];
    final gridDataSize = buffer.getInt16(offset, Endian.big);
    offset += 2;
    offset += 2; // Skip reserved
    
    // Read peaks
    final peaks = <Peak>[];
    for (int i = 0; i < peakCount; i++) {
      final x = bundleData[offset++];
      final y = bundleData[offset++];
      final elev = buffer.getInt16(offset, Endian.big);
      offset += 2;
      peaks.add(Peak(x, y, elev));
    }
    
    // Read compressed grid
    final gridData = bundleData.sublist(offset, offset + gridDataSize);
    
    return CompressedTile(
      minElevation: minElev,
      maxElevation: maxElev,
      gridSize: gridSize,
      compressedGrid: gridData,
      peaks: peaks,
    );
  }
  
  /// Get elevation using bilinear interpolation
  double getElevation(double normalizedX, double normalizedY) {
    // Clamp to valid range
    normalizedX = normalizedX.clamp(0, 1);
    normalizedY = normalizedY.clamp(0, 1);
    
    // Map to grid coordinates
    final gx = normalizedX * (gridSize - 1);
    final gy = normalizedY * (gridSize - 1);
    
    final x0 = gx.floor();
    final x1 = math.min(x0 + 1, gridSize - 1);
    final y0 = gy.floor();
    final y1 = math.min(y0 + 1, gridSize - 1);
    
    // Read encoding type
    final encoding = compressedGrid[0];
    
    // Get four corner elevations
    final e00 = _readElevation(y0 * gridSize + x0, encoding);
    final e01 = _readElevation(y0 * gridSize + x1, encoding);
    final e10 = _readElevation(y1 * gridSize + x0, encoding);
    final e11 = _readElevation(y1 * gridSize + x1, encoding);
    
    // Bilinear interpolation
    final fx = gx - x0;
    final fy = gy - y0;
    
    final e0 = e00 + (e01 - e00) * fx;
    final e1 = e10 + (e11 - e10) * fx;
    
    return e0 + (e1 - e0) * fy;
  }
  
  /// Read elevation from compressed grid
  double _readElevation(int index, int encoding) {
    final range = maxElevation - minElevation;
    
    if (encoding == 8) {
      // 8-bit encoding
      final val = compressedGrid[1 + index];
      if (val == 255) return -32768; // Void
      return minElevation + (val * range / 254);
    } else if (encoding == 12) {
      // 12-bit encoding
      final byteIndex = 1 + (index * 3) ~/ 2;
      int val;
      if (index % 2 == 0) {
        val = (compressedGrid[byteIndex] << 4) | 
              (compressedGrid[byteIndex + 1] >> 4);
      } else {
        val = ((compressedGrid[byteIndex] & 0x0F) << 8) | 
              compressedGrid[byteIndex + 1];
      }
      if (val == 4095) return -32768; // Void
      return minElevation + (val * range / 4094);
    } else {
      // 16-bit encoding
      final byteIndex = 1 + index * 2;
      final buffer = ByteData.view(compressedGrid.buffer);
      return buffer.getInt16(byteIndex, Endian.big).toDouble();
    }
  }
}

/// Peak information for safety
class Peak {
  final int x;
  final int y;
  final int elevation;
  
  Peak(this.x, this.y, this.elevation);
}

/// Elevation point with metadata
class ElevationPoint {
  final LatLng position;
  final double elevation; // meters
  final double distance; // meters from start
  final ElevationAccuracy accuracy;
  
  ElevationPoint({
    required this.position,
    required this.elevation,
    required this.distance,
    required this.accuracy,
  });
}

/// Terrain clearance information
class TerrainClearance {
  final double terrainElevationFt;
  final double aircraftAltitudeFt;
  final double clearanceFt;
  final TerrainWarningLevel warningLevel;
  final ElevationAccuracy accuracy;
  
  TerrainClearance({
    required this.terrainElevationFt,
    required this.aircraftAltitudeFt,
    required this.clearanceFt,
    required this.warningLevel,
    required this.accuracy,
  });
}

/// Terrain warning levels with more granularity
enum TerrainWarningLevel {
  critical,  // < 50ft
  warning,   // 50-200ft
  caution,   // 200-500ft
  advisory,  // 500-1000ft
  safe,      // > 1000ft
  noData,    // No elevation data
}

/// Elevation data accuracy
enum ElevationAccuracy {
  high,   // 5' tiles (±5-8m)
  medium, // Fallback data
  low,    // Synthetic
  none,   // No data
}