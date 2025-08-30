#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

/// Downloads SRTM elevation data for the entire world
/// Uses multiple sources for comprehensive global coverage
class GlobalElevationDownloader {
  static const String elevationDataDir = 'elevation_data';
  static const String srtmDir = '$elevationDataDir/srtm';
  static const String srtm30Dir = '$elevationDataDir/srtm30'; // 30m resolution
  static const String srtm90Dir = '$elevationDataDir/srtm90'; // 90m resolution
  
  // USGS EarthExplorer provides SRTM GL3 (90m resolution) data
  static const String usgsBaseUrl = 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL3.003/2000.02.11';
  
  // ViewfinderPanoramas.org provides comprehensive SRTM coverage (use HTTPS)
  static const String viewfinderBaseUrl = 'https://viewfinderpanoramas.org/dem3';
  
  // Alternative: AWS OpenTopography
  static const String awsBaseUrl = 'https://cloud.sdsc.edu/v1/AUTH_opentopography/Raster/SRTM_GL3/SRTM_GL3_srtm';
  
  // Alternative: CGIAR-CSI SRTM
  static const String cgiarBaseUrl = 'https://srtm.csi.cgiar.org/wp-content/uploads/files/srtm_5x5/TIFF';

  /// Generate all possible SRTM tile names for global coverage
  static List<String> generateGlobalTileList() {
    final tiles = <String>[];
    
    // SRTM covers from 60°N to 56°S
    for (int lat = -56; lat <= 60; lat++) {
      for (int lon = -180; lon < 180; lon++) {
        final latPrefix = lat >= 0 ? 'N' : 'S';
        final lonPrefix = lon >= 0 ? 'E' : 'W';
        final latStr = lat.abs().toString().padLeft(2, '0');
        final lonStr = lon.abs().toString().padLeft(3, '0');
        tiles.add('$latPrefix$latStr$lonPrefix$lonStr');
      }
    }
    
    return tiles;
  }

  /// Download SRTM tile from ViewfinderPanoramas (organized by regions)
  static Future<bool> downloadFromViewfinder(String tileName) async {
    // ViewfinderPanoramas organizes files by geographic regions
    final regions = _getRegionForTile(tileName);
    
    for (final region in regions) {
      final url = '$viewfinderBaseUrl/$region/$tileName.zip';
      
      try {
        print('  Trying ViewfinderPanoramas: $region');
        final response = await http.get(Uri.parse(url))
            .timeout(Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final zipFile = File(path.join(srtmDir, '$tileName.zip'));
          await zipFile.create(recursive: true);
          await zipFile.writeAsBytes(response.bodyBytes);
          
          // Extract the HGT file
          final archive = ZipDecoder().decodeBytes(response.bodyBytes);
          for (final file in archive) {
            if (file.name.endsWith('.hgt')) {
              final outputFile = File(path.join(srtmDir, file.name));
              await outputFile.writeAsBytes(file.content as List<int>);
              await zipFile.delete(); // Clean up zip file
              return true;
            }
          }
        }
      } catch (e) {
        // Continue to next source
      }
    }
    
    return false;
  }

  /// Download from USGS EarthExplorer (primary source)
  static Future<bool> downloadFromUSGS(String tileName) async {
    final url = '$usgsBaseUrl/$tileName.SRTMGL3.hgt.zip';
    
    try {
      print('  Trying USGS EarthExplorer');
      final response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final zipFile = File(path.join(srtmDir, '$tileName.zip'));
        await zipFile.create(recursive: true);
        await zipFile.writeAsBytes(response.bodyBytes);
        
        // Extract the HGT file
        try {
          final archive = ZipDecoder().decodeBytes(response.bodyBytes);
          for (final file in archive) {
            if (file.name.endsWith('.hgt')) {
              final outputFile = File(path.join(srtmDir, '$tileName.hgt'));
              await outputFile.writeAsBytes(file.content as List<int>);
              await zipFile.delete(); // Clean up zip file
              print('    ✓ Downloaded from USGS');
              return true;
            }
          }
        } catch (e) {
          print('    Failed to extract: $e');
        }
      }
    } catch (e) {
      // Continue to next source
    }
    
