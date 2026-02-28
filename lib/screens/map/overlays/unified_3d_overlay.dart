import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../models/airspace.dart';
import '../../../models/obstacle.dart';
import '../../../models/safesky_beacon.dart';
import '../../../services/spatial_airspace_service.dart';
import '../../../utils/airspace_utils.dart';

/// Unified 3D overlay that manages all 3D objects together for better performance
class Unified3DOverlay extends StatefulWidget {
  final SpatialAirspaceService? spatialService;
  final List<Obstacle> obstacles;
  final List<SafeSkyBeacon> beacons;
  final bool showAirspaces;
  final bool showObstacles;
  final bool showSafeSky;
  final double mapTilt;
  final double currentAltitude;
  final LatLng? currentPosition;
  final MapController mapController;
  final Function(Airspace)? onAirspaceTap;
  final Function(Obstacle)? onObstacleTap;
  final Function(SafeSkyBeacon)? onBeaconTap;
  final Set<int>? airspaceTypeFilter;

  const Unified3DOverlay({
    super.key,
    this.spatialService,
    required this.obstacles,
    required this.beacons,
    required this.showAirspaces,
    required this.showObstacles,
    required this.showSafeSky,
    required this.mapTilt,
    required this.mapController,
    this.currentAltitude = 0,
    this.currentPosition,
    this.onAirspaceTap,
    this.onObstacleTap,
    this.onBeaconTap,
    this.airspaceTypeFilter,
  });

  @override
  State<Unified3DOverlay> createState() => _Unified3DOverlayState();
}

class _Unified3DOverlayState extends State<Unified3DOverlay> {
  List<Airspace> _cachedAirspaces = [];
  LatLngBounds? _lastBounds;
  
  @override
  void initState() {
    super.initState();
    if (widget.showAirspaces && widget.spatialService != null) {
      _loadAirspaces();
    }
  }

  @override
  void didUpdateWidget(Unified3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.showAirspaces && widget.spatialService != null) {
      final currentBounds = widget.mapController.camera.visibleBounds;
      if (_lastBounds == null || _boundsChanged(currentBounds, _lastBounds!)) {
        _loadAirspaces();
      }
    }
  }

  bool _boundsChanged(LatLngBounds a, LatLngBounds b) {
    const threshold = 0.05; // More relaxed threshold
    return (a.north - b.north).abs() > threshold ||
           (a.south - b.south).abs() > threshold ||
           (a.east - b.east).abs() > threshold ||
           (a.west - b.west).abs() > threshold;
  }

  Future<void> _loadAirspaces() async {
    if (widget.spatialService == null) return;
    
    try {
      final bounds = widget.mapController.camera.visibleBounds;
      _lastBounds = bounds;
      
      final airspaces = await widget.spatialService!.getAirspacesInBounds(
        bounds,
        currentAltitude: widget.currentAltitude,
        typeFilter: widget.airspaceTypeFilter,
      );
      
      if (mounted) {
        setState(() {
          _cachedAirspaces = airspaces;
        });
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only render when tilted
    if (widget.mapTilt < 5) {
      return const SizedBox.shrink();
    }
    
    // Check if we have anything to render
    final hasContent = (widget.showAirspaces && _cachedAirspaces.isNotEmpty) ||
                      (widget.showObstacles && widget.obstacles.isNotEmpty) ||
                      (widget.showSafeSky && widget.beacons.isNotEmpty);
    
    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: Unified3DPainter(
              airspaces: widget.showAirspaces ? _cachedAirspaces : [],
              obstacles: widget.showObstacles ? widget.obstacles : [],
              beacons: widget.showSafeSky ? widget.beacons : [],
              mapCamera: widget.mapController.camera,
              mapTilt: widget.mapTilt,
              currentAltitude: widget.currentAltitude,
              currentPosition: widget.currentPosition,
            ),
            isComplex: true,
            willChange: false,
          );
        },
      ),
    );
  }
}

class Unified3DPainter extends CustomPainter {
  final List<Airspace> airspaces;
  final List<Obstacle> obstacles;
  final List<SafeSkyBeacon> beacons;
  final MapCamera mapCamera;
  final double mapTilt;
  final double currentAltitude;
  final LatLng? currentPosition;

  // Rendering limits per layer
  static const int maxAirspacesPerRender = 30;
  static const int maxObstaclesPerRender = 50;
  static const int maxBeaconsPerRender = 20;

