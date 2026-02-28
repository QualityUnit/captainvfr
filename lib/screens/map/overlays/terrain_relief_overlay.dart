import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Custom tile provider with connection limiting for terrain tiles
class LimitedConnectionTileProvider extends TileProvider {
  static final _httpClient = http.Client();
  static const int maxConcurrentTiles = 3;
  static int _activeRequests = 0;
  static final List<Function> _pendingRequests = [];
  
  // Cache for non-existent tiles to avoid repeated requests
  static final Set<String> _nonExistentTiles = {};

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return NetworkImageWithRetry(
      url,
      httpClient: _httpClient,
    );
  }

  static void _processNextRequest() {
    if (_pendingRequests.isNotEmpty && _activeRequests < maxConcurrentTiles) {
      final nextRequest = _pendingRequests.removeAt(0);
      nextRequest();
    }
  }

  static Future<T> _executeWithLimit<T>(Future<T> Function() request) async {
    if (_activeRequests >= maxConcurrentTiles) {
      // Queue the request
      final completer = Completer<T>();
      _pendingRequests.add(() async {
        _activeRequests++;
        try {
          final result = await request();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        } finally {
          _activeRequests--;
          _processNextRequest();
        }
      });
      return completer.future;
    } else {
      _activeRequests++;
      try {
        return await request();
      } finally {
        _activeRequests--;
        _processNextRequest();
      }
    }
  }
}

/// Network image provider with retry logic and connection limiting
class NetworkImageWithRetry extends ImageProvider<NetworkImageWithRetry> {
  final String url;
  final http.Client? httpClient;
  final double scale;

  const NetworkImageWithRetry(
    this.url, {
    this.httpClient,
    this.scale = 1.0,
  });

  @override
  Future<NetworkImageWithRetry> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImageWithRetry>(this);
  }

  @override
  ImageStreamCompleter loadImage(NetworkImageWithRetry key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
    );
  }

  Future<Codec> _loadAsync(NetworkImageWithRetry key, ImageDecoderCallback decode) async {
    try {
      // Check if this tile is known to be non-existent
      if (LimitedConnectionTileProvider._nonExistentTiles.contains(key.url)) {
        final buffer = await ImmutableBuffer.fromUint8List(_transparentImage);
        return decode(buffer);
      }
      
      // Use the limited connection execution
      final Uint8List bytes = await LimitedConnectionTileProvider._executeWithLimit(() async {
        final client = RetryClient(
          httpClient ?? http.Client(),
          retries: 2,
          delay: (retryCount) => const Duration(milliseconds: 500) * retryCount,
        );
        
        try {
          final response = await client.get(Uri.parse(key.url)).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Tile request timed out'),
          );
          
          if (response.statusCode == 200) {
            return response.bodyBytes;
          } else if (response.statusCode == 404 || response.statusCode == 403) {
            // Cache this as a non-existent tile
            LimitedConnectionTileProvider._nonExistentTiles.add(key.url);
            // Limit cache size to prevent memory issues
            if (LimitedConnectionTileProvider._nonExistentTiles.length > 10000) {
              // Remove oldest entries (convert to list, remove first half, convert back)
              final list = LimitedConnectionTileProvider._nonExistentTiles.toList();
              LimitedConnectionTileProvider._nonExistentTiles.clear();
              LimitedConnectionTileProvider._nonExistentTiles.addAll(
                list.sublist(list.length ~/ 2)
              );
            }
            // Return transparent 1x1 image for missing tiles or access denied
            return _transparentImage;
          } else {
            throw HttpException('Failed to load tile: ${response.statusCode}');
          }
        } finally {
          if (httpClient == null) {
            client.close();
          }
        }
      });

      final buffer = await ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      // Return transparent image on error
      final buffer = await ImmutableBuffer.fromUint8List(_transparentImage);
      return decode(buffer);
    }
  }

  static final Uint8List _transparentImage = Uint8List.fromList([
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

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is NetworkImageWithRetry && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

/// Overlay for displaying elevation terrain with hillshading
/// Uses pre-rendered terrain tiles from S3 for beautiful 3D visualization
/// Single zoom level 10 with client-side scaling for optimal performance
class TerrainReliefOverlay extends StatelessWidget {
  final bool isVisible;
  final double opacity;
  
  const TerrainReliefOverlay({
    super.key,
    this.isVisible = true,
    this.opacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: TileLayer(
          urlTemplate: 'https://assets.captainvfr.com/terrain_tiles/9/{x}/{y}.png',
          userAgentPackageName: 'com.captainvfr.captainvfr',
          maxNativeZoom: 9,   // Single zoom level 9 (512 tiles total)
          minNativeZoom: 9,   // Single zoom level 9 (512 tiles total)
          maxZoom: 16,        // Allow overzooming (scales tiles up)
          minZoom: 5,         // Allow underzooming (scales tiles down)
          tileProvider: LimitedConnectionTileProvider(),
          errorTileCallback: (tile, error, stackTrace) {
            // Silently ignore tile load errors for areas without terrain data
            // (e.g., ocean areas where we skip generation)
          },
          tileBuilder: (context, widget, tile) {
            // Apply blend mode for better integration with base map
            return ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.2),
                BlendMode.dstIn,
              ),
              child: widget,
            );
          },
        ),
      ),
    );
  }
}

/// Terrain tile generation specifications:
/// 
/// The terrain tiles are generated using GDAL with the following process:
/// 
/// 1. **Hillshading**: 
///    - Altitude: 45° (sun angle)
///    - Z-factor: 2 (vertical exaggeration)
///    - Multidirectional for better relief
/// 
/// 2. **Hypsometric Tinting** (elevation-based colors):
///    - Below sea level: Blue tones
///    - 0-500m: Green (lowlands)
///    - 500-1500m: Yellow-brown (hills)
///    - 1500-3000m: Brown (mountains)
///    - Above 3000m: White (snow)
/// 
/// 3. **Optimization**:
///    - Skip tiles that are all water (no elevation)
///    - Single zoom level (10) with client scaling
///    - 1024x1024 pixel tiles (reduced HTTP requests)
///    - PNG format with compression
///    - Maximum 3 concurrent downloads
/// 
/// 4. **Swiss-style Relief**:
///    - Combines hillshade (70%) with color relief (30%)
///    - Creates beautiful 3D appearance
///    - Based on swisstopo cartographic techniques