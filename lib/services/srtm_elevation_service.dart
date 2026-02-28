import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:archive/archive.dart';

/// SRTM file download/availability states
enum _SrtmFileState {
  downloading,    // Currently being downloaded
  available,      // Successfully downloaded and cached
  notAvailable,   // Known to be unavailable (404, parse error, etc.)
}

/// Resolution type for elevation queries
enum ElevationResolution {
  /// High-resolution 30m data for precise elevation queries
  precise,
  
  /// Low-resolution 500m data for fast map visualization
  visualization,
}

/// Notification when new elevation data becomes available
class ElevationDataAvailableEvent {
  final String filename;
  final ElevationResolution resolution;
  final LatLngBounds coverage;
  
  ElevationDataAvailableEvent({
    required this.filename,
    required this.resolution,
    required this.coverage,
  });
}

/// Modern SRTM-based elevation service with dual resolution support
/// - 30m resolution: Precise elevation queries (user clicks, flight planning)
/// - 500m resolution: Fast map layer visualization
class SrtmElevationService {
  // CDN base URLs for different resolutions
  static const String _baseUrl30m = 'https://assets.captainvfr.com/srtm_data/30m';
  static const String _baseUrl500m = 'https://assets.captainvfr.com/srtm_500';
  
  // Cache configuration
  static const int _maxCacheSize = 30 * 1024 * 1024 * 1024; // 30GB in bytes
  
  // SRTM tile configuration (constants for future use)
  // static const int _srtm30mSize = 3601;     // 30m SRTM: 3601x3601 pixels per 1° tile
  // static const int _srtm500mSize = 211;     // 500m SRTM: 211x211 pixels per 1° tile
  
  // Memory caches for different resolutions
  final Map<String, SrtmFile> _cache30m = {};
  final Map<String, SrtmFile> _cache500m = {};
  
  // Download state tracking
  final Map<String, _SrtmFileState> _fileStates30m = {};
  final Map<String, _SrtmFileState> _fileStates500m = {};
  final Map<String, Future<SrtmFile?>> _activeDownloads30m = {};
  final Map<String, Future<SrtmFile?>> _activeDownloads500m = {};
  
  // Persistent cache for unavailable files
  final Set<String> _notAvailableFiles30m = {};
  final Set<String> _notAvailableFiles500m = {};
  
  // Stream for elevation data availability notifications
  final StreamController<ElevationDataAvailableEvent> _elevationDataController = 
      StreamController<ElevationDataAvailableEvent>.broadcast();
  
  late String _cacheDir;
  late String _notAvailableCache30m;
  late String _notAvailableCache500m;
  
  /// Stream of new elevation data availability events
  Stream<ElevationDataAvailableEvent> get elevationDataAvailable => _elevationDataController.stream;
  
  /// Initialize the SRTM elevation service
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = path.join(appDir.path, 'srtm_cache');
      _notAvailableCache30m = path.join(_cacheDir, 'not_available_30m.txt');
      _notAvailableCache500m = path.join(_cacheDir, 'not_available_500m.txt');
      
      await Directory(_cacheDir).create(recursive: true);
      await Directory(path.join(_cacheDir, '30m')).create(recursive: true);
      await Directory(path.join(_cacheDir, '500m')).create(recursive: true);
      
      // Load persistent caches
      await _loadNotAvailableCache(ElevationResolution.precise);
      await _loadNotAvailableCache(ElevationResolution.visualization);
      
