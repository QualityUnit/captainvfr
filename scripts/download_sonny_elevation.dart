#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

/// Downloads and processes Sonny's LiDAR elevation data for European countries
/// Data source: https://sonny.4lima.de/
/// License: CC BY 4.0 - Attribution required
class SonnyElevationDownloader {
  static const String baseDataDir = 'elevation_data/sonny_lidar';
  static const String tempDir = 'elevation_data/temp';
  
  // Sonny's Google Drive download links for 1" resolution European countries
  // These need to be updated based on the actual links from the website
  static const Map<String, String> countryDownloadLinks = {
    // Format: 'COUNTRY_CODE': 'google_drive_file_id'
    // These would be extracted from the website
    'AT': 'austria_1arc_dtm_file_id',  // Austria
    'CH': 'switzerland_1arc_dtm_file_id',  // Switzerland  
    'DE': 'germany_1arc_dtm_file_id',  // Germany
    'FR': 'france_1arc_dtm_file_id',  // France
    'IT': 'italy_1arc_dtm_file_id',  // Italy
    'ES': 'spain_1arc_dtm_file_id',  // Spain
    'PT': 'portugal_1arc_dtm_file_id',  // Portugal
    'GB': 'uk_1arc_dtm_file_id',  // United Kingdom
    'IE': 'ireland_1arc_dtm_file_id',  // Ireland
    'NL': 'netherlands_1arc_dtm_file_id',  // Netherlands
    'BE': 'belgium_1arc_dtm_file_id',  // Belgium
    'LU': 'luxembourg_1arc_dtm_file_id',  // Luxembourg
    'DK': 'denmark_1arc_dtm_file_id',  // Denmark
    'SE': 'sweden_1arc_dtm_file_id',  // Sweden
    'NO': 'norway_1arc_dtm_file_id',  // Norway
    'FI': 'finland_1arc_dtm_file_id',  // Finland
    'PL': 'poland_1arc_dtm_file_id',  // Poland
    'CZ': 'czech_1arc_dtm_file_id',  // Czech Republic
    'SK': 'slovakia_1arc_dtm_file_id',  // Slovakia
    'HU': 'hungary_1arc_dtm_file_id',  // Hungary
    'RO': 'romania_1arc_dtm_file_id',  // Romania
    'BG': 'bulgaria_1arc_dtm_file_id',  // Bulgaria
    'GR': 'greece_1arc_dtm_file_id',  // Greece
    'HR': 'croatia_1arc_dtm_file_id',  // Croatia
    'SI': 'slovenia_1arc_dtm_file_id',  // Slovenia
    'EE': 'estonia_1arc_dtm_file_id',  // Estonia
    'LV': 'latvia_1arc_dtm_file_id',  // Latvia
    'LT': 'lithuania_1arc_dtm_file_id',  // Lithuania
  };

