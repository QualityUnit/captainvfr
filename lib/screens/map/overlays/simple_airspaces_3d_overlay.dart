import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../../../models/airspace.dart';
import '../../../services/spatial_airspace_service.dart';
import '../../../utils/airspace_utils.dart';

/// Simple and clear 3D Airspace overlay
class SimpleAirspaces3DOverlay extends StatefulWidget {
  final SpatialAirspaceService spatialService;
  final bool showAirspacesLayer;
  final Function(Airspace) onAirspaceTap;
  final double currentAltitude;
  final double mapTilt;
  final MapController mapController;
  final Set<int>? typeFilter;

  const SimpleAirspaces3DOverlay({
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
  State<SimpleAirspaces3DOverlay> createState() => _SimpleAirspaces3DOverlayState();
}

class _SimpleAirspaces3DOverlayState extends State<SimpleAirspaces3DOverlay> {
  List<Airspace> _cachedAirspaces = [];
  LatLngBounds? _lastBounds;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadAirspaces();
  }

  @override
  void didUpdateWidget(SimpleAirspaces3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Increase debounce time to reduce updates
    final currentBounds = widget.mapController.camera.visibleBounds;
    if (_lastBounds == null || _boundsChanged(currentBounds, _lastBounds!)) {
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 500), () {
        _loadAirspaces();
      });
    }
  }

  bool _boundsChanged(LatLngBounds a, LatLngBounds b) {
    // Increase threshold to reduce sensitivity
    const threshold = 0.02;
    return (a.north - b.north).abs() > threshold ||
           (a.south - b.south).abs() > threshold ||
           (a.east - b.east).abs() > threshold ||
           (a.west - b.west).abs() > threshold;
  }

  Future<void> _loadAirspaces() async {
    try {
      final bounds = widget.mapController.camera.visibleBounds;
      _lastBounds = bounds;
      
      // Use visible bounds directly - no expansion needed
      final allAirspaces = await widget.spatialService.getAirspacesInBounds(
        bounds,
        typeFilter: widget.typeFilter,
      );
      
      if (mounted) {
        setState(() {
          _cachedAirspaces = allAirspaces;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading airspaces: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAirspacesLayer || widget.mapTilt < 5 || _cachedAirspaces.isEmpty) {
      return const SizedBox.shrink();
    }

    debugPrint('✅ Building CustomPaint with ${_cachedAirspaces.length} airspaces');
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: SimpleAirspace3DPainter(
              airspaces: _cachedAirspaces,
              mapCamera: widget.mapController.camera,
              mapTilt: widget.mapTilt,
              currentAltitude: widget.currentAltitude,
            ),
            isComplex: true,
            willChange: false,
          );
        },
      ),
    );
  }
}

class SimpleAirspace3DPainter extends CustomPainter {
  final List<Airspace> airspaces;
  final MapCamera mapCamera;
  final double mapTilt;
  final double currentAltitude;

