import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;

/// Map overlay indicators showing zoom level, scale bar, and north arrow
/// Safely handles map initialization by checking camera availability
class MapOverlayIndicators extends StatelessWidget {
  final MapCamera? camera;
  
  const MapOverlayIndicators({
    super.key,
    this.camera,
  });

  @override
  Widget build(BuildContext context) {
    // Don't render if camera is not yet initialized
    if (camera == null) {
      return const SizedBox.shrink();
    }
    
    return Stack(
      children: [
        // North arrow - top left
        Positioned(
          top: 16,
          left: 16,
          child: NorthArrowIndicator(rotation: camera!.rotation),
        ),
        
        // Zoom level - bottom left
        Positioned(
          bottom: 80,
          left: 16,
          child: ZoomLevelIndicator(zoom: camera!.zoom),
        ),
        
        // Scale bar - bottom center
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: ScaleBarIndicator(
              zoom: camera!.zoom,
              latitude: camera!.center.latitude,
            ),
          ),
        ),
      ],
    );
  }
}

/// North arrow indicator showing map orientation
class NorthArrowIndicator extends StatelessWidget {
  final double rotation;
  
  const NorthArrowIndicator({
    super.key,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Transform.rotate(
        angle: -rotation * math.pi / 180,
        child: const Icon(
          Icons.navigation,
          color: Colors.red,
          size: 32,
        ),
      ),
    );
  }
}

/// Zoom level indicator
class ZoomLevelIndicator extends StatelessWidget {
  final double zoom;
  
  const ZoomLevelIndicator({
    super.key,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.zoom_in,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Z${zoom.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scale bar showing distance
class ScaleBarIndicator extends StatelessWidget {
  final double zoom;
  final double latitude;
  
  const ScaleBarIndicator({
    super.key,
    required this.zoom,
    required this.latitude,
  });

  @override
  Widget build(BuildContext context) {
    final scale = _calculateScale();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scale bar
          Container(
            width: scale.barWidth,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          // Scale text
          Text(
            scale.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  _ScaleInfo _calculateScale() {
    // Calculate meters per pixel at this zoom level and latitude
    final metersPerPixel = 156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    
    // Find appropriate scale (1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, etc.)
    final scales = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000];
    
    // Target bar width in pixels
    const targetWidth = 100.0;
    
    // Find best scale
    double bestScale = scales[0].toDouble();
    for (final scale in scales) {
      final pixelWidth = scale / metersPerPixel;
      if (pixelWidth >= targetWidth * 0.5 && pixelWidth <= targetWidth * 1.5) {
        bestScale = scale.toDouble();
        break;
      }
    }
    
    final barWidth = bestScale / metersPerPixel;
    final label = _formatDistance(bestScale);
    
    return _ScaleInfo(barWidth: barWidth, label: label);
  }
  
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    } else {
      return '${meters.toInt()} m';
    }
  }
}

class _ScaleInfo {
  final double barWidth;
  final String label;
  
  _ScaleInfo({required this.barWidth, required this.label});
}
