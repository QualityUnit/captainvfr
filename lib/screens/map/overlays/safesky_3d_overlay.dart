import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../../../models/safesky_beacon.dart';

/// 3D SafeSky beacons overlay that renders aircraft with altitude when map is tilted
class SafeSky3DOverlay extends StatefulWidget {
  final List<SafeSkyBeacon> beacons;
  final double mapTilt;
  final Function(SafeSkyBeacon)? onBeaconTap;
  final double currentAltitude;
  final LatLng? currentPosition;
  final MapController mapController;

  const SafeSky3DOverlay({
    super.key,
    required this.beacons,
    required this.mapTilt,
    required this.mapController,
    this.onBeaconTap,
    this.currentAltitude = 0,
    this.currentPosition,
  });

  @override
  State<SafeSky3DOverlay> createState() => _SafeSky3DOverlayState();
}

class _SafeSky3DOverlayState extends State<SafeSky3DOverlay> {
  List<SafeSkyBeacon> _cachedBeacons = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateBeacons();
  }

  @override
  void didUpdateWidget(SafeSky3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if beacons list has changed
    if (widget.beacons != oldWidget.beacons) {
      // Debounce updates to avoid too frequent rerendering
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 100), () {
        _updateBeacons();
      });
    }
  }

  void _updateBeacons() {
    if (mounted) {
      setState(() {
        _cachedBeacons = widget.beacons;
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
    if (_cachedBeacons.isEmpty || widget.mapTilt < 5) {
      return const SizedBox.shrink();
    }

    final mapCamera = widget.mapController.camera;

    return RepaintBoundary(
      child: CustomPaint(
        painter: SafeSky3DPainter(
          beacons: _cachedBeacons,
          mapCamera: mapCamera,
          mapTilt: widget.mapTilt,
          currentAltitude: widget.currentAltitude,
          currentPosition: widget.currentPosition,
          onBeaconTap: widget.onBeaconTap,
        ),
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

class SafeSky3DPainter extends CustomPainter {
  final List<SafeSkyBeacon> beacons;
  final MapCamera mapCamera;
  final double mapTilt;
  final double currentAltitude;
  final LatLng? currentPosition;
  final Function(SafeSkyBeacon)? onBeaconTap;

  SafeSky3DPainter({
    required this.beacons,
    required this.mapCamera,
    required this.mapTilt,
    required this.currentAltitude,
    this.currentPosition,
    this.onBeaconTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (beacons.isEmpty || size.isEmpty) return;

    canvas.save();
    
    try {
      // Filter beacons that are within visible bounds
      final visibleBounds = mapCamera.visibleBounds;
      final visibleBeacons = <SafeSkyBeacon>[];
      
      for (final beacon in beacons) {
        // Check if beacon is within visible bounds
        if (beacon.latitude >= visibleBounds.south &&
            beacon.latitude <= visibleBounds.north &&
            beacon.longitude >= visibleBounds.west &&
            beacon.longitude <= visibleBounds.east) {
          visibleBeacons.add(beacon);
        }
      }
      
      // Sort beacons by latitude for proper depth rendering in 3D view
      // Northern (farther) beacons should be drawn first
      visibleBeacons.sort((a, b) {
        return b.latitude.compareTo(a.latitude);
      });

      // Draw all visible beacons
      for (final beacon in visibleBeacons) {
        try {
          _drawBeacon3D(canvas, size, beacon);
        } catch (e) {
          // Skip beacon if rendering fails
          continue;
        }
      }
    } finally {
      canvas.restore();
    }
  }

  void _drawBeacon3D(Canvas canvas, Size size, SafeSkyBeacon beacon) {
    // Get screen position at ground level
    final screenPoint = _latLngToScreen(
      LatLng(beacon.latitude, beacon.longitude),
      size,
      0, // Ground level
    );
    
    // Get beacon altitude
    final altitudeFt = beacon.altitude;
    
    // Calculate proximity warning
    final isNearby = _isNearby(beacon);
    final isSameAltitude = (altitudeFt - currentAltitude).abs() < 1000;
    final isDangerous = isNearby && isSameAltitude;
    
    // Determine aircraft color based on type and proximity
    Color aircraftColor;
    if (isDangerous) {
      aircraftColor = Colors.red;
    } else if (isSameAltitude) {
      aircraftColor = Colors.orange;
    } else if (beacon.beaconType == 'HELICOPTER') {
      aircraftColor = Colors.green;
    } else if (beacon.beaconType == 'JET') {
      aircraftColor = Colors.blue;
    } else if (beacon.beaconType == 'GLIDER') {
      aircraftColor = Colors.cyan;
    } else {
      aircraftColor = Colors.yellow;
    }
    
    // Calculate aircraft position at altitude using proper 3D projection
    final aircraftPoint = _latLngToScreen(
      LatLng(beacon.latitude, beacon.longitude),
      size,
      altitudeFt.toDouble(),
    );
    
    // Draw altitude line from ground to aircraft
    final heightDiff = (aircraftPoint.dy - screenPoint.dy).abs();
    if (heightDiff > 5) {
      // Draw shadow/projection on ground
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPoint, 8, shadowPaint);
      
      // Draw altitude line
      final linePaint = Paint()
        ..color = aircraftColor.withValues(alpha: 0.3)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      // Dashed line effect
      final path = ui.Path()
        ..moveTo(screenPoint.dx, screenPoint.dy)
        ..lineTo(aircraftPoint.dx, aircraftPoint.dy);
      
      canvas.drawPath(path, linePaint);
    }
    
    // Draw aircraft icon at altitude
    _drawAircraftIcon(
      canvas,
      aircraftPoint,
      beacon,
      aircraftColor,
      isDangerous,
    );
    
    // Draw motion vector (course and speed)
    if (beacon.groundSpeed > 0) {
      _drawMotionVector(
        canvas,
        aircraftPoint,
        beacon.course.toDouble(),
        beacon.groundSpeed.toDouble(),
        aircraftColor,
      );
    }
    
    // Draw labels when zoomed in
    if (mapCamera.zoom > 11) {
      _drawBeaconLabel(
        canvas,
        aircraftPoint,
        beacon,
        isDangerous,
      );
    }
    
    // Draw warning circle if dangerous
    if (isDangerous) {
      final warningPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(aircraftPoint, 30, warningPaint);
      
      final warningBorderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(aircraftPoint, 30, warningBorderPaint);
    }
  }
  
  void _drawAircraftIcon(
    Canvas canvas,
    Offset position,
    SafeSkyBeacon beacon,
    Color color,
    bool isDangerous,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Rotate based on heading
    canvas.save();
    canvas.translate(position.dx, position.dy);
    
    canvas.rotate(beacon.course * math.pi / 180);
    
    // Draw aircraft shape based on type
    final path = ui.Path();
    
    if (beacon.beaconType == 'HELICOPTER') {
      // Helicopter shape
      path.moveTo(0, -8);
      path.lineTo(-6, 4);
      path.lineTo(-2, 4);
      path.lineTo(-2, 8);
      path.lineTo(2, 8);
      path.lineTo(2, 4);
      path.lineTo(6, 4);
      path.close();
      
      // Rotor
      final rotorPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset.zero, 10, rotorPaint);
    } else {
      // Airplane shape
      path.moveTo(0, -10);
      path.lineTo(-3, -5);
      path.lineTo(-8, 0);
      path.lineTo(-8, 2);
      path.lineTo(-3, 0);
      path.lineTo(-3, 8);
      path.lineTo(-5, 10);
      path.lineTo(0, 8);
      path.lineTo(5, 10);
      path.lineTo(3, 8);
      path.lineTo(3, 0);
      path.lineTo(8, 2);
      path.lineTo(8, 0);
      path.lineTo(3, -5);
      path.close();
    }
    
    // Draw shadow for depth
    canvas.save();
    canvas.translate(2, 2);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
    
    // Draw aircraft
    canvas.drawPath(path, outlinePaint);
    canvas.drawPath(path, paint);
    
    // Flashing effect for dangerous aircraft
    if (isDangerous) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, 3, flashPaint);
    }
    
    canvas.restore();
  }
  
  void _drawMotionVector(
    Canvas canvas,
    Offset position,
    double course,
    double groundSpeed,
    Color color,
  ) {
    // Calculate vector length based on speed
    final vectorLength = math.min(50, groundSpeed / 2);
    
    // Calculate end point
    final radians = (course - 90) * math.pi / 180;
    final endPoint = Offset(
      position.dx + vectorLength * math.cos(radians),
      position.dy + vectorLength * math.sin(radians),
    );
    
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(position, endPoint, paint);
    
    // Draw arrowhead
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final arrowPath = ui.Path();
    final arrowLength = 6.0;
    final arrowAngle = 0.5;
    
    arrowPath.moveTo(endPoint.dx, endPoint.dy);
    arrowPath.lineTo(
      endPoint.dx - arrowLength * math.cos(radians - arrowAngle),
      endPoint.dy - arrowLength * math.sin(radians - arrowAngle),
    );
    arrowPath.lineTo(
      endPoint.dx - arrowLength * math.cos(radians + arrowAngle),
      endPoint.dy - arrowLength * math.sin(radians + arrowAngle),
    );
    arrowPath.close();
    
    canvas.drawPath(arrowPath, arrowPaint);
  }
  
  void _drawBeaconLabel(
    Canvas canvas,
    Offset position,
    SafeSkyBeacon beacon,
    bool isDangerous,
  ) {
    final callsign = beacon.callSign ?? 'Unknown';
    final altitude = beacon.altitude.round();
    final speed = beacon.groundSpeedKnots;
    
    final text = '$callsign\nFL${(altitude / 100).round()} ${speed}kt';
    
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: isDangerous ? Colors.red : Colors.white,
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
        position.dx - textPainter.width / 2,
        position.dy + 15,
      ),
    );
  }
  
  bool _isNearby(SafeSkyBeacon beacon) {
    final pos = currentPosition;
    if (pos == null) return false;
    
    const nearbyDistanceNm = 5.0; // 5 nautical miles
    const nmToKm = 1.852;
    const nearbyDistanceKm = nearbyDistanceNm * nmToKm;
    
    final distance = _calculateDistance(
      pos,
      LatLng(beacon.latitude, beacon.longitude),
    );
    
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
  bool shouldRepaint(SafeSky3DPainter oldDelegate) {
    return oldDelegate.beacons != beacons ||
           oldDelegate.mapTilt != mapTilt ||
           oldDelegate.currentAltitude != currentAltitude ||
           oldDelegate.mapCamera != mapCamera;
  }
}