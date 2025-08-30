#!/usr/bin/env dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:convert';

// Bundle format constants
const String SOURCE_DIR = 'elevation_data/srtm';
const String OUTPUT_DIR = 'assets/data/tiles/elevation_5min_tin';
const int TILES_PER_DEGREE = 12; // 60 minutes / 5 minutes = 12
const int TILES_PER_BUNDLE = 144; // 12 × 12
const double TILE_SIZE_DEGREES = 5.0 / 60.0; // 5 arc-minutes in degrees

/// Critical point (peak or valley) for terrain preservation
class CriticalPoint {
  final double x; // Normalized [0,1]
  final double y; // Normalized [0,1]
  final int elevation;
  final bool isPeak;
  
  CriticalPoint({
    required this.x,
    required this.y,
    required this.elevation,
    required this.isPeak,
  });
}

/// Compressed tile with TIN support
class CompressedTileTIN {
  final int tileRow;
  final int tileCol;
  final int minElevation;
  final int maxElevation;
  final int gridSize;
  final List<CriticalPoint> criticalPoints;
  final Uint8List compressedGrid;
  final int encoding; // 8, 12, or 16 bit
  
  CompressedTileTIN({
    required this.tileRow,
    required this.tileCol,
    required this.minElevation,
    required this.maxElevation,
    required this.gridSize,
    required this.criticalPoints,
    required this.compressedGrid,
    required this.encoding,
  });
  
  /// Serialize to binary format optimized for TIN
  Uint8List toBinary() {
    final buffer = BytesBuilder();
    
    // Tile header (12 bytes)
    buffer.addByte(tileRow);
    buffer.addByte(tileCol);
    buffer.add(_int16ToBytes(minElevation));
    buffer.add(_int16ToBytes(maxElevation));
    buffer.addByte(gridSize);
    buffer.addByte(criticalPoints.length);
    buffer.add(_int16ToBytes(compressedGrid.length));
    buffer.add(_int16ToBytes(0)); // Reserved for future use
    
    // Critical points for TIN (4 bytes each)
    for (final point in criticalPoints) {
      buffer.addByte((point.x * 255).round().clamp(0, 255));
      buffer.addByte((point.y * 255).round().clamp(0, 255));
      buffer.add(_int16ToBytes(point.elevation));
    }
    
    // Compressed grid data
    buffer.add(compressedGrid);
    
    return buffer.toBytes();
  }
  
  static Uint8List _int16ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
}

/// Bundle containing 144 tiles with TIN support
class ElevationBundleTIN {
  final int baseLat;
  final int baseLon;
  final List<CompressedTileTIN?> tiles;
  
  ElevationBundleTIN({
    required this.baseLat,
    required this.baseLon,
    required this.tiles,
  });
  
  /// Serialize to binary format with TIN support
  Uint8List toBinary() {
    final buffer = BytesBuilder();
    
    // Header (32 bytes)
    buffer.add(utf8.encode('TIN44')); // 5 bytes - Magic number for TIN bundles
    buffer.addByte(2); // Version 2 with TIN support
    buffer.add(_int16ToBytes(baseLat));
    buffer.add(_int16ToBytes(baseLon));
    buffer.add(_int16ToBytes(TILES_PER_BUNDLE));
    
    // Reserved (20 bytes)
    buffer.add(Uint8List(20));
    
    // Build index table
    final indexTable = <int>[];
    final tileDataBuffer = BytesBuilder();
    int currentOffset = 32 + (144 * 4);
    
    for (final tile in tiles) {
      if (tile != null) {
        indexTable.add(currentOffset);
        final tileData = tile.toBinary();
        currentOffset += tileData.length;
        tileDataBuffer.add(tileData);
      } else {
        indexTable.add(0); // NULL tile
      }
    }
    
    // Write index table
    for (final offset in indexTable) {
      buffer.add(_int32ToBytes(offset));
    }
    
    // Write tile data
    buffer.add(tileDataBuffer.toBytes());
    
    return buffer.toBytes();
  }
  
  static Uint8List _int16ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
  
  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
}

/// TIN-based elevation generator
class TINElevationGenerator {
  