      debugPrint('SrtmElevation: Service initialized with cache at $_cacheDir');
    } catch (e) {
      debugPrint('SrtmElevation: Failed to initialize: $e');
      _cacheDir = '';
    }
  }
  
  /// Get elevation at specific coordinates
  /// 
  /// [resolution] determines data source:
  /// - ElevationResolution.precise: 30m data for exact elevation queries
  /// - ElevationResolution.visualization: 500m data for map visualization
  Future<double?> getElevation(
    double latitude, 
    double longitude, {
    ElevationResolution resolution = ElevationResolution.precise,
  }) async {
    try {
      final filename = _getSrtmFilename(latitude, longitude);
      var srtmFile = await _loadSrtmFile(filename, resolution);
      
      // If 30m data is not available, automatically fallback to 500m data
      if (srtmFile == null && resolution == ElevationResolution.precise) {
        debugPrint('SrtmElevation: 30m data not available for $filename, falling back to 500m');
        srtmFile = await _loadSrtmFile(filename, ElevationResolution.visualization);
      }
      
      if (srtmFile == null) {
        return null;
      }
      
      return srtmFile.getElevation(latitude, longitude);
    } catch (e) {
      debugPrint('SrtmElevation: Error getting elevation: $e');
      return null;
    }
  }
  
  /// Get elevation for multiple points efficiently (batch processing)
  Future<List<double?>> getElevationBatch(
    List<({double lat, double lon})> points, {
    ElevationResolution resolution = ElevationResolution.precise,
  }) async {
    final results = <double?>[];
    final fileCache = <String, SrtmFile?>{};
    
    for (final point in points) {
      try {
        final filename = _getSrtmFilename(point.lat, point.lon);
        
        // Use local cache for this batch to avoid repeated downloads
        SrtmFile? srtmFile = fileCache[filename];
        if (srtmFile == null) {
          srtmFile = await _loadSrtmFile(filename, resolution);
          
          // If 30m data is not available, automatically fallback to 500m data
          if (srtmFile == null && resolution == ElevationResolution.precise) {
            srtmFile = await _loadSrtmFile(filename, ElevationResolution.visualization);
          }
          
          fileCache[filename] = srtmFile;
        }
        
        final elevation = srtmFile?.getElevation(point.lat, point.lon);
        results.add(elevation);
      } catch (e) {
        debugPrint('SrtmElevation: Error in batch processing: $e');
        results.add(null);
      }
    }
    
    return results;
  }
  
  /// Generate SRTM filename from coordinates
  String _getSrtmFilename(double latitude, double longitude) {
    final lat = latitude.floor();
    final lon = longitude.floor();
    
    final latStr = lat >= 0 ? 'N${lat.toString().padLeft(2, '0')}' 
                            : 'S${lat.abs().toString().padLeft(2, '0')}';
    final lonStr = lon >= 0 ? 'E${lon.toString().padLeft(3, '0')}' 
                            : 'W${lon.abs().toString().padLeft(3, '0')}';
    
    return '$latStr$lonStr';
  }
  
  /// Get the geographic coverage bounds for an SRTM filename
  LatLngBounds _getFilenameCoverage(String filename) {
    // Parse filename like "N48E016" or "S23W045"
    final latMatch = RegExp(r'([NS])(\d{2})').firstMatch(filename);
    final lonMatch = RegExp(r'([EW])(\d{3})').firstMatch(filename);
    
    if (latMatch == null || lonMatch == null) {
      // Fallback for invalid filenames
      return LatLngBounds(const LatLng(0, 0), const LatLng(1, 1));
    }
    
    final latSign = latMatch.group(1) == 'N' ? 1 : -1;
    final latValue = int.parse(latMatch.group(2)!) * latSign;
    final lonSign = lonMatch.group(1) == 'E' ? 1 : -1;
    final lonValue = int.parse(lonMatch.group(2)!) * lonSign;
    
    // SRTM tiles cover exactly 1 degree x 1 degree
    final south = latValue.toDouble();
    final north = latValue.toDouble() + 1.0;
    final west = lonValue.toDouble();
    final east = lonValue.toDouble() + 1.0;
    
    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }
  
  /// Load SRTM file with caching and download management
  Future<SrtmFile?> _loadSrtmFile(String filename, ElevationResolution resolution) async {
    final is30m = resolution == ElevationResolution.precise;
    final cache = is30m ? _cache30m : _cache500m;
    final fileStates = is30m ? _fileStates30m : _fileStates500m;
    final activeDownloads = is30m ? _activeDownloads30m : _activeDownloads500m;
    final notAvailable = is30m ? _notAvailableFiles30m : _notAvailableFiles500m;
    
    // Check memory cache
    if (cache.containsKey(filename)) {
      return cache[filename];
    }
    
    // Check if known unavailable
    if (notAvailable.contains(filename) || 
        fileStates[filename] == _SrtmFileState.notAvailable) {
      return null;
    }
    
    // Check local file cache
    final ext = is30m ? '.hgt.gz' : '.hgt';
    final subDir = is30m ? '30m' : '500m';
    final localPath = path.join(_cacheDir, subDir, '$filename$ext');
    final localFile = File(localPath);
    
    if (await localFile.exists()) {
      try {
        final data = await localFile.readAsBytes();
        
        // Update access time for LRU tracking
        await _updateFileAccessTime(localPath);
        
        final srtmFile = is30m 
            ? SrtmFile.fromHgt(data, filename, isCompressed: true)  // 30m files are .hgt.gz
            : SrtmFile.fromHgt(data, filename, isCompressed: false); // 500m files are raw .hgt
            
        if (srtmFile != null) {
          _cacheInMemory(filename, srtmFile, resolution);
          
          // For local files, emit event only if this is the first load (not in memory cache)
          if (!cache.containsKey(filename)) {
            _elevationDataController.add(ElevationDataAvailableEvent(
              filename: filename,
              resolution: resolution,
              coverage: _getFilenameCoverage(filename),
            ));
          }
          
          return srtmFile;
        }
      } catch (e) {
        debugPrint('SrtmElevation: Error loading cached file: $e');
      }
    }
    
    // Use atomic download to prevent duplicates
    final downloadFuture = activeDownloads.putIfAbsent(filename, () {
      fileStates[filename] = _SrtmFileState.downloading;
      return _downloadAndProcessFile(filename, resolution).whenComplete(() {
        activeDownloads.remove(filename);
      });
    });
    
    return await downloadFuture;
  }
  
  /// Download and process SRTM file
  Future<SrtmFile?> _downloadAndProcessFile(String filename, ElevationResolution resolution) async {
    final is30m = resolution == ElevationResolution.precise;
    final baseUrl = is30m ? _baseUrl30m : _baseUrl500m;
    final ext = is30m ? '.hgt.gz' : '.hgt';
    final subDir = is30m ? '30m' : '500m';
    
    try {
      debugPrint('SrtmElevation: Downloading ${is30m ? "30m" : "500m"} file: $filename');
      
      final url = '$baseUrl/$filename$ext';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        
        // Save to local cache
        if (_cacheDir.isNotEmpty) {
          final localPath = path.join(_cacheDir, subDir, '$filename$ext');
          final localFile = File(localPath);
          await localFile.create(recursive: true);
          await localFile.writeAsBytes(data);
          
          // Check cache size after saving new file
          await _manageCacheSize();
        }
        
        // Parse SRTM file
        debugPrint('SrtmElevation: Downloaded ${data.length} bytes for $filename$ext');
        final srtmFile = is30m 
            ? SrtmFile.fromHgt(data, filename, isCompressed: true)  // 30m files are .hgt.gz
            : SrtmFile.fromHgt(data, filename, isCompressed: false); // 500m files are raw .hgt
            
        if (srtmFile != null) {
          debugPrint('SrtmElevation: Successfully parsed $filename with ${is30m ? "30m" : "500m"} resolution');
          _updateFileState(filename, _SrtmFileState.available, resolution);
          _cacheInMemory(filename, srtmFile, resolution);
          
          // Notify that new elevation data is available
          _elevationDataController.add(ElevationDataAvailableEvent(
            filename: filename,
            resolution: resolution,
            coverage: _getFilenameCoverage(filename),
          ));
          
          debugPrint('SrtmElevation: New ${resolution == ElevationResolution.precise ? "30m" : "500m"} data available for $filename');
          
          return srtmFile;
        }
      } else if (response.statusCode == 404) {
        await _addToNotAvailableCache(filename, resolution);
      }
      
      _updateFileState(filename, _SrtmFileState.notAvailable, resolution);
      return null;
    } catch (e) {
      debugPrint('SrtmElevation: Download error for $filename: $e');
      _updateFileState(filename, _SrtmFileState.notAvailable, resolution);
      await _addToNotAvailableCache(filename, resolution);
      return null;
    }
  }
  
  /// Cache SRTM file in memory with size management
  void _cacheInMemory(String filename, SrtmFile srtmFile, ElevationResolution resolution) {
    final cache = resolution == ElevationResolution.precise ? _cache30m : _cache500m;
    final maxCacheSize = resolution == ElevationResolution.precise ? 3 : 10; // Smaller cache for 30m due to size
    
    if (cache.length >= maxCacheSize) {
      // Simple LRU: clear oldest entries
      final keysToRemove = cache.keys.take(cache.length - maxCacheSize + 1).toList();
      for (final key in keysToRemove) {
        cache.remove(key);
      }
    }
    
    cache[filename] = srtmFile;
  }
  
  /// Update file state
  void _updateFileState(String filename, _SrtmFileState state, ElevationResolution resolution) {
    if (resolution == ElevationResolution.precise) {
      _fileStates30m[filename] = state;
    } else {
      _fileStates500m[filename] = state;
    }
  }
  
  /// Load persistent not-available cache
  Future<void> _loadNotAvailableCache(ElevationResolution resolution) async {
    try {
      final file = File(resolution == ElevationResolution.precise 
          ? _notAvailableCache30m 
          : _notAvailableCache500m);
          
      if (await file.exists()) {
        final lines = await file.readAsLines();
        final notAvailable = resolution == ElevationResolution.precise 
            ? _notAvailableFiles30m 
            : _notAvailableFiles500m;
            
        notAvailable.addAll(lines.where((line) => line.trim().isNotEmpty));
        
        debugPrint('SrtmElevation: Loaded ${notAvailable.length} not-available ${resolution == ElevationResolution.precise ? "30m" : "500m"} files');
      }
    } catch (e) {
      debugPrint('SrtmElevation: Error loading not-available cache: $e');
    }
  }
  
  /// Add file to not-available cache
  Future<void> _addToNotAvailableCache(String filename, ElevationResolution resolution) async {
    final notAvailable = resolution == ElevationResolution.precise 
        ? _notAvailableFiles30m 
        : _notAvailableFiles500m;
        
    if (notAvailable.add(filename)) {
      try {
        final file = File(resolution == ElevationResolution.precise 
            ? _notAvailableCache30m 
            : _notAvailableCache500m);
            
        await file.writeAsString(notAvailable.join('\n'));
      } catch (e) {
        debugPrint('SrtmElevation: Error saving not-available cache: $e');
      }
    }
  }
  
  /// Clear all caches (instance method)
  Future<void> clearCache() async {
    _cache30m.clear();
    _cache500m.clear();
    _fileStates30m.clear();
    _fileStates500m.clear();
    _activeDownloads30m.clear();
    _activeDownloads500m.clear();
    _notAvailableFiles30m.clear();
    _notAvailableFiles500m.clear();
    
    // Clear cache files
    try {
      final dir = Directory(_cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('SrtmElevation: Error clearing cache: $e');
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cache_30m': _cache30m.length,
      'cache_500m': _cache500m.length,
      'not_available_30m': _notAvailableFiles30m.length,
      'not_available_500m': _notAvailableFiles500m.length,
      'active_downloads_30m': _activeDownloads30m.length,
      'active_downloads_500m': _activeDownloads500m.length,
      'cache_directory': _cacheDir,
    };
  }
  
  /// Get total cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'srtm_cache'));
      int totalSize = 0;
      
      // Calculate size of 30m files
      final dir30m = Directory('${cacheDir.path}/30m');
      if (await dir30m.exists()) {
        await for (final entity in dir30m.list()) {
          if (entity is File && entity.path.endsWith('.hgt.gz')) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
      
      // Calculate size of 500m files
      final dir500m = Directory('${cacheDir.path}/500m');
      if (await dir500m.exists()) {
        await for (final entity in dir500m.list()) {
          if (entity is File && entity.path.endsWith('.hgt')) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
      
      // Calculate size of contour tiles
      final dirContour = Directory('${cacheDir.path}/contour_tiles');
      if (await dirContour.exists()) {
        await for (final entity in dirContour.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.geojson')) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('SrtmElevationService: Error calculating cache size: $e');
      return 0;
    }
  }
  
  /// Get total number of cached files
  static Future<int> getCacheFileCount() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'srtm_cache'));
      int totalCount = 0;
      
      // Count 30m files
      final dir30m = Directory('${cacheDir.path}/30m');
      if (await dir30m.exists()) {
        await for (final entity in dir30m.list()) {
          if (entity is File && entity.path.endsWith('.hgt.gz')) {
            totalCount++;
          }
        }
      }
      
      // Count 500m files
      final dir500m = Directory('${cacheDir.path}/500m');
      if (await dir500m.exists()) {
        await for (final entity in dir500m.list()) {
          if (entity is File && entity.path.endsWith('.hgt')) {
            totalCount++;
          }
        }
      }
      
      // Count contour tile files
      final dirContour = Directory('${cacheDir.path}/contour_tiles');
      if (await dirContour.exists()) {
        await for (final entity in dirContour.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.geojson')) {
            totalCount++;
          }
        }
      }
      
      return totalCount;
    } catch (e) {
      debugPrint('SrtmElevationService: Error counting cache files: $e');
      return 0;
    }
  }
  
  /// Clear all cached SRTM data (static method)
  static Future<void> clearCacheStatic() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'srtm_cache'));
      
      // Clear 30m cache
      final dir30m = Directory('${cacheDir.path}/30m');
      if (await dir30m.exists()) {
        await dir30m.delete(recursive: true);
      }
      
      // Clear 500m cache
      final dir500m = Directory('${cacheDir.path}/500m');
      if (await dir500m.exists()) {
        await dir500m.delete(recursive: true);
      }
      
      // Clear contour tiles cache
      final dirContour = Directory('${cacheDir.path}/contour_tiles');
      if (await dirContour.exists()) {
        await dirContour.delete(recursive: true);
      }
      
      debugPrint('SrtmElevationService: Cache cleared successfully');
    } catch (e) {
      debugPrint('SrtmElevationService: Error clearing cache: $e');
    }
  }
  
  /// Check and manage cache size with LRU eviction
  static Future<void> _manageCacheSize() async {
    try {
      final currentSize = await getCacheSize();
      
      if (currentSize > _maxCacheSize) {
        debugPrint('SrtmElevationService: Cache size ${(currentSize / 1024 / 1024 / 1024).toStringAsFixed(2)}GB exceeds limit, performing LRU eviction');
        
        final appDir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory(path.join(appDir.path, 'srtm_cache'));
        
        // Collect all cache files with their access times
        final List<MapEntry<File, DateTime>> fileList = [];
        
        // Check 30m files
        final dir30m = Directory('${cacheDir.path}/30m');
        if (await dir30m.exists()) {
          await for (final entity in dir30m.list()) {
            if (entity is File && entity.path.endsWith('.hgt.gz')) {
              final stat = await entity.stat();
              fileList.add(MapEntry(entity, stat.accessed));
            }
          }
        }
        
        // Check 500m files
        final dir500m = Directory('${cacheDir.path}/500m');
        if (await dir500m.exists()) {
          await for (final entity in dir500m.list()) {
            if (entity is File && entity.path.endsWith('.hgt')) {
              final stat = await entity.stat();
              fileList.add(MapEntry(entity, stat.accessed));
            }
          }
        }
        
        // Check contour files
        final dirContour = Directory('${cacheDir.path}/contour_tiles');
        if (await dirContour.exists()) {
          await for (final entity in dirContour.list(recursive: true)) {
            if (entity is File && entity.path.endsWith('.geojson')) {
              final stat = await entity.stat();
              fileList.add(MapEntry(entity, stat.accessed));
            }
          }
        }
        
        // Sort by access time (oldest first)
        fileList.sort((a, b) => a.value.compareTo(b.value));
        
        // Delete oldest files until we're under 80% of the limit
        final targetSize = (_maxCacheSize * 0.8).round();
        int deletedSize = 0;
        int deletedCount = 0;
        
        for (final entry in fileList) {
          if (currentSize - deletedSize <= targetSize) {
            break;
          }
          
          try {
            final stat = await entry.key.stat();
            await entry.key.delete();
            deletedSize += stat.size;
            deletedCount++;
          } catch (e) {
            // Continue if we can't delete a file
          }
        }
        
        if (deletedCount > 0) {
          debugPrint('SrtmElevationService: Evicted $deletedCount files (${(deletedSize / 1024 / 1024).toStringAsFixed(2)}MB)');
        }
      }
    } catch (e) {
      debugPrint('SrtmElevationService: Error managing cache size: $e');
    }
  }
  
  /// Update file access time (for LRU tracking)
  static Future<void> _updateFileAccessTime(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        // Touch the file to update access time
        final now = DateTime.now();
        await file.setLastAccessed(now);
      }
    } catch (e) {
      // Silently ignore - not critical
    }
  }

  /// Dispose of resources
  void dispose() {
    _elevationDataController.close();
  }
}

