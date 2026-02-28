import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../../../models/airspace.dart';
import '../../../services/spatial_airspace_service.dart';
import '../../../utils/airspace_utils.dart';

/// 3D Airspace overlay that renders airspaces with height when map is tilted
class Airspaces3DOverlay extends StatefulWidget {
  final SpatialAirspaceService spatialService;
  final bool showAirspacesLayer;
  final Function(Airspace) onAirspaceTap;
  final double currentAltitude;
  final double mapTilt; // Tilt angle in degrees (0 = flat, 60 = max tilt)
  final Set<int>? typeFilter;
  final MapController mapController;

  const Airspaces3DOverlay({
    super.key,
    required this.spatialService,
    required this.showAirspacesLayer,
    required this.onAirspaceTap,
    required this.mapTilt,
    required this.mapController,
    this.currentAltitude = 0,
    this.typeFilter,
  });

  @override
  State<Airspaces3DOverlay> createState() => _Airspaces3DOverlayState();
}

class _Airspaces3DOverlayState extends State<Airspaces3DOverlay> {
  List<Airspace> _cachedAirspaces = [];
  LatLngBounds? _lastBounds;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadAirspaces();
  }

  @override
  void didUpdateWidget(Airspaces3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if map has moved significantly
    final currentBounds = widget.mapController.camera.visibleBounds;
    if (_lastBounds == null || _boundsChanged(currentBounds, _lastBounds!)) {
      // Debounce updates to avoid too frequent reloading
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 300), () {
        _loadAirspaces();
      });
    }
  }

  bool _boundsChanged(LatLngBounds a, LatLngBounds b) {
    const threshold = 0.01; // About 1km
    return (a.north - b.north).abs() > threshold ||
           (a.south - b.south).abs() > threshold ||
           (a.east - b.east).abs() > threshold ||
           (a.west - b.west).abs() > threshold;
  }

  Future<void> _loadAirspaces() async {
    try {
      final bounds = widget.mapController.camera.visibleBounds;
      _lastBounds = bounds;
      
      final airspaces = await widget.spatialService.getAirspacesInBounds(
        bounds,
        currentAltitude: widget.currentAltitude,
        typeFilter: widget.typeFilter,
      );
      
      if (mounted) {
        setState(() {
          _cachedAirspaces = airspaces;
        });
      }
    } catch (e) {
      // Error loading airspaces: $e
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAirspacesLayer || widget.mapTilt == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: Airspace3DPainter(
            airspaces: _cachedAirspaces,
            mapCamera: widget.mapController.camera,
            mapTilt: widget.mapTilt,
            currentAltitude: widget.currentAltitude,
            onAirspaceTap: widget.onAirspaceTap,
          ),
        );
      },
    );
  }
}

class Airspace3DPainter extends CustomPainter {
  final List<Airspace> airspaces;
  final MapCamera mapCamera;
  final double mapTilt;
  final double currentAltitude;
  final Function(Airspace) onAirspaceTap;