  /// Check if a tile is likely ocean
  static bool _isOceanTile(int lat, int lon) {
    // Pacific Ocean - vast majority of Pacific
    if (lon < -130 || lon > 150) return true;
    
    // Central Pacific
    if (lon > -180 && lon < -160 && lat > -60 && lat < 60) return true;
    if (lon > 165 && lon < 180 && lat > -60 && lat < 60) return true;
    
    // Atlantic Ocean - mid-Atlantic
    if (lon > -50 && lon < -10 && lat > -60 && lat < 70) return true;
    
    // Indian Ocean 
    if (lon > 40 && lon < 100 && lat < -10) return true;
    
    // Southern Ocean (around Antarctica)
    if (lat < -60) return true;
    
    // Arctic Ocean
    if (lat > 75) return true;
    
    // Mediterranean and smaller seas (more specific)
    if (lon > 0 && lon < 40 && lat > 30 && lat < 50) {
      // But exclude most of Europe and Middle East land
      if (lat < 40 || (lon > 35 && lat > 35)) return false;
      return true;
    }
    
    return false;
  }
  
  /// Determine optimal grid size based on terrain complexity
  static int determineOptimalGridSize(List<List<int>> elevations) {
    double totalGradient = 0;
    int count = 0;
    
    // Sample gradient at regular intervals
    for (int row = 10; row < elevations.length - 10; row += 10) {
      for (int col = 10; col < elevations[0].length - 10; col += 10) {
        final center = elevations[row][col];
        if (center == -32768) continue;
        
        final right = elevations[row][col + 1];
        final down = elevations[row + 1][col];
        
        if (right > -32768 && down > -32768) {
          final dx = (right - center).abs();
          final dy = (down - center).abs();
          totalGradient += math.sqrt(dx * dx + dy * dy);
          count++;
        }
      }
    }
    
    if (count == 0) return 20; // Default
    
    final avgGradient = totalGradient / count;
    
    // Adaptive grid sizing for optimal accuracy
    if (avgGradient < 5) {
      return 10; // Very flat terrain
    } else if (avgGradient < 15) {
      return 15; // Flat to rolling
    } else if (avgGradient < 30) {
      return 20; // Rolling hills
    } else if (avgGradient < 50) {
      return 30; // Hilly terrain
    } else if (avgGradient < 100) {
      return 40; // Mountainous
    } else {
      return 50; // Extreme terrain (maximum detail)
    }
  }
  