  Unified3DPainter({
    required this.airspaces,
    required this.obstacles,
    required this.beacons,
    required this.mapCamera,
    required this.mapTilt,
    required this.currentAltitude,
    this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    // Save canvas state
    canvas.save();
    
    try {
      // Collect all renderable objects with their distances
      final renderQueue = <_RenderObject>[];
      
      // Add airspaces to render queue
      int airspaceCount = 0;
      for (final airspace in airspaces) {
        if (airspaceCount >= maxAirspacesPerRender) break;
        if (airspace.geometry.isEmpty) continue;
        
        final center = _calculateCenter(airspace.geometry);
        if (_isVisible(center, size)) {
          renderQueue.add(_RenderObject(
            type: _ObjectType.airspace,
            data: airspace,
            latitude: center.latitude,
          ));
          airspaceCount++;
        }
      }
      
      // Add obstacles to render queue
      int obstacleCount = 0;
      for (final obstacle in obstacles) {
        if (obstacleCount >= maxObstaclesPerRender) break;
        
        if (_isVisible(obstacle.position, size)) {
          renderQueue.add(_RenderObject(
            type: _ObjectType.obstacle,
            data: obstacle,
            latitude: obstacle.position.latitude,
          ));
          obstacleCount++;
        }
      }
      
      // Add beacons to render queue
      int beaconCount = 0;
      for (final beacon in beacons) {
        if (beaconCount >= maxBeaconsPerRender) break;
        
        final position = LatLng(beacon.latitude, beacon.longitude);
        if (_isVisible(position, size)) {
          renderQueue.add(_RenderObject(
            type: _ObjectType.beacon,
            data: beacon,
            latitude: beacon.latitude,
          ));
          beaconCount++;
        }
      }
      
      // Sort by latitude (far to near) for proper depth rendering
      renderQueue.sort((a, b) => b.latitude.compareTo(a.latitude));
      
      // Render all objects in correct order
      for (final obj in renderQueue) {
        try {
          switch (obj.type) {
            case _ObjectType.airspace:
              _drawAirspace3D(canvas, size, obj.data as Airspace);
              break;
            case _ObjectType.obstacle:
              _drawObstacle3D(canvas, size, obj.data as Obstacle);
              break;
            case _ObjectType.beacon:
              _drawBeacon3D(canvas, size, obj.data as SafeSkyBeacon);
              break;
          }
        } catch (e) {
          // Skip object if rendering fails
          continue;
        }
      }
    } finally {
      canvas.restore();
    }
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return LatLng(0, 0);
    
    double lat = 0, lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  bool _isVisible(LatLng point, Size size) {
    try {
      final screenPoint = _latLngToScreen(point, size);
      return screenPoint.dx >= -100 && screenPoint.dx <= size.width + 100 &&
             screenPoint.dy >= -100 && screenPoint.dy <= size.height + 100;
    } catch (e) {
      return false;
    }
  }

  void _drawAirspace3D(Canvas canvas, Size size, Airspace airspace) {
    if (airspace.geometry.isEmpty) return;
    
    // Simplify geometry if too complex
    final points = airspace.geometry.length > 30 
        ? _simplifyGeometry(airspace.geometry, 30)
        : airspace.geometry;
    
    final lowerLimitFt = airspace.lowerLimitFt ?? 0;
    final upperLimitFt = airspace.upperLimitFt ?? 60000;
    
    if (upperLimitFt <= 0 || lowerLimitFt > 50000) return;
    
    final baseColor = AirspaceUtils.getAirspaceColorByString(
      airspace.type,
      airspace.icaoClass,
    );
    
    final isInside = currentAltitude >= lowerLimitFt && 
                     currentAltitude <= upperLimitFt;
    
    // Convert to screen coordinates
    final screenPoints = <Offset>[];
    for (final point in points) {
      final sp = _latLngToScreen(point, size);
      if (sp.dx.isFinite && sp.dy.isFinite) {
        screenPoints.add(sp);
      }
    }
    
    if (screenPoints.length < 3) return;
    
    // Calculate height
    final altitudeDiffKft = (upperLimitFt - lowerLimitFt) / 1000;
    final tiltRadians = mapTilt * math.pi / 180;
    final perspectiveFactor = 1.0 + math.sin(tiltRadians) * 1.2;
    final zoomFactor = math.pow(2.0, (mapCamera.zoom - 10) / 4).clamp(0.5, 2.0);
    final pixelHeight = altitudeDiffKft * 12 * zoomFactor * perspectiveFactor;
    
    if (pixelHeight > 3) {
      // Draw vertical lines (very subtle)
      final linePaint = Paint()
        ..color = baseColor.withValues(alpha: 0.15)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      
      // Draw only corner lines
      final cornerIndices = [0, screenPoints.length ~/ 3, 2 * screenPoints.length ~/ 3];
      for (final i in cornerIndices) {
        if (i < screenPoints.length) {
          canvas.drawLine(
            screenPoints[i],
            Offset(screenPoints[i].dx, screenPoints[i].dy - pixelHeight),
            linePaint,
          );
        }
      }
      
      // Draw top surface
      final topPath = ui.Path();
      for (int i = 0; i < screenPoints.length; i++) {
        final topPoint = Offset(screenPoints[i].dx, screenPoints[i].dy - pixelHeight);
        if (i == 0) {
          topPath.moveTo(topPoint.dx, topPoint.dy);
        } else {
          topPath.lineTo(topPoint.dx, topPoint.dy);
        }
      }
      topPath.close();
      
      final topFillPaint = Paint()
        ..color = baseColor.withValues(alpha: isInside ? 0.3 : 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawPath(topPath, topFillPaint);
      
      final topBorderPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.6)
        ..strokeWidth = isInside ? 2.0 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(topPath, topBorderPaint);
    }
    
    // Draw bottom surface
    final bottomPath = ui.Path();
    for (int i = 0; i < screenPoints.length; i++) {
      if (i == 0) {
        bottomPath.moveTo(screenPoints[i].dx, screenPoints[i].dy);
      } else {
        bottomPath.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      }
    }
    bottomPath.close();
    
    final bottomFillPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPath, bottomFillPaint);
    
    final bottomBorderPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bottomPath, bottomBorderPaint);
  }

