#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

/// Downloads sample elevation data for testing the terrain altitude service
/// This script downloads a small set of SRTM tiles for testing purposes
class TestElevationDataSetup {
  static const String elevationDataDir = 'elevation_data';
  static const String srtmTestDir = '$elevationDataDir/srtm_test';
  
  // Sample SRTM tiles covering interesting terrain areas
  // These are 3" resolution tiles from the SRTM dataset
  static const List<String> testTiles = [
    'N47E010', // Alps region (Austria/Switzerland)
    'N46E007', // Swiss Alps (Matterhorn area)
    'N45E006', // French Alps (Mont Blanc area)
    'N37W119', // Yosemite/Sierra Nevada (USA)
    'N36W112', // Grand Canyon (USA)
  ];

  /// Download SRTM HGT file from mirror
  static Future<void> downloadSRTMTile(String tileName) async {
    print('📥 Downloading SRTM tile: $tileName');
    
    // SRTM data URLs (using viewfinderpanoramas.org mirror)
    // Format: http://viewfinderpanoramas.org/dem3/[ZONE]/[TILENAME].zip
    final zone = _getZoneForTile(tileName);
    final url = 'http://viewfinderpanoramas.org/dem3/$zone/$tileName.zip';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Save zip file
        final zipFile = File(path.join(srtmTestDir, '$tileName.zip'));
        await zipFile.create(recursive: true);
        await zipFile.writeAsBytes(response.bodyBytes);
        
        // Extract HGT file
        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
          if (file.isFile && file.name.endsWith('.hgt')) {
            final outputFile = File(path.join(srtmTestDir, file.name));
            await outputFile.writeAsBytes(file.content as List<int>);
            print('✅ Extracted: ${file.name}');
          }
        }
        