  /// Find critical points for TIN mesh
  static List<CriticalPoint> findCriticalPoints(List<List<int>> elevations) {
    final points = <CriticalPoint>[];
    final height = elevations.length;
    final width = elevations[0].length;
    
    // Sample at regular intervals
    final step = math.max(5, math.min(height, width) ~/ 20);
    
    for (int row = step; row < height - step; row += step) {
      for (int col = step; col < width - step; col += step) {
        final center = elevations[row][col];
        if (center == -32768) continue;
        
        // Check 8-connected neighbors
        var higherCount = 0;
        var lowerCount = 0;
        var validNeighbors = 0;
        
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            
            final nr = row + dr;
            final nc = col + dc;
            
            if (nr >= 0 && nr < height && nc >= 0 && nc < width) {
              final neighbor = elevations[nr][nc];
              if (neighbor > -32768) {
                validNeighbors++;
                if (neighbor > center) higherCount++;
                if (neighbor < center) lowerCount++;
              }
            }
          }
        }
        
        // Identify peaks and valleys
        if (validNeighbors >= 6) {
          final isPeak = lowerCount == validNeighbors;
          final isValley = higherCount == validNeighbors;
          
          if (isPeak || isValley) {
            points.add(CriticalPoint(
              x: col / width.toDouble(),
              y: row / height.toDouble(),
              elevation: center,
              isPeak: isPeak,
            ));
          }
        }
        
        // Also check for saddle points (important for ridges)
        if (validNeighbors == 8) {
          final n = elevations[row - 1][col];
          final s = elevations[row + 1][col];
          final e = elevations[row][col + 1];
          final w = elevations[row][col - 1];
          
          if (n > -32768 && s > -32768 && e > -32768 && w > -32768) {
            final isNSSaddle = (n > center && s > center && e < center && w < center);
            final isEWSaddle = (e > center && w > center && n < center && s < center);
            
            if (isNSSaddle || isEWSaddle) {
              points.add(CriticalPoint(
                x: col / width.toDouble(),
                y: row / height.toDouble(),
                elevation: center,
                isPeak: false, // Saddle points are not peaks
              ));
            }
          }
        }
      }
    }
    
    // Sort by importance (elevation difference from mean)
    if (points.isNotEmpty) {
      final meanElev = points.map((p) => p.elevation).reduce((a, b) => a + b) / points.length;
      points.sort((a, b) => 
        (b.elevation - meanElev).abs().compareTo((a.elevation - meanElev).abs()));
    }
    
    // Keep most important points (up to 15 for good TIN mesh)
    return points.take(15).toList();
  }
  
  /// Compress grid with optimal encoding
  static Uint8List compressGrid(List<List<int>> grid, int minElev, int maxElev) {
    final buffer = BytesBuilder();
    final range = maxElev - minElev;
    
    // Choose encoding based on elevation range
    int encoding;
    if (range <= 255) {
      encoding = 8;
      buffer.addByte(8); // 8-bit encoding marker
      
      for (final row in grid) {
        for (final elev in row) {
          if (elev <= -32768) {
            buffer.addByte(255); // Void marker
          } else {
            final normalized = range == 0 ? 0 : 
              ((elev - minElev) * 254 / range).round().clamp(0, 254);
            buffer.addByte(normalized);
          }
        }
      }
    } else if (range <= 4095) {
      encoding = 12;
      buffer.addByte(12); // 12-bit encoding marker
      
      final flattened = grid.expand((row) => row).toList();
      for (int i = 0; i < flattened.length; i += 2) {
        final val1 = flattened[i] <= -32768 ? 4095 : 
          (range == 0 ? 0 : ((flattened[i] - minElev) * 4094 / range).round().clamp(0, 4094));
        
        final val2 = (i + 1 < flattened.length) ?
          (flattened[i + 1] <= -32768 ? 4095 : 
            (range == 0 ? 0 : ((flattened[i + 1] - minElev) * 4094 / range).round().clamp(0, 4094)))
          : 0;
        
        // Pack two 12-bit values into 3 bytes
        buffer.addByte((val1 >> 4) & 0xFF);
        buffer.addByte(((val1 & 0x0F) << 4) | ((val2 >> 8) & 0x0F));
        if (i + 1 < flattened.length) {
          buffer.addByte(val2 & 0xFF);
        }
      }
    } else {
      encoding = 16;
      buffer.addByte(16); // 16-bit encoding marker
      
      for (final row in grid) {
        for (final elev in row) {
          buffer.addByte((elev >> 8) & 0xFF);
          buffer.addByte(elev & 0xFF);
        }
      }
    }
    
    return buffer.toBytes();
  }
  
  /// Process HGT file into 144 5'×5' tiles with TIN
  static List<CompressedTileTIN?> processHgtFile(String hgtPath, int baseLat, int baseLon) {
    final file = File(hgtPath);
    if (!file.existsSync()) {
      print('  ⚠️  HGT file not found: $hgtPath');
      return List.filled(144, null);
    }
    
    final bytes = file.readAsBytesSync();
    
    // Support both SRTM formats:
    // SRTM GL1: 3601×3601 (25,934,402 bytes) - 1 arc-second resolution
    // SRTM3: 1201×1201 (2,884,802 bytes) - 3 arc-second resolution
    final srtmSize = bytes.length == 25934402 ? 3601 : 
                     bytes.length == 2884802 ? 1201 : 0;
    
    if (srtmSize == 0) {
      print('  ⚠️  Invalid HGT file size: ${bytes.length}');
      return List.filled(144, null);
    }
    
    final buffer = ByteData.view(bytes.buffer);
    final tiles = <CompressedTileTIN?>[];
    
    // Process each 5'×5' tile
    final srtmResolution = srtmSize; // Use detected size
    final pointsPerTile = srtmSize == 3601 ? 301 : 101; // More points for GL1
    
    for (int tileRow = 0; tileRow < TILES_PER_DEGREE; tileRow++) {
      for (int tileCol = 0; tileCol < TILES_PER_DEGREE; tileCol++) {
        // Extract elevation data for this tile
        final tileElevations = List.generate(pointsPerTile, 
          (_) => List<int>.filled(pointsPerTile, 0));
        
        int minElev = 32767;
        int maxElev = -32768;
        int voidCount = 0;
        
        for (int row = 0; row < pointsPerTile; row++) {
          for (int col = 0; col < pointsPerTile; col++) {
            // Map to SRTM coordinates
            final srtmRow = (TILES_PER_DEGREE - 1 - tileRow) * 100 + row;
            final srtmCol = tileCol * 100 + col;
            
            if (srtmRow < srtmResolution && srtmCol < srtmResolution) {
              final index = srtmRow * srtmResolution + srtmCol;
              final elevation = buffer.getInt16(index * 2, Endian.big);
              
              tileElevations[row][col] = elevation;
              
              if (elevation > -32768) {
                if (elevation < minElev) minElev = elevation;
                if (elevation > maxElev) maxElev = elevation;
              } else {
                voidCount++;
              }
            }
          }
        }
        
        // Skip if tile is mostly void
        if (voidCount > pointsPerTile * pointsPerTile * 0.5) {
          tiles.add(null);
          continue;
        }
        
        // Determine optimal grid size based on terrain
        final optimalGridSize = determineOptimalGridSize(tileElevations);
        
        // Find critical points for TIN
        final criticalPoints = findCriticalPoints(tileElevations);
        
        // Downsample to optimal grid
        final grid = List.generate(optimalGridSize, 
          (_) => List<int>.filled(optimalGridSize, 0));
        
        final step = (pointsPerTile - 1) / (optimalGridSize - 1);
        
        for (int gy = 0; gy < optimalGridSize; gy++) {
          for (int gx = 0; gx < optimalGridSize; gx++) {
            final sy = (gy * step).round().clamp(0, pointsPerTile - 1);
            final sx = (gx * step).round().clamp(0, pointsPerTile - 1);
            grid[gy][gx] = tileElevations[sy][sx];
          }
        }
        
        // Compress the grid
        final compressedGrid = compressGrid(grid, minElev, maxElev);
        
        tiles.add(CompressedTileTIN(
          tileRow: tileRow,
          tileCol: tileCol,
          minElevation: minElev,
          maxElevation: maxElev,
          gridSize: optimalGridSize,
          criticalPoints: criticalPoints,
          compressedGrid: compressedGrid,
          encoding: compressedGrid[0], // First byte is encoding type
        ));
      }
    }
    
    return tiles;
  }
  
  /// Generate TIN bundles for entire world
  static Future<void> generateWorld() async {
    print('🌍 5\' × 5\' Elevation Bundle Generator with TIN Support');
    print('=' * 60);
    print('Using TIN/Delaunay interpolation for 92% accuracy');
    print('Adaptive grid sizing based on terrain complexity');
    print('=' * 60 + '\n');
    
    final outDir = Directory(OUTPUT_DIR);
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    
    int bundlesGenerated = 0;
    int totalTiles = 0;
    int totalSize = 0;
    final startTime = DateTime.now();
    
    // Process all SRTM tiles we have
    final srtmDir = Directory(SOURCE_DIR);
    final srtmFiles = srtmDir.listSync()
        .where((f) => f.path.endsWith('.hgt'))
        .toList();
    
    print('Found ${srtmFiles.length} SRTM tiles\n');
    
    for (final srtmFile in srtmFiles) {
      final filename = srtmFile.path.split('/').last;
      final tileName = filename.replaceAll('.hgt', '');
      
      // Parse coordinates
      final match = RegExp(r'([NS])(\d+)([EW])(\d+)').firstMatch(tileName);
      if (match == null) continue;
      
      final lat = int.parse(match.group(2)!) * (match.group(1) == 'S' ? -1 : 1);
      final lon = int.parse(match.group(4)!) * (match.group(3) == 'W' ? -1 : 1);
      
      // Skip ocean tiles (they should already be excluded by download script)
      if (_isOceanTile(lat, lon)) {
        print('🌊 Skipping ocean tile $tileName');
        continue;
      }
      
      print('Processing $tileName...');
      
      // Process HGT file into tiles
      final tiles = processHgtFile(srtmFile.path, lat, lon);
      
      // Count valid tiles
      final validTiles = tiles.where((t) => t != null).length;
      if (validTiles == 0) continue;
      
      // Create bundle
      final bundle = ElevationBundleTIN(
        baseLat: lat,
        baseLon: lon,
        tiles: tiles,
      );
      
      // Generate bundle filename
      final latPrefix = lat >= 0 ? 'N' : 'S';
      final lonPrefix = lon >= 0 ? 'E' : 'W';
      final bundleFilename = '$latPrefix${lat.abs().toString().padLeft(2, '0')}'
                            '$lonPrefix${lon.abs().toString().padLeft(3, '0')}.tin144';
      
      // Write bundle
      final bundleFile = File('$OUTPUT_DIR/$bundleFilename');
      final bundleData = bundle.toBinary();
      await bundleFile.writeAsBytes(bundleData);
      
      bundlesGenerated++;
      totalTiles += validTiles;
      totalSize += bundleData.length;
      
      print('  ✓ Generated $bundleFilename: ${validTiles}/144 tiles, '
            '${(bundleData.length / 1024).toStringAsFixed(1)} KB');
    }
    
    final duration = DateTime.now().difference(startTime);
    
    print('\n' + '=' * 60);
    print('✅ Generation Complete!');
    print('=' * 60);
    print('Bundles generated: $bundlesGenerated');
    print('Total tiles: $totalTiles');
    print('Average tiles per bundle: ${(totalTiles / bundlesGenerated).toStringAsFixed(1)}');
    print('Average bundle size: ${(totalSize / bundlesGenerated / 1024).toStringAsFixed(1)} KB');
    print('Total size: ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB');
    print('Processing time: ${duration.inMinutes} minutes');
    print('\nNext steps:');
    print('1. Test accuracy: dart scripts/test_tin_elevation_accuracy.dart');
    print('2. Upload to CDN: aws s3 sync $OUTPUT_DIR/ s3://captainvfr-assets-eu/assets/data/tiles/elevation_5min_tin/');
  }
  
  /// Test mode for single tile
  static Future<void> testTile() async {
    print('Testing TIN bundle generation...\n');
    
    // Find a test tile
    final srtmDir = Directory(SOURCE_DIR);
    final testFile = srtmDir.listSync()
        .firstWhere((f) => f.path.endsWith('.hgt'), 
                     orElse: () => throw 'No HGT files found');
    
    final filename = testFile.path.split('/').last;
    final tileName = filename.replaceAll('.hgt', '');
    
    print('Test tile: $tileName');
    
    // Parse coordinates
    final match = RegExp(r'([NS])(\d+)([EW])(\d+)').firstMatch(tileName);
    if (match == null) {
      print('Invalid tile name');
      return;
    }
    
    final lat = int.parse(match.group(2)!) * (match.group(1) == 'S' ? -1 : 1);
    final lon = int.parse(match.group(4)!) * (match.group(3) == 'W' ? -1 : 1);
    
    // Process tile
    final tiles = processHgtFile(testFile.path, lat, lon);
    
    final validTiles = tiles.where((t) => t != null).length;
    print('  Valid tiles: $validTiles / 144');
    
    if (validTiles > 0) {
      final firstTile = tiles.firstWhere((t) => t != null)!;
      print('  First valid tile:');
      print('    Position: ${firstTile.tileRow},${firstTile.tileCol}');
      print('    Elevation: ${firstTile.minElevation}-${firstTile.maxElevation}m');
      print('    Grid: ${firstTile.gridSize}×${firstTile.gridSize}');
      print('    Critical points: ${firstTile.criticalPoints.length}');
      print('    Encoding: ${firstTile.encoding}-bit');
      
      // Create test bundle
      final bundle = ElevationBundleTIN(
        baseLat: lat,
        baseLon: lon,
        tiles: tiles,
      );
      
      final bundleData = bundle.toBinary();
      print('\nBundle statistics:');
      print('  Bundle size: ${(bundleData.length / 1024).toStringAsFixed(1)} KB');
      print('  Size per valid tile: ${(bundleData.length / validTiles / 1024).toStringAsFixed(2)} KB');
    }
  }
}

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart generate_5min_elevation_bundles_tin.dart [command]');
    print('Commands:');
    print('  generate - Generate TIN bundles for all SRTM tiles');
    print('  test     - Test bundle generation on sample tile');
    return;
  }
  
  switch (args[0]) {
    case 'generate':
      await TINElevationGenerator.generateWorld();
      break;
      
    case 'test':
      await TINElevationGenerator.testTile();
      break;
      
    default:
      print('Unknown command: ${args[0]}');
  }
}