/// Represents a single SRTM file with elevation data
class SrtmFile {
  final String filename;
  final int size;
  final Uint16List elevationData;
  
  SrtmFile({
    required this.filename,
    required this.size,
    required this.elevationData,
  });
  
  /// Create SRTM file from HGT format (both 30m and 500m resolution)
  static SrtmFile? fromHgt(Uint8List data, String filename, {bool isCompressed = false}) {
    try {
      Uint8List hgtData = data;
      
      // Decompress if needed
      if (isCompressed) {
        try {
          hgtData = GZipDecoder().decodeBytes(data);
          debugPrint('SrtmFile: Decompressed ${data.length} bytes to ${hgtData.length} bytes');
        } catch (e) {
          debugPrint('SrtmFile: Failed to decompress HGT.gz file: $e');
          return null;
        }
      }
      
      // HGT format: raw 16-bit signed big-endian elevation values
      // 30m SRTM: 3601x3601 pixels = 25,934,402 bytes
      // 500m SRTM: 211x211 pixels = 89,042 bytes
      final expected30mSize = 3601 * 3601 * 2;
      final expected500mSize = 211 * 211 * 2;
      
      // Determine size based on data length
      final size = hgtData.length == expected30mSize ? 3601 :
                   hgtData.length == expected500mSize ? 211 :
                   sqrt(hgtData.length / 2).round();
      
      if (hgtData.length != size * size * 2) {
        debugPrint('SrtmFile: Invalid HGT file size: ${hgtData.length} bytes (expected ${size * size * 2})');
        return null;
      }
      
      final elevationData = Uint16List(size * size);
      
      // Parse big-endian 16-bit values
      for (int i = 0; i < elevationData.length; i++) {
        final offset = i * 2;
        if (offset + 1 < hgtData.length) {
          final high = hgtData[offset];
          final low = hgtData[offset + 1];
          elevationData[i] = (high << 8) | low;
        }
      }
      
      debugPrint('SrtmFile: Successfully parsed HGT file with ${size}x$size pixels');
      return SrtmFile(
        filename: filename,
        size: size,
        elevationData: elevationData,
      );
    } catch (e) {
      debugPrint('SrtmFile: Error parsing HGT file: $e');
      return null;
    }
  }
  