  Airspace3DPainter({
    required this.airspaces,
    required this.mapCamera,
    required this.mapTilt,
    required this.currentAltitude,
    required this.onAirspaceTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Sort airspaces by distance from viewer for proper depth ordering
    // In 3D view, closer (southern) airspaces should be drawn last
    final sortedAirspaces = List<Airspace>.from(airspaces)
      ..sort((a, b) {
        // Calculate average latitude (Y position) for each airspace
        double aAvgLat = 0;
        double bAvgLat = 0;
        
        if (a.geometry.isNotEmpty) {
          for (final point in a.geometry) {
            aAvgLat += point.latitude;
          }
          aAvgLat /= a.geometry.length;
        }
        
        if (b.geometry.isNotEmpty) {
          for (final point in b.geometry) {
            bAvgLat += point.latitude;
          }
          bAvgLat /= b.geometry.length;
        }
        
        // Draw northern (farther) airspaces first
        return bAvgLat.compareTo(aAvgLat);
      });

    // Draw all airspaces from back to front
    for (final airspace in sortedAirspaces) {
      _drawAirspace3D(canvas, size, airspace);
    }
  }

  void _drawAirspace3D(Canvas canvas, Size size, Airspace airspace) {
    if (airspace.geometry.isEmpty) return;

    // Get airspace altitude limits
    final lowerLimit = airspace.lowerLimitFt ?? 0;
    final upperLimit = airspace.upperLimitFt ?? 60000;
    
    // Calculate height factor based on tilt (used for future enhancements)
    // final tiltRadians = mapTilt * math.pi / 180;
    // final heightFactor = math.sin(tiltRadians);
    
    // Scale height based on zoom level (used for future enhancements)
    // final zoomScale = math.pow(2.0, (mapCamera.zoom - 10) / 4).clamp(0.5, 3.0);
    
    // Get airspace color - use string-based method
    final baseColor = AirspaceUtils.getAirspaceColorByString(
      airspace.type,
      airspace.icaoClass,
    );
    
    // Check if current altitude is within this airspace
    final isInside = currentAltitude >= lowerLimit && currentAltitude <= upperLimit;
    
    // Create paths for bottom and top polygons
    final bottomPath = ui.Path();
    final topPath = ui.Path();
    
    // Convert lat/lng to screen coordinates for bottom and top
    final bottomPoints = <Offset>[];
    final topPoints = <Offset>[];
    bool hasValidPoints = false;
    
    for (int i = 0; i < airspace.geometry.length; i++) {
      final point = airspace.geometry[i];
      
      // Calculate bottom point (at lower altitude)
      final bottomScreenPoint = _latLngToScreen(point, size, lowerLimit);
      
      // Calculate top point (at upper altitude)
      final topScreenPoint = _latLngToScreen(point, size, upperLimit);
      
      // Check if point is within reasonable bounds
      if (bottomScreenPoint.dx >= -size.width && bottomScreenPoint.dx <= size.width * 2 &&
          bottomScreenPoint.dy >= -size.height && bottomScreenPoint.dy <= size.height * 2) {
        hasValidPoints = true;
      }
      
      bottomPoints.add(bottomScreenPoint);
      topPoints.add(topScreenPoint);
      
      // Build paths
      if (i == 0) {
        bottomPath.moveTo(bottomScreenPoint.dx, bottomScreenPoint.dy);
        topPath.moveTo(topScreenPoint.dx, topScreenPoint.dy);
      } else {
        bottomPath.lineTo(bottomScreenPoint.dx, bottomScreenPoint.dy);
        topPath.lineTo(topScreenPoint.dx, topScreenPoint.dy);
      }
    }
    
    bottomPath.close();
    topPath.close();
    
    // Only draw if we have valid points on screen
    if (!hasValidPoints) return;
    
    // Calculate if airspace has significant height
    // Top points should be above (smaller y) than bottom points
    final hasHeight = bottomPoints.isNotEmpty && topPoints.isNotEmpty && 
                      (bottomPoints[0].dy - topPoints[0].dy) > 2;
    
    // Draw side walls (connecting bottom to top) for 3D effect
    if (hasHeight) {
      // Separate walls into front-facing and back-facing based on winding order
      final frontWalls = <_WallSegment>[];
      final backWalls = <_WallSegment>[];
      
      for (int i = 0; i < bottomPoints.length; i++) {
        final nextI = (i + 1) % bottomPoints.length;
        
        // Skip walls that are completely off-screen
        if ((bottomPoints[i].dx < -size.width && bottomPoints[nextI].dx < -size.width) ||
            (bottomPoints[i].dx > size.width * 2 && bottomPoints[nextI].dx > size.width * 2)) {
          continue;
        }
        
        // Calculate wall normal to determine if it's front or back facing
        final wallVector = Offset(
          bottomPoints[nextI].dx - bottomPoints[i].dx,
          bottomPoints[nextI].dy - bottomPoints[i].dy,
        );
        
        // Cross product with view direction (pointing into screen)
        // Positive = front facing, negative = back facing
        final isFrontFacing = wallVector.dy > 0;
        
        final wallPath = ui.Path()
          ..moveTo(bottomPoints[i].dx, bottomPoints[i].dy)
          ..lineTo(topPoints[i].dx, topPoints[i].dy)
          ..lineTo(topPoints[nextI].dx, topPoints[nextI].dy)
          ..lineTo(bottomPoints[nextI].dx, bottomPoints[nextI].dy)
          ..close();
        
        final segment = _WallSegment(wallPath, isFrontFacing, i);
        
        if (isFrontFacing) {
          frontWalls.add(segment);
        } else {
          backWalls.add(segment);
        }
      }
      
      // Draw back-facing walls first (darker)
      for (final wall in backWalls) {
        final wallPaint = Paint()
          ..color = baseColor.withValues(alpha: isInside ? 0.1 : 0.05)
          ..style = PaintingStyle.fill;
        canvas.drawPath(wall.path, wallPaint);
      }
      
      // Draw front-facing walls (lighter)
      for (final wall in frontWalls) {
        final wallPaint = Paint()
          ..color = baseColor.withValues(alpha: isInside ? 0.25 : 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawPath(wall.path, wallPaint);
      }
    }
    
    // Draw bottom polygon (ground level or lower limit)
    final bottomPaint = Paint()
      ..color = baseColor.withValues(alpha: isInside ? 0.15 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPath, bottomPaint);
    
    // Draw top polygon (upper limit) with stronger color
    if (hasHeight) {
      final topPaint = Paint()
        ..color = baseColor.withValues(alpha: isInside ? 0.35 : 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawPath(topPath, topPaint);
      
      // Draw top border for clarity
      final topBorderPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isInside ? 2.0 : 1.5;
      canvas.drawPath(topPath, topBorderPaint);
    }
    
    // Draw bottom border
    final bottomBorderPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(bottomPath, bottomBorderPaint);
    
    // Draw altitude labels for significant airspaces when zoomed in
    if (mapCamera.zoom > 10 && hasHeight && topPoints.isNotEmpty) {
      _drawAltitudeLabel(canvas, size, airspace, topPoints);
    }
  }
  
  void _drawAltitudeLabel(Canvas canvas, Size size, Airspace airspace, List<Offset> topPoints) {
    if (topPoints.isEmpty) return;
    
    // Calculate center of top polygon
    double centerX = 0, centerY = 0;
    for (final point in topPoints) {
      centerX += point.dx;
      centerY += point.dy;
    }
    centerX /= topPoints.length;
    centerY /= topPoints.length;
    
    // Create altitude text
    final upperText = airspace.upperLimitFt != null 
      ? 'FL${(airspace.upperLimitFt! / 100).round()}' 
      : 'UNL';
    final lowerText = airspace.lowerLimitFt != null 
      ? airspace.lowerLimitFt == 0 
        ? 'GND' 
        : 'FL${(airspace.lowerLimitFt! / 100).round()}'
      : 'GND';
    
    final textSpan = TextSpan(
      text: '$upperText\n$lowerText',
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
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        centerY - textPainter.height / 2,
      ),
    );
  }
  
  Offset _latLngToScreen(LatLng latLng, Size size, [double altitudeFt = 0]) {
    try {
      // Use flutter_map's built-in projection
      final point = mapCamera.projectAtZoom(latLng);
      final centerPoint = mapCamera.projectAtZoom(mapCamera.center);
      
      // Calculate offset from center in pixels
      final dx = point.dx - centerPoint.dx;
      final dy = point.dy - centerPoint.dy;
      
      // Calculate altitude offset for 3D effect
      // Simulate ground-level perspective - height grows with tilt
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
    } catch (e) {
      // Return center if calculation fails
      return Offset(size.width / 2, size.height / 2);
    }
  }

  @override
  bool shouldRepaint(Airspace3DPainter oldDelegate) {
    return oldDelegate.airspaces != airspaces ||
           oldDelegate.mapTilt != mapTilt ||
           oldDelegate.currentAltitude != currentAltitude ||
           oldDelegate.mapCamera != mapCamera;
  }
}

// Helper class for wall segments
class _WallSegment {
  final ui.Path path;
  final bool isFrontFacing;
  final int index;
  
  _WallSegment(this.path, this.isFrontFacing, this.index);
}