  /// Download file from Google Drive
  static Future<void> downloadFromGoogleDrive(
    String fileId, 
    String outputPath,
    String countryName,
  ) async {
    print('📥 Downloading $countryName elevation data...');
    
    // Google Drive direct download URL format
    final url = 'https://drive.google.com/uc?export=download&id=$fileId';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final file = File(outputPath);
        await file.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        print('✅ Downloaded $countryName (${response.bodyBytes.length ~/ 1024 ~/ 1024} MB)');
      } else {
        print('❌ Failed to download $countryName: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error downloading $countryName: $e');
    }
  }

  /// Extract HGT files from downloaded ZIP
  static Future<void> extractHgtFiles(String zipPath, String outputDir) async {
    print('📦 Extracting elevation files...');
    
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    int extractedCount = 0;
    for (final file in archive) {
      if (file.isFile && file.name.endsWith('.hgt')) {
        final outputFile = File(path.join(outputDir, path.basename(file.name)));
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
        extractedCount++;
      }
    }
    
    print('✅ Extracted $extractedCount HGT files');
  }

  /// Process HGT file into our tile format
  static Future<void> processHgtToTiles(String hgtPath, String outputDir) async {
    final file = File(hgtPath);
    final fileName = path.basenameWithoutExtension(file.path);
    
    // Parse coordinates from filename (e.g., N47E010.hgt)
    final latMatch = RegExp(r'([NS])(\d+)').firstMatch(fileName);
    final lonMatch = RegExp(r'([EW])(\d+)').firstMatch(fileName);
    
    if (latMatch == null || lonMatch == null) {
      print('⚠️ Skipping invalid HGT file: $fileName');
      return;
    }
    
    final lat = int.parse(latMatch.group(2)!) * (latMatch.group(1) == 'S' ? -1 : 1);
    final lon = int.parse(lonMatch.group(2)!) * (lonMatch.group(1) == 'W' ? -1 : 1);
    
    // Read HGT file (1" = 3601x3601 points, 2 bytes per point)
    final bytes = await file.readAsBytes();
    const resolution = 3601; // 1 arc-second resolution
    
    // Convert to our tile format with metadata
    final tileData = {
      'source': 'sonny_lidar',
      'resolution': '1_arc_second',
      'lat': lat,
      'lon': lon,
      'accuracy': 'high',
      'attribution': 'Sonny (sonny.4lima.de) - CC BY 4.0',
      'data_points': resolution * resolution,
      'min_elevation': 0,
      'max_elevation': 0,
    };
    
    // Calculate min/max elevation for metadata
    int minElev = 32767;
    int maxElev = -32768;
    
    for (int i = 0; i < bytes.length - 1; i += 2) {
      // HGT files use big-endian 16-bit signed integers
      final elevation = (bytes[i] << 8) | bytes[i + 1];
      if (elevation != -32768) { // -32768 = void/no data
        if (elevation < minElev) minElev = elevation;
        if (elevation > maxElev) maxElev = elevation;
      }
    }
    
    tileData['min_elevation'] = minElev;
    tileData['max_elevation'] = maxElev;
    
    // Save processed tile
    final outputPath = path.join(outputDir, 'tile_${lat}_${lon}.json');
    final outputFile = File(outputPath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(jsonEncode(tileData));
    
    // Also copy raw HGT file for elevation queries
    final hgtOutputPath = path.join(outputDir, '$fileName.hgt');
    await file.copy(hgtOutputPath);
  }

  /// Download and process all European countries
  static Future<void> downloadAllEurope() async {
    // Create directories
    await Directory(baseDataDir).create(recursive: true);
    await Directory(tempDir).create(recursive: true);
    
    print('🌍 Starting Sonny\'s LiDAR elevation data download for Europe');
    print('📍 Data will be saved to: $baseDataDir');
    print('⚖️ License: CC BY 4.0 - Attribution required\n');
    
    // Download each country
    for (final entry in countryDownloadLinks.entries) {
      final countryCode = entry.key;
      final fileId = entry.value;
      final zipPath = path.join(tempDir, '${countryCode.toLowerCase()}_elevation.zip');
      
      // Download country data
      await downloadFromGoogleDrive(fileId, zipPath, countryCode);
      
      // Extract HGT files
      final countryDir = path.join(baseDataDir, countryCode.toLowerCase());
      await extractHgtFiles(zipPath, countryDir);
      
      // Process each HGT file
      final hgtFiles = Directory(countryDir)
          .listSync()
          .where((f) => f.path.endsWith('.hgt'));
      
      print('🔄 Processing ${hgtFiles.length} tiles for $countryCode...');
      for (final hgtFile in hgtFiles) {
        await processHgtToTiles(hgtFile.path, countryDir);
      }
      
      // Clean up ZIP file to save space
      await File(zipPath).delete();
    }
    
    // Clean up temp directory
    await Directory(tempDir).delete(recursive: true);
    
    print('\n✅ European LiDAR elevation data download complete!');
    print('📊 Data stored in: $baseDataDir');
    print('📝 Remember to add attribution: "Elevation data by Sonny (sonny.4lima.de)"');
  }

  /// Download specific countries only
  static Future<void> downloadCountries(List<String> countryCodes) async {
    await Directory(baseDataDir).create(recursive: true);
    await Directory(tempDir).create(recursive: true);
    
    for (final countryCode in countryCodes) {
      if (!countryDownloadLinks.containsKey(countryCode)) {
        print('⚠️ Unknown country code: $countryCode');
        continue;
      }
      
      final fileId = countryDownloadLinks[countryCode]!;
      final zipPath = path.join(tempDir, '${countryCode.toLowerCase()}_elevation.zip');
      
      await downloadFromGoogleDrive(fileId, zipPath, countryCode);
      
      final countryDir = path.join(baseDataDir, countryCode.toLowerCase());
      await extractHgtFiles(zipPath, countryDir);
      
      final hgtFiles = Directory(countryDir)
          .listSync()
          .where((f) => f.path.endsWith('.hgt'));
      
      for (final hgtFile in hgtFiles) {
        await processHgtToTiles(hgtFile.path, countryDir);
      }
      
      await File(zipPath).delete();
    }
    
    await Directory(tempDir).delete(recursive: true);
  }
}

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart download_sonny_elevation.dart [all|COUNTRY_CODES]');
    print('Examples:');
    print('  dart download_sonny_elevation.dart all');
    print('  dart download_sonny_elevation.dart AT CH DE');
    print('\nAvailable country codes:');
    print(SonnyElevationDownloader.countryDownloadLinks.keys.join(', '));
    return;
  }
  
  if (args[0] == 'all') {
    await SonnyElevationDownloader.downloadAllEurope();
  } else {
    await SonnyElevationDownloader.downloadCountries(args);
  }
}