  /// Create SRTM file from TIFF format (30m resolution)
  static SrtmFile? fromTiff(Uint8List data, String filename) {
    try {
      // TIFF parser for SRTM 30m data
      if (data.length < 8) {
        debugPrint('SrtmFile: TIFF file too small');
        return null;
      }
      
      // Check TIFF magic number (II for little-endian, MM for big-endian)
      final isLittleEndian = data[0] == 0x49 && data[1] == 0x49;
      final isBigEndian = data[0] == 0x4D && data[1] == 0x4D;
      
      if (!isLittleEndian && !isBigEndian) {
        debugPrint('SrtmFile: Not a valid TIFF file');
        return null;
      }
      
      final byteData = ByteData.sublistView(data);
      final endian = isLittleEndian ? Endian.little : Endian.big;
      
      // Get TIFF version and first IFD offset
      final version = byteData.getUint16(2, endian);
      final ifdOffset = byteData.getUint32(4, endian);
      
      if (version != 42) {
        debugPrint('SrtmFile: Unexpected TIFF version: $version');
        return null;
      }
      
      // Read IFD to find image data location
      if (ifdOffset >= data.length - 2) {
        debugPrint('SrtmFile: IFD offset out of bounds');
        return null;
      }
      
      final numEntries = byteData.getUint16(ifdOffset, endian);
      debugPrint('SrtmFile: TIFF IFD has $numEntries entries at offset $ifdOffset');
      
      // TIFF tags we need
      int imageWidth = 0;
      int imageHeight = 0;
      int stripOffset = 0;
      int tileOffset = 0;
      int stripByteCount = 0;
      int rowsPerStrip = 0;
      List<int> stripOffsets = [];
      List<int> stripByteCounts = [];
      // Tile-based TIFF support
      int tileWidth = 0;
      int tileLength = 0;
      List<int> tileOffsets = [];
      List<int> tileByteCounts = [];
      // int bitsPerSample = 16; // Currently unused but may be needed for other formats
      int compression = 1; // 1 = no compression
      
      // Parse IFD entries
      for (int i = 0; i < numEntries; i++) {
        final entryOffset = ifdOffset + 2 + (i * 12);
        if (entryOffset + 12 > data.length) break;
        
        final tag = byteData.getUint16(entryOffset, endian);
        final type = byteData.getUint16(entryOffset + 2, endian);
        final count = byteData.getUint32(entryOffset + 4, endian);
        final valueOffset = entryOffset + 8;
        
        // Debug specific important tags
        if (tag == 273 || tag == 279 || tag == 322 || tag == 323 || tag == 324 || tag == 325) {
          final tagName = {
            273: 'StripOffsets',
            279: 'StripByteCounts',
            322: 'TileWidth',
            323: 'TileLength',
            324: 'TileOffsets',
            325: 'TileByteCounts',
          }[tag];
          debugPrint('SrtmFile: Tag $tag ($tagName): type=$type, count=$count');
        }
        
        switch (tag) {
          case 256: // ImageWidth
            imageWidth = type == 3 
                ? byteData.getUint16(valueOffset, endian)
                : byteData.getUint32(valueOffset, endian);
            break;
          case 257: // ImageLength (height)
            imageHeight = type == 3
                ? byteData.getUint16(valueOffset, endian)
                : byteData.getUint32(valueOffset, endian);
            break;
          case 258: // BitsPerSample
            // bitsPerSample = byteData.getUint16(valueOffset, endian);
            break;
          case 259: // Compression
            compression = byteData.getUint16(valueOffset, endian);
            break;
          case 273: // StripOffsets
            if (count == 1) {
              // For single strip, value fits in the offset field
              if (type == 3) { // SHORT
                stripOffset = byteData.getUint16(valueOffset, endian);
              } else { // LONG
                stripOffset = byteData.getUint32(valueOffset, endian);
              }
              stripOffsets = [stripOffset];
            } else {
              // Multiple strips - read offset array
              final arrayOffset = byteData.getUint32(valueOffset, endian);
              for (int j = 0; j < count; j++) {
                if (arrayOffset + j * 4 <= data.length - 4) {
                  if (type == 3) { // SHORT
                    stripOffsets.add(byteData.getUint16(arrayOffset + j * 2, endian));
                  } else { // LONG
                    stripOffsets.add(byteData.getUint32(arrayOffset + j * 4, endian));
                  }
                }
              }
              if (stripOffsets.isNotEmpty) {
                stripOffset = stripOffsets.first;
              }
            }
            break;
          case 278: // RowsPerStrip
            rowsPerStrip = type == 3
                ? byteData.getUint16(valueOffset, endian)
                : byteData.getUint32(valueOffset, endian);
            break;
          case 279: // StripByteCounts
            if (count == 1) {
              // For single strip, value fits in the offset field
              if (type == 3) { // SHORT
                stripByteCount = byteData.getUint16(valueOffset, endian);
              } else { // LONG
                stripByteCount = byteData.getUint32(valueOffset, endian);
              }
              stripByteCounts = [stripByteCount];
            } else {
              // Multiple strips - read byte count array
              final arrayOffset = byteData.getUint32(valueOffset, endian);
              for (int j = 0; j < count; j++) {
                if (arrayOffset + j * 4 <= data.length - 4) {
                  if (type == 3) { // SHORT
                    stripByteCounts.add(byteData.getUint16(arrayOffset + j * 2, endian));
                  } else { // LONG
                    stripByteCounts.add(byteData.getUint32(arrayOffset + j * 4, endian));
                  }
                }
              }
              if (stripByteCounts.isNotEmpty) {
                stripByteCount = stripByteCounts.reduce((a, b) => a + b);
              }
            }
            break;
          case 322: // TileWidth
            tileWidth = type == 3
                ? byteData.getUint16(valueOffset, endian)
                : byteData.getUint32(valueOffset, endian);
            break;
          case 323: // TileLength
            tileLength = type == 3
                ? byteData.getUint16(valueOffset, endian)
                : byteData.getUint32(valueOffset, endian);
            break;
          case 324: // TileOffsets
            if (count == 1) {
              tileOffset = byteData.getUint32(valueOffset, endian);
              tileOffsets = [tileOffset];
            } else {
              // Multiple tiles - read offset array
              final arrayOffset = byteData.getUint32(valueOffset, endian);
              for (int j = 0; j < count; j++) {
                if (arrayOffset + j * 4 <= data.length - 4) {
                  tileOffsets.add(byteData.getUint32(arrayOffset + j * 4, endian));
                }
              }
              if (tileOffsets.isNotEmpty) {
                tileOffset = tileOffsets.first;
              }
            }
            break;
          case 325: // TileByteCounts
            if (count == 1) {
              tileByteCounts = [byteData.getUint32(valueOffset, endian)];
            } else {
              // Multiple tiles - read byte count array
              final arrayOffset = byteData.getUint32(valueOffset, endian);
              for (int j = 0; j < count; j++) {
                if (arrayOffset + j * 4 <= data.length - 4) {
                  tileByteCounts.add(byteData.getUint32(arrayOffset + j * 4, endian));
                }
              }
            }
            break;
        }
      }
      
      // Use appropriate offset (strip or tile)
      final dataOffset = stripOffset > 0 ? stripOffset : (tileOffset > 0 ? tileOffset : 8);
      
      // Validate dimensions
      if (imageWidth != 3601 || imageHeight != 3601) {
        debugPrint('SrtmFile: Unexpected dimensions: ${imageWidth}x$imageHeight (expected 3601x3601)');
        // Continue anyway as some SRTM files might have slightly different dimensions
      }
      
      const expectedSize = 3601;
      final totalPixels = expectedSize * expectedSize;
      
      // Debug output for TIFF structure
      debugPrint('SrtmFile: TIFF structure - width=$imageWidth, height=$imageHeight, compression=$compression');
      
      // Check if this is a tiled TIFF
      final bool isTiled = tileOffsets.isNotEmpty;
      if (isTiled) {
        debugPrint('SrtmFile: Tiled TIFF - tileWidth=$tileWidth, tileLength=$tileLength, tiles=${tileOffsets.length}');
        if (tileOffsets.isNotEmpty) {
          debugPrint('SrtmFile: First tile at offset ${tileOffsets.first}, size ${tileByteCounts.isNotEmpty ? tileByteCounts.first : "unknown"}');
        }
      } else {
        debugPrint('SrtmFile: Strips - count=${stripOffsets.length}, offset=$stripOffset, byteCount=$stripByteCount');
        if (stripOffsets.isNotEmpty) {
          debugPrint('SrtmFile: First strip at offset ${stripOffsets.first}, size ${stripByteCounts.isNotEmpty ? stripByteCounts.first : "unknown"}');
        }
      }
      
      // Check if data is compressed
      if (compression == 8) {
        // Compression type 8 is Deflate/ZIP compression
        debugPrint('SrtmFile: TIFF uses Deflate compression (type 8), ${isTiled ? tileOffsets.length : stripOffsets.length} ${isTiled ? "tiles" : "strips"}');
        
        try {
          final elevationData = Uint16List(totalPixels);
          int pixelIndex = 0;
          
          // Handle tiled TIFF
          if (isTiled && tileOffsets.isNotEmpty && tileByteCounts.length == tileOffsets.length) {
            debugPrint('SrtmFile: Processing ${tileOffsets.length} compressed tiles');
            
            // Calculate tiles per row
            final tilesPerRow = (imageWidth + tileWidth - 1) ~/ tileWidth;
            
            // Process each tile
            for (int tileIdx = 0; tileIdx < tileOffsets.length && tileIdx < tileByteCounts.length; tileIdx++) {
              final offset = tileOffsets[tileIdx];
              final byteCount = tileByteCounts[tileIdx];
              
              if (offset == 0 || byteCount == 0) continue;
              if (offset + byteCount > data.length) {
                debugPrint('SrtmFile: Tile $tileIdx exceeds file bounds');
                continue;
              }
              
              final compressedTile = data.sublist(offset, offset + byteCount);
              
              try {
                // Decompress tile
                List<int> decompressed;
                try {
                  decompressed = zlib.decode(compressedTile);
                } catch (e) {
                  // Try without zlib header
                  if (compressedTile.length > 2 && compressedTile[0] == 0x78) {
                    decompressed = zlib.decode(compressedTile.sublist(2));
                  } else {
                    rethrow;
                  }
                }
                
                // Calculate tile position in the image
                final tileRow = tileIdx ~/ tilesPerRow;
                final tileCol = tileIdx % tilesPerRow;
                final tileStartY = tileRow * tileLength;
                final tileStartX = tileCol * tileWidth;
                
                // Copy decompressed data to elevation array
                final decompressedBytes = Uint8List.fromList(decompressed);
                final tileByteData = ByteData.sublistView(decompressedBytes);
                
                int tilePixelIdx = 0;
                for (int y = 0; y < tileLength && tileStartY + y < imageHeight; y++) {
                  for (int x = 0; x < tileWidth && tileStartX + x < imageWidth; x++) {
                    final globalX = tileStartX + x;
                    final globalY = tileStartY + y;
                    final globalIdx = globalY * imageWidth + globalX;
                    
                    if (globalIdx < totalPixels && tilePixelIdx * 2 + 1 < decompressedBytes.length) {
                      elevationData[globalIdx] = tileByteData.getUint16(tilePixelIdx * 2, endian);
                      tilePixelIdx++;
                    }
                  }
                }
              } catch (e) {
                debugPrint('SrtmFile: Failed to decompress tile $tileIdx: $e');
              }
            }
            
            pixelIndex = totalPixels; // All pixels processed
          }
          // Handle multiple strips if present
          else if (stripOffsets.length > 1 && stripByteCounts.length == stripOffsets.length) {
            debugPrint('SrtmFile: Processing ${stripOffsets.length} compressed strips');
            
            // Process each strip
            for (int stripIdx = 0; stripIdx < stripOffsets.length; stripIdx++) {
              final offset = stripOffsets[stripIdx];
              final byteCount = stripByteCounts[stripIdx];
              
              if (offset + byteCount > data.length) {
                debugPrint('SrtmFile: Strip $stripIdx exceeds file bounds, using available data');
              }
              
              final compressedStrip = data.sublist(offset, 
                  (offset + byteCount).clamp(offset, data.length));
              
              try {
                // Decompress this strip
                List<int> decompressed;
                try {
                  decompressed = zlib.decode(compressedStrip);
                } catch (e) {
                  // Try without zlib header
                  if (compressedStrip.length > 2 && compressedStrip[0] == 0x78) {
                    decompressed = zlib.decode(compressedStrip.sublist(2));
                  } else {
                    rethrow;
                  }
                }
                
                // Copy decompressed data to elevation array
                final decompressedBytes = Uint8List.fromList(decompressed);
                final stripByteData = ByteData.sublistView(decompressedBytes);
                final pixelsInStrip = decompressedBytes.length ~/ 2;
                
                for (int i = 0; i < pixelsInStrip && pixelIndex < totalPixels; i++) {
                  elevationData[pixelIndex++] = stripByteData.getUint16(i * 2, endian);
                }
              } catch (e) {
                debugPrint('SrtmFile: Failed to decompress strip $stripIdx: $e');
                // Fill this strip with NODATA
                final pixelsInStrip = rowsPerStrip > 0 ? rowsPerStrip * imageWidth : 0;
                for (int i = 0; i < pixelsInStrip && pixelIndex < totalPixels; i++) {
                  elevationData[pixelIndex++] = 32768;
                }
              }
            }
          } else {
            // Single strip or use first strip
            Uint8List compressedData;
            
            if (stripByteCount > 0 && dataOffset + stripByteCount <= data.length) {
              compressedData = data.sublist(dataOffset, dataOffset + stripByteCount);
            } else {
              compressedData = data.sublist(dataOffset);
            }
            
            debugPrint('SrtmFile: Attempting to decompress ${compressedData.length} bytes from offset $dataOffset');
            
            // Try decompression with error recovery
            List<int> decompressed;
            try {
              decompressed = zlib.decode(compressedData);
            } catch (e) {
              debugPrint('SrtmFile: Standard zlib failed, trying raw deflate');
              try {
                if (compressedData.length > 2 && compressedData[0] == 0x78) {
                  compressedData = compressedData.sublist(2);
                }
                decompressed = zlib.decode(compressedData);
              } catch (e2) {
                debugPrint('SrtmFile: All decompression attempts failed: $e2');
                debugPrint('SrtmFile: Cannot parse compressed TIFF file $filename');
                return null;
              }
            }
            
            final decompressedBytes = Uint8List.fromList(decompressed);
            debugPrint('SrtmFile: Decompressed ${compressedData.length} bytes to ${decompressedBytes.length} bytes');
            
            final decompressedByteData = ByteData.sublistView(decompressedBytes);
            final pixelsAvailable = decompressedBytes.length ~/ 2;
            final pixelsToRead = pixelsAvailable < totalPixels ? pixelsAvailable : totalPixels;
            
            for (int i = 0; i < pixelsToRead; i++) {
              elevationData[i] = decompressedByteData.getUint16(i * 2, endian);
            }
            
            pixelIndex = pixelsToRead;
          }
          
          // Fill remaining pixels if needed
          if (pixelIndex < totalPixels) {
            debugPrint('SrtmFile: Read $pixelIndex/$totalPixels pixels, filling remaining');
            for (int i = pixelIndex; i < totalPixels; i++) {
              elevationData[i] = 32768; // SRTM NODATA value
            }
          }
          
          debugPrint('SrtmFile: Successfully parsed compressed TIFF $filename');
          
          return SrtmFile(
            filename: filename,
            size: expectedSize,
            elevationData: elevationData,
          );
        } catch (e) {
          debugPrint('SrtmFile: Failed to decompress TIFF data: $e');
          return null;
        }
      } else if (compression == 5) {
        // Compression type 5 is LZW compression
        debugPrint('SrtmFile: LZW compression (type 5) not supported, file cannot be parsed');
        return null;
      } else if (compression != 1) {
        debugPrint('SrtmFile: Unsupported compression type: $compression');
        // Try to parse anyway as raw data
      }
      
      debugPrint('SrtmFile: TIFF IFD - width=$imageWidth, height=$imageHeight, dataOffset=$dataOffset, compression=$compression');
      
      // Extract elevation data (uncompressed path)
      final elevationData = Uint16List(totalPixels);
      
      // Calculate how much data we can read
      final availableBytes = data.length - dataOffset;
      final maxPixels = availableBytes ~/ 2; // 2 bytes per pixel
      final pixelsToRead = maxPixels < totalPixels ? maxPixels : totalPixels;
      
      // Read the elevation data
      for (int i = 0; i < pixelsToRead; i++) {
        final offset = dataOffset + (i * 2);
        if (offset + 1 < data.length) {
          elevationData[i] = byteData.getUint16(offset, endian);
        }
      }
      
      // Fill remaining pixels if needed
      if (pixelsToRead < totalPixels) {
        debugPrint('SrtmFile: Read $pixelsToRead/$totalPixels pixels, filling remaining');
        // Fill with NODATA value (32768 or 0x8000)
        for (int i = pixelsToRead; i < totalPixels; i++) {
          elevationData[i] = 32768; // SRTM NODATA value
        }
      }
      
      debugPrint('SrtmFile: Successfully parsed TIFF $filename (${imageWidth}x$imageHeight, read $pixelsToRead pixels)');
      
      return SrtmFile(
        filename: filename,
        size: expectedSize,
        elevationData: elevationData,
      );
    } catch (e) {
      debugPrint('SrtmFile: Error parsing TIFF file: $e');
      return null;
    }
  }
  