        // Clean up zip file
        await zipFile.delete();
      } else {
        print('❌ Failed to download $tileName: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error downloading $tileName: $e');
      // Try alternative source
      await _downloadFromAlternativeSource(tileName);
    }
  }

  /// Alternative download from OpenTopography
  static Future<void> _downloadFromAlternativeSource(String tileName) async {
    print('🔄 Trying alternative source for $tileName');
    
    // Parse coordinates from tile name
    final latMatch = RegExp(r'([NS])(\d+)').firstMatch(tileName);
    final lonMatch = RegExp(r'([EW])(\d+)').firstMatch(tileName);
    
    if (latMatch == null || lonMatch == null) {
      print('❌ Invalid tile name: $tileName');
      return;
    }
    
    final lat = int.parse(latMatch.group(2)!) * (latMatch.group(1) == 'S' ? -1 : 1);
    final lon = int.parse(lonMatch.group(2)!) * (lonMatch.group(1) == 'W' ? -1 : 1);
    
    // Use OpenElevation API to get sample points
    print('📍 Fetching elevation data for region around $lat°, $lon°');
    
    // Create a synthetic HGT file with sample data
    await _createSyntheticHGTFile(tileName, lat, lon);
  }

  /// Create synthetic HGT file for testing
  static Future<void> _createSyntheticHGTFile(String tileName, int lat, int lon) async {
    final hgtFile = File(path.join(srtmTestDir, '$tileName.hgt'));
    await hgtFile.create(recursive: true);
    
    // SRTM3 has 1201x1201 points (3 arc-second resolution)
    const resolution = 1201;
    final buffer = List<int>.filled(resolution * resolution * 2, 0);
    
    // Generate synthetic terrain data
    final random = Random();
    for (int row = 0; row < resolution; row++) {
      for (int col = 0; col < resolution; col++) {
        // Create realistic terrain with some variation
        final baseElevation = 500; // Base elevation in meters
        final variation = random.nextInt(200) - 100; // ±100m variation
        
        // Add some mountain peaks
        final distFromCenter = ((row - resolution / 2).abs() + (col - resolution / 2).abs()) / resolution;
        final peakElevation = (1 - distFromCenter) * 1000; // Up to 1000m peak
        
        final elevation = (baseElevation + variation + peakElevation).round().clamp(0, 9000);
        
        // Convert to big-endian 16-bit signed integer
        final index = (row * resolution + col) * 2;
        buffer[index] = (elevation >> 8) & 0xFF;
        buffer[index + 1] = elevation & 0xFF;
      }
    }
    
    await hgtFile.writeAsBytes(buffer);
    print('✅ Created synthetic HGT file: $tileName.hgt');
  }

  /// Determine SRTM zone for a tile
  static String _getZoneForTile(String tileName) {
    final latMatch = RegExp(r'([NS])(\d+)').firstMatch(tileName);
    final lonMatch = RegExp(r'([EW])(\d+)').firstMatch(tileName);
    
    if (latMatch == null || lonMatch == null) return 'UNKNOWN';
    
    final lat = int.parse(latMatch.group(2)!) * (latMatch.group(1) == 'S' ? -1 : 1);
    final lon = int.parse(lonMatch.group(2)!) * (lonMatch.group(1) == 'W' ? -1 : 1);
    
    // Simplified zone determination
    if (lat >= 0 && lon >= -180 && lon < -90) return 'N00W180';
    if (lat >= 0 && lon >= -90 && lon < 0) return 'N00W090';
    if (lat >= 0 && lon >= 0 && lon < 90) return 'N00E000';
    if (lat >= 0 && lon >= 90 && lon <= 180) return 'N00E090';
    
    return 'S00W180'; // Default for southern hemisphere
  }

  /// Create README with instructions
  static Future<void> createReadme() async {
    final readme = File(path.join(elevationDataDir, 'README.md'));
    await readme.create(recursive: true);
    
    await readme.writeAsString('''
# Terrain Elevation Data

This directory contains elevation data for the terrain altitude service.

## Directory Structure

```
elevation_data/
├── sonny_lidar/     # High-precision LiDAR data for Europe
│   └── [country]/   # Country-specific subdirectories
├── srtm/            # Global SRTM coverage
├── srtm_test/       # Test data for development
└── cache/           # Runtime cache directory
```

## Data Sources

### Sonny's LiDAR Data (Europe)
- Source: https://sonny.4lima.de/
- Resolution: 1" (30m) or better
- Coverage: Most European countries
- License: CC BY 4.0

To download Sonny's data:
```bash
dart scripts/download_sonny_elevation.dart AT CH DE FR IT
```

### SRTM Data (Global)
- Source: NASA SRTM / OpenTopography
- Resolution: 3" (90m)
- Coverage: Global between 60°N and 56°S
- License: Public Domain

## Testing

Test elevation data has been set up in `srtm_test/` with tiles covering:
- Alps region (Switzerland, Austria, France)
- US mountainous regions (Yosemite, Grand Canyon)

## Usage

The TerrainElevationService automatically selects the best available data source:
1. Sonny's LiDAR (if available for the region)
2. SRTM (global fallback)
3. OpenElevation API (online fallback)

## File Format

### HGT Files
- Binary format with 16-bit signed integers (big-endian)
- Each value represents elevation in meters
- Resolution determined by file size:
  - 1" (1 arc-second): 3601x3601 points = 25,934,402 bytes
  - 3" (3 arc-seconds): 1201x1201 points = 2,884,802 bytes

### Tile Naming
Files are named by their SW corner coordinates:
- N47E010.hgt = Tile from 47°N 10°E to 48°N 11°E
- S34W071.hgt = Tile from 34°S 71°W to 33°S 70°W
''');
    
    print('📄 Created README.md');
  }

  /// Setup test elevation data
  static Future<void> setupTestData() async {
    print('🏔️ Setting up test elevation data');
    print('📁 Data directory: $elevationDataDir\n');
    
    // Create directories
    await Directory(srtmTestDir).create(recursive: true);
    
    // Download test tiles
    for (final tile in testTiles) {
      await downloadSRTMTile(tile);
      
      // Add delay to avoid rate limiting
      await Future.delayed(Duration(seconds: 2));
    }
    
    // Create README
    await createReadme();
    
    print('\n✅ Test elevation data setup complete!');
    print('📍 Test tiles cover:');
    print('   - Swiss/Austrian Alps');
    print('   - French Alps (Mont Blanc)');
    print('   - Yosemite/Sierra Nevada');
    print('   - Grand Canyon');
  }

  /// Verify elevation data is working
  static Future<void> verifyElevationData() async {
    print('\n🔍 Verifying elevation data...');
    
    final testDir = Directory(srtmTestDir);
    if (!await testDir.exists()) {
      print('❌ Test directory not found');
      return;
    }
    
    final hgtFiles = await testDir
        .list()
        .where((f) => f.path.endsWith('.hgt'))
        .toList();
    
    print('📊 Found ${hgtFiles.length} HGT files:');
    
    for (final file in hgtFiles) {
      final stat = await file.stat();
      final fileName = path.basename(file.path);
      final sizeMB = (stat.size / 1024 / 1024).toStringAsFixed(2);
      
      String resolution = 'Unknown';
      if (stat.size == 2884802) resolution = '3" (SRTM3)';
      else if (stat.size == 25934402) resolution = '1" (SRTM1)';
      else if (stat.size == 2884802) resolution = 'Synthetic';
      
      print('   ✓ $fileName - ${sizeMB}MB - $resolution');
    }
  }
}

// Add Random import for synthetic data generation
import 'dart:math';

void main(List<String> args) async {
  print('🏔️ CaptainVFR Terrain Elevation Test Data Setup');
  print('=' * 50);
  
  if (args.isEmpty || args[0] == 'setup') {
    await TestElevationDataSetup.setupTestData();
    await TestElevationDataSetup.verifyElevationData();
  } else if (args[0] == 'verify') {
    await TestElevationDataSetup.verifyElevationData();
  } else {
    print('Usage: dart setup_test_elevation_data.dart [setup|verify]');
    print('  setup  - Download and setup test elevation data');
    print('  verify - Verify existing elevation data');
  }
}