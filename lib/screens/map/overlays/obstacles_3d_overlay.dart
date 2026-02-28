import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:async';
import '../../../models/obstacle.dart';

/// 3D Obstacles overlay that renders obstacles with height when map is tilted
class Obstacles3DOverlay extends StatefulWidget {
  final List<Obstacle> obstacles;
  final double mapTilt;
  final Function(Obstacle)? onObstacleTap;
  final double currentAltitude;
  final MapController mapController;

  const Obstacles3DOverlay({
    super.key,
    required this.obstacles,
    required this.mapTilt,
    required this.mapController,
    this.onObstacleTap,
    this.currentAltitude = 0,
  });

  @override
  State<Obstacles3DOverlay> createState() => _Obstacles3DOverlayState();
}

class _Obstacles3DOverlayState extends State<Obstacles3DOverlay> {
  List<Obstacle> _cachedObstacles = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateObstacles();
  }

  @override
  void didUpdateWidget(Obstacles3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if obstacles list has changed
    if (widget.obstacles != oldWidget.obstacles) {
      // Debounce updates to avoid too frequent rerendering
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 200), () {
        _updateObstacles();
      });
    }
  }

  void _updateObstacles() {
    if (mounted) {
      setState(() {
        _cachedObstacles = widget.obstacles;
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedObstacles.isEmpty || widget.mapTilt < 5) {
      return const SizedBox.shrink();
    }

    final mapCamera = widget.mapController.camera;

    return RepaintBoundary(
      child: CustomPaint(
        painter: Obstacles3DPainter(
          obstacles: _cachedObstacles,
          mapCamera: mapCamera,
          mapTilt: widget.mapTilt,
          currentAltitude: widget.currentAltitude,
          onObstacleTap: widget.onObstacleTap,
        ),
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

class Obstacles3DPainter extends CustomPainter {
  final List<Obstacle> obstacles;
  final MapCamera mapCamera;
  final double mapTilt;
  final double currentAltitude;
  final Function(Obstacle)? onObstacleTap;

  Obstacles3DPainter({
    required this.obstacles,
    required this.mapCamera,
    required this.mapTilt,
    required this.currentAltitude,
    this.onObstacleTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (obstacles.isEmpty || size.isEmpty) return;

    canvas.save();
    
    try {
      // Filter obstacles that intersect with visible bounds
      final visibleBounds = mapCamera.visibleBounds;
      final visibleObstacles = <Obstacle>[];
      
      for (final obstacle in obstacles) {
        // Check if obstacle is within visible bounds
        if (obstacle.position.latitude >= visibleBounds.south &&
            obstacle.position.latitude <= visibleBounds.north &&
            obstacle.position.longitude >= visibleBounds.west &&
            obstacle.position.longitude <= visibleBounds.east) {
          visibleObstacles.add(obstacle);
        }
      }
      
      // Sort obstacles by latitude for proper depth rendering in 3D view
      // Northern (farther) obstacles should be drawn first
      visibleObstacles.sort((a, b) {
        return b.position.latitude.compareTo(a.position.latitude);
      });

      // Draw all visible obstacles
      for (final obstacle in visibleObstacles) {
        try {
          _drawObstacle3D(canvas, size, obstacle);
        } catch (e) {
          // Skip obstacle if rendering fails
          continue;
        }
      }
    } finally {
      canvas.restore();
    }
  }


  void _drawObstacle3D(Canvas canvas, Size size, Obstacle obstacle) {
    // Get screen position at ground level
    final screenPoint = _latLngToScreen(obstacle.position, size, 0);
    
    // Get obstacle height
    final heightFt = obstacle.elevationFt ?? 0;
    
    // Get top point position with altitude
    final topPoint = _latLngToScreen(obstacle.position, size, heightFt.toDouble());
    
    // Calculate if obstacle has visible height
    final hasVisibleHeight = (screenPoint.dy - topPoint.dy).abs() > 2;
    
    // Determine color based on danger level
    final isDangerous = currentAltitude > 0 && 
                       currentAltitude < heightFt + 500; // 500ft safety margin
    
    Color obstacleColor;
    if (obstacle.type?.toLowerCase().contains('wind') == true) {
      obstacleColor = Colors.green;
    } else if (isDangerous) {
      obstacleColor = Colors.red;
    } else if (obstacle.lighted == true) {
      obstacleColor = Colors.orange;
    } else {
      obstacleColor = Colors.grey;
    }
    
    // Draw obstacle as a vertical line/tower
    if (hasVisibleHeight) {
      
      // Draw shadow for depth
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(screenPoint.dx + 2, screenPoint.dy + 2),
        Offset(topPoint.dx + 2, topPoint.dy + 2),
        shadowPaint,
      );
      
      // Draw main obstacle line
      final obstaclePaint = Paint()
        ..color = obstacleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(screenPoint, topPoint, obstaclePaint);
      
      // Draw flashing light at top if lit
      if (obstacle.lighted == true) {
        final lightPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        
        // Outer glow
        final glowPaint = Paint()
          ..color = Colors.orange.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(topPoint, 6, glowPaint);
        canvas.drawCircle(topPoint, 3, lightPaint);
      }
      
      // Draw base circle
      final basePaint = Paint()
        ..color = obstacleColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 4, basePaint);
      
      // Draw height label when zoomed in
      if (mapCamera.zoom > 12 && hasVisibleHeight) {
        _drawHeightLabel(canvas, topPoint, heightFt.round());
      }
    } else {
      // Just draw a marker when height is too small
      final markerPaint = Paint()
        ..color = obstacleColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 3, markerPaint);
    }
    
    // Draw warning circle if dangerous
    if (isDangerous) {
      final warningPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 20, warningPaint);
      
      final warningBorderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(screenPoint, 20, warningBorderPaint);
    }
  }
  
  void _drawHeightLabel(Canvas canvas, Offset position, int heightFt) {
    final textSpan = TextSpan(
      text: '${heightFt}ft',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 2,
          ),
        ],
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height - 5,
      ),
    );
  }
  
  Offset _latLngToScreen(LatLng latLng, Size size, [double altitudeFt = 0]) {
    try {
      // Use flutter_map's built-in projection
      final point = mapCamera.projectAtZoom(latLng, mapCamera.zoom);
      final centerPoint = mapCamera.projectAtZoom(mapCamera.center, mapCamera.zoom);
      
      // Calculate offset from center in pixels
      final dx = point.dx - centerPoint.dx;
      final dy = point.dy - centerPoint.dy;
      
      // Check for invalid values
      if (!dx.isFinite || !dy.isFinite) {
        return Offset(size.width / 2, size.height / 2);
      }
      
      // Calculate altitude offset for 3D effect
      if (altitudeFt > 0) {
        final tiltRadians = mapTilt * math.pi / 180;
        final perspectiveFactor = 1.0 + math.sin(tiltRadians) * 1.5;
        final zoomFactor = math.pow(2.0, (mapCamera.zoom - 10) / 4).clamp(0.5, 2.0);
        final altitudeOffset = (altitudeFt / 1000.0) * 15 * zoomFactor * perspectiveFactor;
        
        // Return position relative to screen center
        // Subtract altitude offset to move UP on screen (negative Y is up)
        return Offset(
          size.width / 2 + dx,
          size.height / 2 + dy - altitudeOffset,
        );
      }
      
      return Offset(
        size.width / 2 + dx,
        size.height / 2 + dy,
      );
    } catch (e) {
      // Return center if calculation fails
      return Offset(size.width / 2, size.height / 2);
    }
  }

  @override
  bool shouldRepaint(Obstacles3DPainter oldDelegate) {
    return oldDelegate.obstacles != obstacles ||
           oldDelegate.mapTilt != mapTilt ||
           oldDelegate.currentAltitude != currentAltitude ||
           oldDelegate.mapCamera != mapCamera;
  }
}