  /// Get elevation at specific coordinates
  double? getElevation(double latitude, double longitude) {
    try {
      // Extract integer coordinates for tile
      final tileLatFloor = latitude.floor();
      final tileLonFloor = longitude.floor();
      
      // Calculate position within tile (0.0 to 1.0)
      final latFraction = latitude - tileLatFloor;
      final lonFraction = longitude - tileLonFloor;
      
      // Convert to pixel coordinates
      final row = ((1.0 - latFraction) * (size - 1)).round();
      final col = (lonFraction * (size - 1)).round();
      
      final index = row * size + col;
      
      if (index >= 0 && index < elevationData.length) {
        final rawValue = elevationData[index];
        
        // Handle NoData values (SRTM uses -32768 when interpreted as signed)
        // In unsigned 16-bit, -32768 appears as 32768
        if (rawValue == 32768 || rawValue == 65535) {
          return null; // NoData (void value)
        }
        
        // Convert to signed elevation (16-bit signed: values > 32767 are negative)
        final elevation = rawValue > 32767 
            ? rawValue - 65536 
            : rawValue;
            
        // Additional check for invalid elevations
        if (elevation < -1000 || elevation > 9000) {
          // Unrealistic elevation for Earth, likely corrupt data
          return null;
        }
            
        return elevation.toDouble();
      }
      
      return null;
    } catch (e) {
      debugPrint('SrtmFile: Error getting elevation: $e');
      return null;
    }
  }
  
  /// Get file information
  Map<String, dynamic> getInfo() {
    return {
      'filename': filename,
      'size': size,
      'data_points': elevationData.length,
      'memory_size': elevationData.lengthInBytes,
    };
  }
}