  void _drawObstacle3D(Canvas canvas, Size size, Obstacle obstacle) {
    final screenPoint = _latLngToScreen(obstacle.position, size);
    if (!screenPoint.dx.isFinite || !screenPoint.dy.isFinite) return;
    
    final heightFt = obstacle.elevationFt ?? 0;
    if (heightFt <= 0) return;
    
    final topPoint = _latLngToScreen(obstacle.position, size, heightFt.toDouble());
    if (!topPoint.dx.isFinite || !topPoint.dy.isFinite) return;
    
    final hasVisibleHeight = (screenPoint.dy - topPoint.dy).abs() > 2;
    
    final isDangerous = currentAltitude > 0 && 
                       currentAltitude < heightFt + 500;
    
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
    
    if (hasVisibleHeight) {
      // Draw shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(screenPoint.dx + 2, screenPoint.dy + 2),
        Offset(topPoint.dx + 2, topPoint.dy + 2),
        shadowPaint,
      );
      
      // Draw obstacle line
      final obstaclePaint = Paint()
        ..color = obstacleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(screenPoint, topPoint, obstaclePaint);
      
      // Draw light if lit
      if (obstacle.lighted == true) {
        final lightPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        
        final glowPaint = Paint()
          ..color = Colors.orange.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(topPoint, 6, glowPaint);
        canvas.drawCircle(topPoint, 3, lightPaint);
      }
      
      // Draw base
      final basePaint = Paint()
        ..color = obstacleColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 4, basePaint);
    } else {
      // Just draw a marker
      final markerPaint = Paint()
        ..color = obstacleColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 3, markerPaint);
    }
    
    if (isDangerous) {
      final warningPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 20, warningPaint);
    }
  }

  void _drawBeacon3D(Canvas canvas, Size size, SafeSkyBeacon beacon) {
    final position = LatLng(beacon.latitude, beacon.longitude);
    final screenPoint = _latLngToScreen(position, size);
    
    if (!screenPoint.dx.isFinite || !screenPoint.dy.isFinite) return;
    
    final altitudeFt = beacon.altitude;
    final aircraftPoint = _latLngToScreen(position, size, altitudeFt.toDouble());
    
    if (!aircraftPoint.dx.isFinite || !aircraftPoint.dy.isFinite) return;
    
    final isNearby = _isNearby(beacon);
    final isSameAltitude = (altitudeFt - currentAltitude).abs() < 1000;
    final isDangerous = isNearby && isSameAltitude;
    
    Color aircraftColor;
    if (isDangerous) {
      aircraftColor = Colors.red;
    } else if (isSameAltitude) {
      aircraftColor = Colors.orange;
    } else if (beacon.beaconType == 'HELICOPTER') {
      aircraftColor = Colors.green;
    } else {
      aircraftColor = Colors.yellow;
    }
    
    // Draw altitude line
    final heightDiff = (aircraftPoint.dy - screenPoint.dy).abs();
    if (heightDiff > 5) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 8, shadowPaint);
      
      final linePaint = Paint()
        ..color = aircraftColor.withValues(alpha: 0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(screenPoint, aircraftPoint, linePaint);
    }
    
    // Draw aircraft icon
    final paint = Paint()
      ..color = aircraftColor
      ..style = PaintingStyle.fill;
    
    canvas.save();
    canvas.translate(aircraftPoint.dx, aircraftPoint.dy);
    canvas.rotate(beacon.course * math.pi / 180);
    
    final path = ui.Path()
      ..moveTo(0, -10)
      ..lineTo(-3, -5)
      ..lineTo(-8, 0)
      ..lineTo(-8, 2)
      ..lineTo(-3, 0)
      ..lineTo(-3, 8)
      ..lineTo(-5, 10)
      ..lineTo(0, 8)
      ..lineTo(5, 10)
      ..lineTo(3, 8)
      ..lineTo(3, 0)
      ..lineTo(8, 2)
      ..lineTo(8, 0)
      ..lineTo(3, -5)
      ..close();
    
    canvas.drawPath(path, paint);
    canvas.restore();
    
    if (isDangerous) {
      final warningPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(aircraftPoint, 30, warningPaint);
    }
  }

  bool _isNearby(SafeSkyBeacon beacon) {
    if (currentPosition == null) return false;
    
    const nearbyDistanceKm = 9.26; // 5 nautical miles
    final beaconPos = LatLng(beacon.latitude, beacon.longitude);
    final distance = _calculateDistance(currentPosition!, beaconPos);
    
    return distance < nearbyDistanceKm;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371; // km
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLon = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

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

  Offset _latLngToScreen(LatLng latLng, Size size, [double altitudeFt = 0]) {
    try {
      // Check bounds first
      final bounds = mapCamera.visibleBounds;
      if (latLng.latitude < bounds.south - 2 || 
          latLng.latitude > bounds.north + 2 ||
          latLng.longitude < bounds.west - 2 || 
          latLng.longitude > bounds.east + 2) {
        return Offset(size.width / 2, size.height / 2);
      }
      
      // Project point
      final point = mapCamera.projectAtZoom(latLng, mapCamera.zoom);
      final centerPoint = mapCamera.projectAtZoom(mapCamera.center, mapCamera.zoom);
      
      var dx = point.dx - centerPoint.dx;
      var dy = point.dy - centerPoint.dy;
      
      // Validate values
      if (!dx.isFinite || !dy.isFinite || dx.abs() > 50000 || dy.abs() > 50000) {
        return Offset(size.width / 2, size.height / 2);
      }
      
      // Apply altitude offset for 3D effect
      if (altitudeFt > 0) {
        final tiltRadians = mapTilt * math.pi / 180;
        final perspectiveFactor = 1.0 + math.sin(tiltRadians) * 1.2;
        final zoomFactor = math.pow(2.0, (mapCamera.zoom - 10) / 4).clamp(0.5, 2.0);
        final altitudeOffset = (altitudeFt / 1000.0) * 12 * zoomFactor * perspectiveFactor;
        dy -= altitudeOffset;
      }
      
      // Clamp values
      dx = dx.clamp(-size.width, size.width);
      dy = dy.clamp(-size.height, size.height);
      
      return Offset(size.width / 2 + dx, size.height / 2 + dy);
    } catch (e) {
      return Offset(size.width / 2, size.height / 2);
    }
  }

  @override
  bool shouldRepaint(Unified3DPainter oldDelegate) {
    return oldDelegate.airspaces != airspaces ||
           oldDelegate.obstacles != obstacles ||
           oldDelegate.beacons != beacons ||
           oldDelegate.mapTilt != mapTilt ||
           oldDelegate.currentAltitude != currentAltitude ||
           oldDelegate.mapCamera != mapCamera;
  }
}

enum _ObjectType { airspace, obstacle, beacon }

class _RenderObject {
  final _ObjectType type;
  final dynamic data;
  final double latitude;
  
  _RenderObject({
    required this.type,
    required this.data,
    required this.latitude,
  });
}