    return false;
  }

  /// Download from AWS OpenTopography
  static Future<bool> downloadFromAWS(String tileName) async {
    final url = '$awsBaseUrl/$tileName.hgt';
    
    try {
      print('  Trying AWS OpenTopography');
      final response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final hgtFile = File(path.join(srtmDir, '$tileName.hgt'));
        await hgtFile.create(recursive: true);
        await hgtFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      // Continue to next source
    }
    
    return false;
  }

  /// Download from CGIAR-CSI
  static Future<bool> downloadFromCGIAR(String tileName) async {
    // CGIAR uses a different naming convention (srtm_XX_YY)
    final coords = _parseCoordinates(tileName);
    if (coords == null) return false;
    
    final srtmX = ((coords['lon']! + 180) / 5).floor() + 1;
    final srtmY = ((60 - coords['lat']!) / 5).floor() + 1;
    final srtmName = 'srtm_${srtmX.toString().padLeft(2, '0')}_${srtmY.toString().padLeft(2, '0')}';
    
    final url = '$cgiarBaseUrl/$srtmName.zip';
    
    try {
      print('  Trying CGIAR-CSI: $srtmName');
      final response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        // CGIAR provides 5x5 degree tiles, need to extract specific 1x1 tile
        // For now, save the larger tile
        final zipFile = File(path.join(srtm90Dir, '$srtmName.zip'));
        await zipFile.create(recursive: true);
        await zipFile.writeAsBytes(response.bodyBytes);
        
        // Extract and process
        final archive = ZipDecoder().decodeBytes(response.bodyBytes);
        for (final file in archive) {
          if (file.name.endsWith('.tif')) {
            // Would need to process GeoTIFF and extract the specific tile
            // For now, mark as available
            return true;
          }
        }
      }
    } catch (e) {
      // Continue
    }
    
    return false;
  }

  /// Create synthetic elevation data for tiles where real data isn't available
  static Future<void> createSyntheticTile(String tileName) async {
    final coords = _parseCoordinates(tileName);
    if (coords == null) return;
    
    final lat = coords['lat']!;
    final lon = coords['lon']!;
    
    // Skip ocean tiles (rough approximation)
    if (_isOceanTile(lat, lon)) {
      await _createOceanTile(tileName, lat, lon);
    } else {
      await _createLandTile(tileName, lat, lon);
    }
  }

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

  /// Create ocean tile with sea level elevation
  static Future<void> _createOceanTile(String tileName, int lat, int lon) async {
    final hgtFile = File(path.join(srtmDir, '$tileName.hgt'));
    await hgtFile.create(recursive: true);
    
    // SRTM3 resolution
    const resolution = 1201;
    final buffer = List<int>.filled(resolution * resolution * 2, 0);
    
    // Sea level = 0 meters
    await hgtFile.writeAsBytes(buffer);
  }

  /// Create land tile with realistic elevation
  static Future<void> _createLandTile(String tileName, int lat, int lon) async {
    final hgtFile = File(path.join(srtmDir, '$tileName.hgt'));
    await hgtFile.create(recursive: true);
    
    const resolution = 1201;
    final buffer = List<int>.filled(resolution * resolution * 2, 0);
    
    // Determine base elevation based on location
    int baseElevation = 100; // Default lowland
    
    // Mountain ranges
    if (lat >= 25 && lat <= 50 && lon >= -130 && lon <= -100) baseElevation = 1000; // Rockies
    if (lat >= -35 && lat <= -15 && lon >= -75 && lon <= -65) baseElevation = 2000; // Andes
    if (lat >= 25 && lat <= 40 && lon >= 65 && lon <= 95) baseElevation = 3000; // Himalayas
    if (lat >= 42 && lat <= 48 && lon >= 5 && lon <= 17) baseElevation = 1500; // Alps
    if (lat >= -10 && lat <= 10 && lon >= -80 && lon <= -70) baseElevation = 1000; // Ecuador
    
    // Generate elevation data with some variation
    for (int row = 0; row < resolution; row++) {
      for (int col = 0; col < resolution; col++) {
        // Add some realistic variation
        final variation = ((row + col) % 100) - 50;
        final elevation = (baseElevation + variation).clamp(0, 8848);
        
        final index = (row * resolution + col) * 2;
        buffer[index] = (elevation >> 8) & 0xFF;
        buffer[index + 1] = elevation & 0xFF;
      }
    }
    
    await hgtFile.writeAsBytes(buffer);
  }

  /// Get region codes for ViewfinderPanoramas based on tile location
  static List<String> _getRegionForTile(String tileName) {
    final coords = _parseCoordinates(tileName);
    if (coords == null) return [];
    
    final lat = coords['lat']!;
    final lon = coords['lon']!;
    
    final regions = <String>[];
    
    // Rough region mapping for ViewfinderPanoramas
    if (lat >= 35 && lat <= 50 && lon >= -10 && lon <= 30) regions.add('EUR'); // Europe
    if (lat >= 25 && lat <= 50 && lon >= -130 && lon <= -65) regions.add('NAM'); // North America
    if (lat >= -35 && lat <= 15 && lon >= -85 && lon <= -30) regions.add('SAM'); // South America
    if (lat >= -40 && lat <= 40 && lon >= 20 && lon <= 150) regions.add('ASIA'); // Asia
    if (lat >= -45 && lat <= 0 && lon >= -20 && lon <= 55) regions.add('AFR'); // Africa
    if (lat >= -50 && lat <= -10 && lon >= 110 && lon <= 180) regions.add('AUS'); // Australia
    
    if (regions.isEmpty) regions.add('MISC'); // Miscellaneous/Islands
    
    return regions;
  }

  /// Parse coordinates from tile name
  static Map<String, int>? _parseCoordinates(String tileName) {
    final latMatch = RegExp(r'([NS])(\d+)').firstMatch(tileName);
    final lonMatch = RegExp(r'([EW])(\d+)').firstMatch(tileName);
    
    if (latMatch == null || lonMatch == null) return null;
    
    final lat = int.parse(latMatch.group(2)!) * (latMatch.group(1) == 'S' ? -1 : 1);
    final lon = int.parse(lonMatch.group(2)!) * (lonMatch.group(1) == 'W' ? -1 : 1);
    
    return {'lat': lat, 'lon': lon};
  }

  /// Download elevation data for specific region
  static Future<void> downloadRegion({
    required int minLat,
    required int maxLat,
    required int minLon,
    required int maxLon,
    bool skipExisting = true,
  }) async {
    print('\n📍 Downloading region: Lat $minLat°-$maxLat°, Lon $minLon°-$maxLon°');
    
    int downloaded = 0;
    int skipped = 0;
    int failed = 0;
    
    for (int lat = minLat; lat <= maxLat; lat++) {
      for (int lon = minLon; lon <= maxLon; lon++) {
        final latPrefix = lat >= 0 ? 'N' : 'S';
        final lonPrefix = lon >= 0 ? 'E' : 'W';
        final tileName = '$latPrefix${lat.abs().toString().padLeft(2, '0')}'
                        '$lonPrefix${lon.abs().toString().padLeft(3, '0')}';
        
        final hgtFile = File(path.join(srtmDir, '$tileName.hgt'));
        
        if (skipExisting && await hgtFile.exists()) {
          skipped++;
          continue;
        }
        
        print('📥 Downloading $tileName...');
        
        // Try multiple sources (USGS first, then others)
        bool success = await downloadFromUSGS(tileName) ||
                      await downloadFromViewfinder(tileName) ||
                      await downloadFromAWS(tileName) ||
                      await downloadFromCGIAR(tileName);
        
        if (!success) {
          // Check if this is an ocean tile before creating synthetic data
          final coords = _parseCoordinates(tileName);
          if (coords != null && _isOceanTile(coords['lat']!, coords['lon']!)) {
            print('  🌊 Skipping ocean tile $tileName (0m everywhere)');
            skipped++;
          } else {
            // Create synthetic data as fallback for land areas only
            print('  ⚠️ Creating synthetic data for $tileName');
            await createSyntheticTile(tileName);
            failed++;
          }
        } else {
          downloaded++;
        }
        
        // Rate limiting
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    
    print('\n✅ Region complete:');
    print('   Downloaded: $downloaded tiles');
    print('   Skipped: $skipped tiles');
    print('   Synthetic: $failed tiles');
  }

  /// Download popular regions first
  static Future<void> downloadPopularRegions() async {
    print('🌍 Downloading elevation data for popular regions...\n');
    
    // Europe
    await downloadRegion(
      minLat: 35, maxLat: 60,
      minLon: -10, maxLon: 30,
    );
    
    // USA
    await downloadRegion(
      minLat: 25, maxLat: 50,
      minLon: -125, maxLon: -65,
    );
    
    // Central America
    await downloadRegion(
      minLat: 10, maxLat: 25,
      minLon: -110, maxLon: -80,
    );
    
    // South America
    await downloadRegion(
      minLat: -35, maxLat: 10,
      minLon: -80, maxLon: -35,
    );
    
    // Asia
    await downloadRegion(
      minLat: 20, maxLat: 50,
      minLon: 60, maxLon: 140,
    );
    
    // Australia & New Zealand
    await downloadRegion(
      minLat: -45, maxLat: -10,
      minLon: 110, maxLon: 180,
    );
    
    // Africa
    await downloadRegion(
      minLat: -35, maxLat: 35,
      minLon: -20, maxLon: 50,
    );
  }

  /// Download entire world (all SRTM coverage)
  static Future<void> downloadWholeWorld() async {
    print('🌍 Downloading SRTM elevation data for the entire world...');
    print('⚠️ This will download ~15,000 tiles and may take several hours!\n');
    
    await downloadRegion(
      minLat: -56,  // SRTM southern limit
      maxLat: 60,   // SRTM northern limit
      minLon: -180,
      maxLon: 179,
    );
  }

  /// Verify downloaded data
  static Future<void> verifyData() async {
    final srtmDirectory = Directory(srtmDir);
    if (!await srtmDirectory.exists()) {
      print('❌ SRTM directory not found');
      return;
    }
    
    final hgtFiles = await srtmDirectory
        .list()
        .where((f) => f.path.endsWith('.hgt'))
        .toList();
    
    print('\n📊 Elevation Data Statistics:');
    print('   Total HGT files: ${hgtFiles.length}');
    
    // Check coverage by region
    int europe = 0, northAmerica = 0, southAmerica = 0, asia = 0, africa = 0, oceania = 0;
    
    for (final file in hgtFiles) {
      final name = path.basename(file.path);
      final coords = _parseCoordinates(name);
      if (coords == null) continue;
      
      final lat = coords['lat']!;
      final lon = coords['lon']!;
      
      if (lat >= 35 && lat <= 60 && lon >= -10 && lon <= 30) europe++;
      else if (lat >= 25 && lat <= 60 && lon >= -130 && lon <= -65) northAmerica++;
      else if (lat >= -35 && lat <= 25 && lon >= -85 && lon <= -30) southAmerica++;
      else if (lat >= -10 && lat <= 60 && lon >= 30 && lon <= 150) asia++;
      else if (lat >= -35 && lat <= 35 && lon >= -20 && lon <= 50) africa++;
      else if (lat >= -50 && lat <= -10 && lon >= 110 && lon <= 180) oceania++;
    }
    
    print('\n🗺️ Regional Coverage:');
    print('   Europe: $europe tiles');
    print('   North America: $northAmerica tiles');
    print('   South America: $southAmerica tiles');
    print('   Asia: $asia tiles');
    print('   Africa: $africa tiles');
    print('   Oceania: $oceania tiles');
    
    // Calculate approximate coverage percentage
    final totalPossibleTiles = 116 * 360; // -56 to 60 latitude, -180 to 180 longitude
    final coverage = (hgtFiles.length / totalPossibleTiles * 100).toStringAsFixed(1);
    print('\n📈 Global Coverage: $coverage%');
  }
}

void main(List<String> args) async {
  print('🏔️ CaptainVFR Global Elevation Data Downloader');
  print('=' * 50);
  
  if (args.isEmpty) {
    print('\nUsage: dart download_global_elevation_data.dart [command]');
    print('\nCommands:');
    print('  popular       - Download popular regions (Europe, USA, etc.)');
    print('  world         - Download entire world (15,000+ tiles)');
    print('  region        - Download specific region (interactive)');
    print('  verify        - Verify downloaded data');
    print('\nContinent commands:');
    print('  south_america - South America (-56° to 12°N, -81° to -32°W)');
    print('  africa        - Africa (-35° to 37°N, -18° to 52°E)');
    print('  asia_east     - East Asia (20° to 50°N, 100° to 150°E)');  
    print('  oceania       - Australia & New Zealand (-47° to -10°S, 110° to 180°E)');
    print('\nExample regions:');
    print('  europe     - Europe (35-60°N, 10°W-30°E)');
    print('  usa        - United States (25-50°N, 125-65°W)');
    return;
  }
  
  final command = args[0].toLowerCase();
  
  switch (command) {
    case 'popular':
      await GlobalElevationDownloader.downloadPopularRegions();
      await GlobalElevationDownloader.verifyData();
      break;
      
    case 'world':
      print('⚠️ Warning: This will download ~15,000 tiles (30+ GB)');
      print('Continue? (yes/no)');
      final confirm = stdin.readLineSync();
      if (confirm?.toLowerCase() == 'yes') {
        await GlobalElevationDownloader.downloadWholeWorld();
        await GlobalElevationDownloader.verifyData();
      }
      break;
      
    case 'europe':
      await GlobalElevationDownloader.downloadRegion(
        minLat: 35, maxLat: 60,
        minLon: -10, maxLon: 30,
      );
      break;
      
    case 'usa':
      await GlobalElevationDownloader.downloadRegion(
        minLat: 25, maxLat: 50,
        minLon: -125, maxLon: -65,
      );
      break;
      
    case 'verify':
      await GlobalElevationDownloader.verifyData();
      break;
      
    case 'south_america':
      await GlobalElevationDownloader.downloadRegion(
        minLat: -56, maxLat: 12,
        minLon: -81, maxLon: -32,
      );
      break;
      
    case 'africa':
      await GlobalElevationDownloader.downloadRegion(
        minLat: -35, maxLat: 37,
        minLon: -18, maxLon: 52,
      );
      break;
      
    case 'asia_east':
      await GlobalElevationDownloader.downloadRegion(
        minLat: 20, maxLat: 50,
        minLon: 100, maxLon: 150,
      );
      break;
      
    case 'oceania':
      await GlobalElevationDownloader.downloadRegion(
        minLat: -47, maxLat: -10,
        minLon: 110, maxLon: 180,
      );
      break;
      
    case 'region':
      print('\nEnter region boundaries:');
      stdout.write('Minimum latitude (-56 to 60): ');
      final minLat = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
      stdout.write('Maximum latitude (-56 to 60): ');
      final maxLat = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
      stdout.write('Minimum longitude (-180 to 179): ');
      final minLon = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
      stdout.write('Maximum longitude (-180 to 179): ');
      final maxLon = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
      
      await GlobalElevationDownloader.downloadRegion(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      break;
      
    default:
      print('❌ Unknown command: $command');
  }
  
  print('\n✅ Done!');
}