import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'offline_map_service.dart';

/// Custom tile provider that supports both online and offline tiles
class OfflineTileProvider extends TileProvider {
  final String urlTemplate;
  final OfflineMapService offlineMapService;
  final String? userAgentPackageName;

  OfflineTileProvider({
    required this.urlTemplate,
    required this.offlineMapService,
    this.userAgentPackageName,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return OfflineTileImageProvider(
      coordinates: coordinates,
      urlTemplate: urlTemplate,
      offlineMapService: offlineMapService,
      userAgentPackageName: userAgentPackageName,
    );
  }
}

/// Custom image provider for offline tiles
class OfflineTileImageProvider extends ImageProvider<OfflineTileImageProvider> {
  final TileCoordinates coordinates;
  final String urlTemplate;
  final OfflineMapService offlineMapService;
  final String? userAgentPackageName;

  const OfflineTileImageProvider({
    required this.coordinates,
    required this.urlTemplate,
    required this.offlineMapService,
    this.userAgentPackageName,
  });

  @override
  Future<OfflineTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OfflineTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(
    OfflineTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final Logger logger = Logger();

    try {
      // First, try to get the tile from offline cache
      final cachedTile = await offlineMapService.getCachedTile(
        coordinates.z,
        coordinates.x,
        coordinates.y,
      );

      if (cachedTile != null && cachedTile.isNotEmpty) {
        try {
          // Validate that the cached data is actually an image
          final buffer = await ImmutableBuffer.fromUint8List(cachedTile);
          return await decode(buffer);
        } catch (e) {
          // Cached tile is corrupted, delete it and continue to download
          logger.w('Corrupted cached tile ${coordinates.z}/${coordinates.x}/${coordinates.y}, removing from cache');
          // Don't await to avoid blocking
          offlineMapService.deleteCachedTile(coordinates.z, coordinates.x, coordinates.y);
        }
      }

      // If not cached, try to download from online source
      final url = urlTemplate
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString());

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              if (userAgentPackageName != null)
                'User-Agent': userAgentPackageName!,
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // Validate that we got valid image data
        if (bytes.isEmpty) {
          throw Exception('Empty response body');
        }

        try {
          final buffer = await ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          
          // Only store the tile if it decoded successfully
          _storeTileAsync(coordinates.z, coordinates.x, coordinates.y, bytes);
          
          return codec;
        } catch (e) {
          // Don't store corrupted data
          throw Exception('Invalid image data: $e');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Log the error but don't spam the console for common errors
      if (e.toString().contains('TimeoutException')) {
        // Silent fail for timeouts - map will show blank tile
      } else if (e.toString().contains('Codec failed') || 
                 e.toString().contains('Invalid image data')) {
        // Silent fail for image codec errors - these are expected for corrupted tiles
        logger.d('Skipping corrupted tile ${coordinates.z}/${coordinates.x}/${coordinates.y}');
      } else if (!e.toString().contains('HTTP 404') && 
                 !e.toString().contains('HTTP 403')) {
        // Only log unexpected errors
        logger.w(
          '⚠️ Failed to load tile ${coordinates.z}/${coordinates.x}/${coordinates.y}: $e',
        );
      }

      // Return a transparent placeholder instead of throwing
      try {
        final transparentPixel = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
          0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
          0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
          0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
          0x42, 0x60, 0x82,
        ]);
        final buffer = await ImmutableBuffer.fromUint8List(transparentPixel);
        return await decode(buffer);
      } catch (_) {
        // If we can't even create a transparent image, rethrow the original error
        throw Exception('Failed to load map tile: $e');
      }
    }
  }

  /// Store tile asynchronously without blocking the UI
  void _storeTileAsync(int z, int x, int y, Uint8List tileData) {
    // Run in background without awaiting to avoid blocking tile loading
    () async {
      try {
        // Use the offline map service to store the tile
        await offlineMapService.storeTileDirectly(z, x, y, tileData);
      } catch (e) {
        Logger().w('⚠️ Failed to cache tile $z/$x/$y: $e');
      }
    }();
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is OfflineTileImageProvider &&
        other.coordinates == coordinates &&
        other.urlTemplate == urlTemplate;
  }

  @override
  int get hashCode => Object.hash(coordinates, urlTemplate);
}