  SimpleAirspace3DPainter({
    required this.airspaces,
    required this.mapCamera,
    required this.mapTilt,
    required this.currentAltitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('🎨 SimpleAirspaces3DPainter.paint called with ${airspaces.length} airspaces');
    if (airspaces.isEmpty || size.isEmpty) {
      debugPrint('⚠️ Skipping paint: airspaces=${airspaces.length}, size=$size');
      return;
    }
    
    // Save canvas state to prevent corruption
    canvas.save();
    
    try {
      // Get visible bounds with extra buffer to ensure partially visible airspaces are included
      final visibleBounds = mapCamera.visibleBounds;
      
      // Expand bounds by 50% on each side to ensure we don't miss airspaces
      // that are partially visible or just outside the view
      final latDiff = (visibleBounds.north - visibleBounds.south) * 0.5;
      final lngDiff = (visibleBounds.east - visibleBounds.west) * 0.5;
      
      final expandedBounds = LatLngBounds(
        LatLng(
          math.max(-90.0, visibleBounds.south - latDiff),
          math.max(-180.0, visibleBounds.west - lngDiff),
        ),
        LatLng(
          math.min(90.0, visibleBounds.north + latDiff),
          math.min(180.0, visibleBounds.east + lngDiff),
        ),
      );
      
      final visibleAirspaces = <Airspace>[];
      
      for (final airspace in airspaces) {
        if (airspace.geometry.isEmpty) continue;
        
        // Check if airspace intersects with expanded bounds
        // This ensures we render all airspaces that might be partially visible
        if (_airspaceIntersectsBounds(airspace.geometry, expandedBounds)) {
          visibleAirspaces.add(airspace);
        }
      }
      
      final airspacesToRender = visibleAirspaces;
      debugPrint('📊 Filtered to ${airspacesToRender.length} visible airspaces from ${airspaces.length} total');
    
    // Sort airspaces by distance from viewer (far to near)
    final sortedAirspaces = List<Airspace>.from(airspacesToRender)
      ..sort((a, b) {
        // Calculate center latitude for each airspace
        double aLat = 0, bLat = 0;
        
        if (a.geometry.isNotEmpty) {
          for (final point in a.geometry) {
            aLat += point.latitude;
          }
          aLat /= a.geometry.length;
        }
        
        if (b.geometry.isNotEmpty) {
          for (final point in b.geometry) {
            bLat += point.latitude;
          }
          bLat /= b.geometry.length;
        }
        
        // Draw far (north) airspaces first
        return bLat.compareTo(aLat);
      });

      // Draw each airspace with error handling
      for (final airspace in sortedAirspaces) {
        try {
          _drawSimpleAirspace3D(canvas, size, airspace);
        } catch (e) {
          // Skip this airspace if rendering fails
          continue;
        }
      }
    } finally {
      // Always restore canvas state
      canvas.restore();
    }
  }

  void _drawSimpleAirspace3D(Canvas canvas, Size size, Airspace airspace) {
    if (airspace.geometry.isEmpty) return;
    

    // Limit geometry points for complex airspaces
    final geometryPoints = airspace.geometry.length > 100
        ? _simplifyGeometry(airspace.geometry, 100)
        : airspace.geometry;

    // Get airspace altitude limits in feet
    final lowerLimitFt = airspace.lowerLimitFt ?? 0;
    final upperLimitFt = airspace.upperLimitFt ?? 60000;
    
    // Get base color for this airspace type
    final baseColor = AirspaceUtils.getAirspaceColorByString(
      airspace.type,
      airspace.icaoClass,
    );
    
    // Check if current altitude is inside this airspace
    final isInside = currentAltitude >= lowerLimitFt && 
                     currentAltitude <= upperLimitFt;
    
    // Convert airspace boundary to screen coordinates
    final screenPoints = <Offset>[];
    bool hasVisiblePoints = false;
    
    for (final point in geometryPoints) {
      final screenPoint = _latLngToScreen(point, size);
      
      // Skip invalid points
      if (!screenPoint.dx.isFinite || !screenPoint.dy.isFinite) continue;
      
      screenPoints.add(screenPoint);
      
      // Check if any point is visible on screen
      if (screenPoint.dx >= -100 && screenPoint.dx <= size.width + 100 &&
          screenPoint.dy >= -100 && screenPoint.dy <= size.height + 100) {
        hasVisiblePoints = true;
      }
    }
    
    // Skip if no points are visible or too few points
    if (!hasVisiblePoints || screenPoints.length < 3) return;
    
    // Calculate 3D height in pixels based on altitude difference
    // Height should be consistent - not affected by tilt to prevent triangular convergence
    final zoomFactor = math.pow(2.0, (mapCamera.zoom - 10) / 4).clamp(0.5, 2.0);
    final altitudeDiffKft = (upperLimitFt - lowerLimitFt) / 1000; // thousands of feet
    
    // Fixed height calculation - same regardless of tilt angle
    // This prevents the triangular convergence effect
    final pixelHeight = altitudeDiffKft * 20 * zoomFactor;
    
    
    // Always draw 3D effect for all airspaces
    // Draw with clear boundaries and reduced opacity for less clutter
    if (true) {
      // Draw side walls with low opacity to reduce visual clutter
      final wallPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.15)  // Very transparent walls
        ..style = PaintingStyle.fill;
      
      final wallBorderPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.6)  // Visible borders
        ..strokeWidth = 2.0  // Thick borders for clarity
        ..style = PaintingStyle.stroke;
      
      // Draw only corner walls to reduce clutter (every 4th wall)
      final step = math.max(1, screenPoints.length ~/ 8);
      for (int i = 0; i < screenPoints.length; i += step) {
        final nextI = (i + 1) % screenPoints.length;
        final bottomPoint1 = screenPoints[i];
        final bottomPoint2 = screenPoints[nextI];
        
        final topPoint1 = Offset(bottomPoint1.dx, bottomPoint1.dy - pixelHeight);
        final topPoint2 = Offset(bottomPoint2.dx, bottomPoint2.dy - pixelHeight);
        
        final wallPath = ui.Path()
          ..moveTo(bottomPoint1.dx, bottomPoint1.dy)
          ..lineTo(bottomPoint2.dx, bottomPoint2.dy)
          ..lineTo(topPoint2.dx, topPoint2.dy)
          ..lineTo(topPoint1.dx, topPoint1.dy)
          ..close();
        
        // Draw wall fill
        canvas.drawPath(wallPath, wallPaint);
        canvas.drawPath(wallPath, wallPaint);
        canvas.drawPath(wallPath, wallBorderPaint);
      }
      
      // Draw top outline with clear boundary
      final topPath = ui.Path();
      for (int i = 0; i < screenPoints.length; i++) {
        final topPoint = Offset(
          screenPoints[i].dx,
          screenPoints[i].dy - pixelHeight,
        );
        
        if (i == 0) {
          topPath.moveTo(topPoint.dx, topPoint.dy);
        } else {
          topPath.lineTo(topPoint.dx, topPoint.dy);
        }
      }
      topPath.close();
      
      // Draw top surface with low opacity
      final topAlpha = isInside ? 0.25 : 0.15;
      final topFillPaint = Paint()
        ..color = baseColor.withValues(alpha: topAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(topPath, topFillPaint);
      
      // Draw top border - this is the key visual element
      final topBorderPaint = Paint()
        ..color = baseColor.withValues(alpha: isInside ? 0.9 : 0.7)
        ..strokeWidth = isInside ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(topPath, topBorderPaint);
    }
    
    // Draw bottom outline
    final bottomPath = ui.Path();
    for (int i = 0; i < screenPoints.length; i++) {
      if (i == 0) {
        bottomPath.moveTo(screenPoints[i].dx, screenPoints[i].dy);
      } else {
        bottomPath.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      }
    }
    bottomPath.close();
    
    // Draw bottom with minimal opacity
    final bottomAlpha = 0.1;
    final bottomFillPaint = Paint()
      ..color = baseColor.withValues(alpha: bottomAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPath, bottomFillPaint);
    
    // Draw bottom border with reduced opacity
    final bottomBorderPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.5)
      ..strokeWidth = isInside ? 2.0 : 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bottomPath, bottomBorderPaint);
    
    // Draw altitude label only if zoomed in and airspace is significant
    if (mapCamera.zoom > 11 && pixelHeight > 30) {
      _drawAltitudeLabel(canvas, size, airspace, screenPoints, pixelHeight);
    }
  }
  
  void _drawAltitudeLabel(
    Canvas canvas, 
    Size size, 
    Airspace airspace, 
    List<Offset> screenPoints,
    double pixelHeight,
  ) {
    // Calculate center of airspace
    double centerX = 0, centerY = 0;
    for (final point in screenPoints) {
      centerX += point.dx;
      centerY += point.dy;
    }
    centerX /= screenPoints.length;
    centerY = centerY / screenPoints.length - pixelHeight / 2;
    
    // Create altitude text
    final upperText = airspace.upperLimitFt != null 
      ? airspace.upperLimitFt! >= 18000
        ? 'FL${(airspace.upperLimitFt! / 100).round()}'
        : '${airspace.upperLimitFt}ft'
      : 'UNL';
    
    final lowerText = airspace.lowerLimitFt != null 
      ? airspace.lowerLimitFt == 0 
        ? 'GND' 
        : airspace.lowerLimitFt! >= 18000
          ? 'FL${(airspace.lowerLimitFt! / 100).round()}'
          : '${airspace.lowerLimitFt}ft'
      : 'GND';
    
    // Draw background box
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    
    final textPaint = TextPainter(
      text: TextSpan(
        text: '$lowerText-$upperText',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPaint.layout();
    
    // Draw background
    final padding = 4.0;
    final bgRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: textPaint.width + padding * 2,
      height: textPaint.height + padding * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      bgPaint,
    );
    
    // Draw text
    textPaint.paint(
      canvas,
      Offset(
        centerX - textPaint.width / 2,
        centerY - textPaint.height / 2,
      ),
    );
  }
  
  Offset _latLngToScreen(LatLng latLng, Size size) {
    try {
      // Use the camera's project method
      final point = mapCamera.projectAtZoom(latLng, mapCamera.zoom);
      final centerPoint = mapCamera.projectAtZoom(mapCamera.center, mapCamera.zoom);
      
      // Calculate offset from center in pixels
      final dx = point.dx - centerPoint.dx;
      final dy = point.dy - centerPoint.dy;
      
      // Check for invalid values
      if (!dx.isFinite || !dy.isFinite) {
        return Offset(size.width / 2, size.height / 2);
      }
      
      // Return position relative to screen center
      // No clamping to allow off-screen rendering for partial visibility
      return Offset(
        size.width / 2 + dx,
        size.height / 2 + dy,
      );
    } catch (e) {
      // Return center on any error
      return Offset(size.width / 2, size.height / 2);
    }
  }


  // Check if airspace polygon intersects with map bounds
  bool _airspaceIntersectsBounds(List<LatLng> geometry, LatLngBounds bounds) {
    if (geometry.isEmpty) return false;
    
    // First check if any point is inside bounds
    for (final point in geometry) {
      if (point.latitude >= bounds.south && 
          point.latitude <= bounds.north &&
          point.longitude >= bounds.west && 
          point.longitude <= bounds.east) {
        return true;
      }
    }
    
    // Check if airspace bounds intersect with map bounds
    double minLat = geometry[0].latitude;
    double maxLat = geometry[0].latitude;
    double minLng = geometry[0].longitude;
    double maxLng = geometry[0].longitude;
    
    for (final point in geometry) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    // Check if bounding boxes intersect
    return !(maxLat < bounds.south || 
             minLat > bounds.north || 
             maxLng < bounds.west || 
             minLng > bounds.east);
  }
  
  // Simplify geometry by taking every nth point
  List<LatLng> _simplifyGeometry(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    
    final simplified = <LatLng>[];
    final step = points.length / maxPoints;
    
    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).round();
      if (index < points.length) {
        simplified.add(points[index]);
      }
    }
    
    return simplified;
  }

  @override
  bool shouldRepaint(SimpleAirspace3DPainter oldDelegate) {
    return oldDelegate.airspaces != airspaces ||
           oldDelegate.mapTilt != mapTilt ||
           oldDelegate.currentAltitude != currentAltitude ||
           oldDelegate.mapCamera != mapCamera;
  }
}