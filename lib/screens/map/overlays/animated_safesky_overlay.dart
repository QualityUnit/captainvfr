import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'dart:math' as math;
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../models/safesky_beacon.dart';
import '../../../services/safesky_service.dart';
import '../../../services/settings_service.dart';

/// Animated beacon data with interpolated position
class AnimatedBeaconData {
  final SafeSkyBeacon beacon;
  LatLng currentPosition;
  LatLng targetPosition;
  DateTime lastUpdate;
  
  AnimatedBeaconData({
    required this.beacon,
    required LatLng position,
  }) : currentPosition = position,
       targetPosition = position,
       lastUpdate = DateTime.now();
       
  void updateWithNewBeacon(SafeSkyBeacon newBeacon) {
    // Start from current interpolated position
    currentPosition = getCurrentInterpolatedPosition();
    targetPosition = LatLng(newBeacon.latitude, newBeacon.longitude);
    lastUpdate = DateTime.now();
  }
  
  /// Get interpolated position based on elapsed time and ground speed
  LatLng getCurrentInterpolatedPosition() {
    if (beacon.groundSpeed <= 0) {
      return currentPosition;
    }
    
    final elapsed = DateTime.now().difference(lastUpdate).inMilliseconds / 1000.0; // seconds
    final distanceTraveled = beacon.groundSpeed * elapsed; // meters
    
    // Calculate maximum possible distance between positions
    final distance = const Distance();
    final maxDistance = distance.as(LengthUnit.Meter, currentPosition, targetPosition);
    
    if (maxDistance <= 0) {
      return targetPosition;
    }
    
    // Calculate interpolation factor (0 to 1)
    final t = math.min(1.0, distanceTraveled / maxDistance);
    
    // Linear interpolation of position
    final lat = currentPosition.latitude + (targetPosition.latitude - currentPosition.latitude) * t;
    final lng = currentPosition.longitude + (targetPosition.longitude - currentPosition.longitude) * t;
    
    return LatLng(lat, lng);
  }
}

class AnimatedSafeSkyOverlay extends StatefulWidget {
  // Constants for collision detection
  static const double collisionDistanceKm = 2.0;
  static const double collisionAltitudeFt = 1000.0;
  static const double collisionTimeMinutes = 15.0;
  static const double callsignDisplayRangeKm = 50.0;
  
  // Constants for visual display
  static const double iconSizeDefault = 24.0;
  static const double iconSizeCollision = 28.0;
  static const double markerSizeDefault = 48.0;
  static const double markerSizeCollision = 60.0;
  static const double opacityNear = 1.0;
  static const double opacityFar = 0.3;
  static const double altitudeFadeStartFt = 2000.0;
  static const double altitudeFadeEndFt = 5000.0;
  
  final SafeSkyService safeSkyService;
  final bool showSafeSkyLayer;
  final Function(SafeSkyBeacon)? onBeaconTap;
  final Position? currentPosition;
  
  const AnimatedSafeSkyOverlay({
    super.key,
    required this.safeSkyService,
    required this.showSafeSkyLayer,
    this.onBeaconTap,
    this.currentPosition,
  });
  
  @override
  State<AnimatedSafeSkyOverlay> createState() => _AnimatedSafeSkyOverlayState();
}

class _AnimatedSafeSkyOverlayState extends State<AnimatedSafeSkyOverlay> 
    with SingleTickerProviderStateMixin {
  
  // Animation controller for smooth updates
  late AnimationController _animationController;
  Timer? _animationTimer;
  
  // Map of beacon ID to animated data
  final Map<String, AnimatedBeaconData> _animatedBeacons = {};
  
  // Stream subscription
  StreamSubscription<List<SafeSkyBeacon>>? _beaconSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Create animation controller for smooth 60fps updates
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    // Start animation timer for position updates (60fps)
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted && widget.showSafeSkyLayer) {
        setState(() {
          // Trigger rebuild to update interpolated positions
        });
      }
    });
    
    // Subscribe to beacon updates
    _subscribeToBeacons();
  }
  
  @override
  void didUpdateWidget(AnimatedSafeSkyOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.showSafeSkyLayer != oldWidget.showSafeSkyLayer) {
      if (widget.showSafeSkyLayer) {
        _subscribeToBeacons();
      } else {
        _unsubscribeFromBeacons();
      }
    }
  }
  
  void _subscribeToBeacons() {
    _beaconSubscription?.cancel();
    _beaconSubscription = widget.safeSkyService.beaconsStream.listen((beacons) {
      _updateBeacons(beacons);
    });
  }
  
  void _unsubscribeFromBeacons() {
    _beaconSubscription?.cancel();
    _beaconSubscription = null;
  }
  
  void _updateBeacons(List<SafeSkyBeacon> newBeacons) {
    if (!mounted) return;
    
    setState(() {
      // Create a map of new beacons for quick lookup
      final newBeaconsMap = {for (var b in newBeacons) b.id: b};
      
      // Update existing beacons
      final beaconsToRemove = <String>[];
      for (final entry in _animatedBeacons.entries) {
        final id = entry.key;
        final animatedData = entry.value;
        
        if (newBeaconsMap.containsKey(id)) {
          // Update existing beacon - keep the animated data, just update the target
          final newBeacon = newBeaconsMap[id]!;
          animatedData.updateWithNewBeacon(newBeacon);
          // Update the beacon data itself
          _animatedBeacons[id] = AnimatedBeaconData(
            beacon: newBeacon,
            position: animatedData.currentPosition,
          )..currentPosition = animatedData.currentPosition
           ..targetPosition = LatLng(newBeacon.latitude, newBeacon.longitude)
           ..lastUpdate = animatedData.lastUpdate;
        } else {
          // Mark for removal if not in new update
          beaconsToRemove.add(id);
        }
      }
      
      // Remove old beacons
      for (final id in beaconsToRemove) {
        _animatedBeacons.remove(id);
      }
      
      // Add new beacons
      for (final beacon in newBeacons) {
        if (!_animatedBeacons.containsKey(beacon.id)) {
          _animatedBeacons[beacon.id] = AnimatedBeaconData(
            beacon: beacon,
            position: LatLng(beacon.latitude, beacon.longitude),
          );
        }
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _animationTimer?.cancel();
    _beaconSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.showSafeSkyLayer) {
      return const SizedBox.shrink();
    }
    
    try {
      // Get user's unit preferences
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final altitudeUnit = settingsService.altitudeUnit;
      
      // Get current map camera for zoom level
      final mapCamera = MapCamera.maybeOf(context);
      if (mapCamera == null) {
        return const SizedBox.shrink();
      }
      
      // Build warning circles and markers
      final warningCircles = <CircleMarker>[];
      final markers = <Marker>[];
      
      for (final animatedData in _animatedBeacons.values) {
        try {
          final beacon = animatedData.beacon;
          
          // Get interpolated position
          final interpolatedPosition = animatedData.getCurrentInterpolatedPosition();
          
          // Check collision risk using interpolated position
          final hasCollisionRisk = _checkCollisionRisk(beacon, interpolatedPosition);
          final distanceKm = _getDistanceKm(interpolatedPosition);
          final showCallsign = beacon.altitude > 0 && 
                              distanceKm != null && 
                              distanceKm <= AnimatedSafeSkyOverlay.callsignDisplayRangeKm;
          
          if (hasCollisionRisk) {
            warningCircles.add(_buildWarningCircle(interpolatedPosition));
          }
          
          markers.add(_buildBeaconMarker(
            beacon, 
            interpolatedPosition,
            hasCollisionRisk, 
            showCallsign, 
            altitudeUnit,
            mapCamera.zoom,
          ));
        } catch (e) {
          // Skip problematic beacon but continue with others
          continue;
        }
      }
      
      return Stack(
        children: [
          // Warning circles layer (behind markers)
          if (warningCircles.isNotEmpty)
            CircleLayer(circles: warningCircles),
          // Aircraft markers layer
          MarkerLayer(markers: markers),
        ],
      );
    } catch (e) {
      // If any error occurs, return empty widget
      return const SizedBox.shrink();
    }
  }
  
  // Get distance to beacon in kilometers
  double? _getDistanceKm(LatLng beaconPosition) {
    if (widget.currentPosition == null) return null;
    
    final myPosition = LatLng(
      widget.currentPosition!.latitude,
      widget.currentPosition!.longitude,
    );
    
    return const Distance().as(LengthUnit.Kilometer, myPosition, beaconPosition);
  }
  
  // Check if aircraft poses real collision risk
  bool _checkCollisionRisk(SafeSkyBeacon beacon, LatLng interpolatedPosition) {
    if (widget.currentPosition == null) return false;
    
    // Check altitude difference
    final myAltitudeFt = widget.currentPosition!.altitude * 3.28084;
    final beaconAltitudeFt = beacon.altitude * 3.28084;
    final altDifference = (myAltitudeFt - beaconAltitudeFt).abs();
    
    if (altDifference > AnimatedSafeSkyOverlay.collisionAltitudeFt) return false;
    
    // Check if either aircraft is moving significantly
    const double minSpeedThreshold = 5.0; // m/s
    final mySpeed = widget.currentPosition?.speed ?? 0;
    if (mySpeed < minSpeedThreshold || beacon.groundSpeed < minSpeedThreshold) return false;
    
    // Calculate CPA (Closest Point of Approach)
    final myLat = widget.currentPosition!.latitude;
    final myLon = widget.currentPosition!.longitude;
    final beaconLat = interpolatedPosition.latitude;
    final beaconLon = interpolatedPosition.longitude;
    
    // Get velocities
    final myHeading = (widget.currentPosition?.heading ?? 0) * math.pi / 180;
    final beaconHeading = beacon.course * math.pi / 180;
    
    final myVelLat = mySpeed * math.cos(myHeading) / 111320; // degrees/s
    final myVelLon = mySpeed * math.sin(myHeading) / (111320 * math.cos(myLat * math.pi / 180));
    final beaconVelLat = beacon.groundSpeed * math.cos(beaconHeading) / 111320;
    final beaconVelLon = beacon.groundSpeed * math.sin(beaconHeading) / (111320 * math.cos(beaconLat * math.pi / 180));
    
    // Relative position and velocity
    final deltaLat = beaconLat - myLat;
    final deltaLon = beaconLon - myLon;
    final deltaVelLat = beaconVelLat - myVelLat;
    final deltaVelLon = beaconVelLon - myVelLon;
    
    final relVelSquared = deltaVelLat * deltaVelLat + deltaVelLon * deltaVelLon;
    if (relVelSquared < 1e-10) return false; // Not converging
    
    // Time to CPA
    final tcpa = -(deltaLat * deltaVelLat + deltaLon * deltaVelLon) / relVelSquared;
    
    // Check time horizon
    final collisionTimeSeconds = AnimatedSafeSkyOverlay.collisionTimeMinutes * 60;
    if (tcpa < 0 || tcpa > collisionTimeSeconds) return false;
    
    // Calculate distance at CPA
    final cpaLat = deltaLat + deltaVelLat * tcpa;
    final cpaLon = deltaLon + deltaVelLon * tcpa;
    final cpaDistanceKm = math.sqrt(cpaLat * cpaLat + cpaLon * cpaLon) * 111.32;
    
    return cpaDistanceKm < AnimatedSafeSkyOverlay.collisionDistanceKm;
  }
  
  // Build warning circle
  CircleMarker _buildWarningCircle(LatLng position) {
    return CircleMarker(
      point: position,
      color: Colors.red.withValues(alpha: 0.15),
      borderColor: Colors.red.withValues(alpha: 0.5),
      borderStrokeWidth: 3,
      radius: 100, // 100 meter radius warning zone
    );
  }
  
  // Build beacon marker with proper visual feedback
  Marker _buildBeaconMarker(
    SafeSkyBeacon beacon,
    LatLng interpolatedPosition,
    bool hasCollisionRisk,
    bool showCallsign,
    String altitudeUnit,
    double mapZoom,
  ) {
    // Calculate opacity based on altitude
    final opacity = _calculateOpacity(beacon);
    
    // Determine marker size
    final markerSize = hasCollisionRisk 
        ? AnimatedSafeSkyOverlay.markerSizeCollision 
        : AnimatedSafeSkyOverlay.markerSizeDefault;
    final iconSize = hasCollisionRisk 
        ? AnimatedSafeSkyOverlay.iconSizeCollision 
        : AnimatedSafeSkyOverlay.iconSizeDefault;
    
    // Add speed indicator trail if moving fast enough
    final showSpeedTrail = beacon.groundSpeed > 10 && mapZoom > 10;
    // Cap trail length to prevent overflow
    final trailLength = showSpeedTrail ? math.min(beacon.groundSpeed * 0.3, 30.0) : 0.0;
    
    // Calculate total height needed including trail
    final totalHeight = markerSize + (showCallsign ? 20 : 0) + trailLength;
    
    return Marker(
      point: interpolatedPosition,
      width: markerSize + (showCallsign ? 60 : 20), // Extra width for callsign and labels
      height: totalHeight,
      child: GestureDetector(
        onTap: () => widget.onBeaconTap?.call(beacon),
        child: SizedBox(
          width: markerSize + (showCallsign ? 60 : 20),
          height: totalHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
            // Speed trail indicator (positioned behind the icon)
            if (showSpeedTrail)
              Positioned(
                top: (totalHeight - markerSize) / 2 - trailLength,
                child: Transform.rotate(
                  angle: (beacon.course - 180) * math.pi / 180, // Trail behind aircraft
                  child: Container(
                    width: 2,
                    height: trailLength,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _getBeaconColor(beacon.beaconType).withValues(alpha: 0),
                          _getBeaconColor(beacon.beaconType).withValues(alpha: opacity * 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Warning ring - positioned at center
            if (hasCollisionRisk)
              Positioned(
                top: (totalHeight - markerSize) / 2,
                child: Container(
                  width: markerSize,
                  height: markerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red,
                      width: 3,
                    ),
                  ),
                ),
              ),
            // Aircraft icon - positioned at center
            Positioned(
              top: (totalHeight - markerSize) / 2,
              child: SizedBox(
                width: markerSize,
                height: markerSize,
                child: Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: _getRotationAngle(beacon.beaconType, beacon.course.toDouble()),
                      child: Icon(
                        _getBeaconIcon(beacon.beaconType),
                        color: hasCollisionRisk ? Colors.red : _getBeaconColor(beacon.beaconType),
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Altitude label - positioned top-right of icon
            Positioned(
              top: (totalHeight - markerSize) / 2 - 4,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: (hasCollisionRisk ? Colors.red : Colors.black).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _formatAltitude(beacon.altitudeFt, altitudeUnit),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Callsign label - positioned below icon
            if (showCallsign && beacon.callSign != null)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    beacon.callSign!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Calculate opacity based on altitude difference
  double _calculateOpacity(SafeSkyBeacon beacon) {
    if (widget.currentPosition == null) return 1.0;
    
    final myAltitudeFt = widget.currentPosition!.altitude * 3.28084;
    final beaconAltitudeFt = beacon.altitude * 3.28084;
    final altDifference = (myAltitudeFt - beaconAltitudeFt).abs();
    
    if (altDifference <= AnimatedSafeSkyOverlay.collisionAltitudeFt) {
      return AnimatedSafeSkyOverlay.opacityNear;
    }
    
    if (altDifference <= AnimatedSafeSkyOverlay.altitudeFadeStartFt) {
      final fadeRange = AnimatedSafeSkyOverlay.altitudeFadeStartFt - AnimatedSafeSkyOverlay.collisionAltitudeFt;
      final fadeProgress = (altDifference - AnimatedSafeSkyOverlay.collisionAltitudeFt) / fadeRange;
      return AnimatedSafeSkyOverlay.opacityNear - (fadeProgress * (AnimatedSafeSkyOverlay.opacityNear - 0.5));
    }
    
    if (altDifference <= AnimatedSafeSkyOverlay.altitudeFadeEndFt) {
      final fadeRange = AnimatedSafeSkyOverlay.altitudeFadeEndFt - AnimatedSafeSkyOverlay.altitudeFadeStartFt;
      final fadeProgress = (altDifference - AnimatedSafeSkyOverlay.altitudeFadeStartFt) / fadeRange;
      return 0.5 - (fadeProgress * (0.5 - AnimatedSafeSkyOverlay.opacityFar));
    }
    
    return AnimatedSafeSkyOverlay.opacityFar;
  }
  
  IconData _getBeaconIcon(String? beaconType) {
    switch (beaconType?.toUpperCase()) {
      case 'JET':
      case 'MOTORPLANE':
        return Icons.flight;
      case 'HELICOPTER':
      case 'GYROCOPTER':
        return Icons.toys;
      case 'GLIDER':
      case 'HAND_GLIDER':
        return Icons.flight_takeoff;
      case 'BALLOON':
      case 'AIRSHIP':
        return Icons.bubble_chart;
      case 'PARA_GLIDER':
      case 'PARA_MOTOR':
        return Icons.paragliding;
      case 'UAV':
      case 'PAV':
        return Icons.precision_manufacturing;
      case 'STATIC_OBJECT':
        return Icons.radio_button_checked;
      case 'MILITARY':
        return Icons.shield;
      default:
        return Icons.airplanemode_active;
    }
  }
  
  double _getRotationAngle(String? beaconType, double courseRadians) {
    // Adjust rotation based on icon default orientation
    switch (beaconType?.toUpperCase()) {
      case 'HELICOPTER':
      case 'GYROCOPTER':
        return courseRadians;
      case 'GLIDER':
      case 'HAND_GLIDER':
        return courseRadians + (math.pi / 4);
      case 'BALLOON':
      case 'AIRSHIP':
        return 0.0; // No rotation for balloons
      case 'PARA_GLIDER':
      case 'PARA_MOTOR':
        return courseRadians;
      case 'UAV':
      case 'PAV':
        return courseRadians;
      case 'STATIC_OBJECT':
        return 0.0;
      case 'MILITARY':
        return courseRadians;
      default:
        return courseRadians + (math.pi / 4);
    }
  }
  
  Color _getBeaconColor(String? beaconType) {
    switch (beaconType?.toUpperCase()) {
      case 'JET':
      case 'MOTORPLANE':
        return Colors.blue;
      case 'HELICOPTER':
      case 'GYROCOPTER':
        return Colors.orange;
      case 'GLIDER':
      case 'HAND_GLIDER':
        return Colors.cyan;
      case 'BALLOON':
      case 'AIRSHIP':
        return Colors.pink;
      case 'PARA_GLIDER':
      case 'PARA_MOTOR':
        return Colors.green;
      case 'UAV':
      case 'PAV':
        return Colors.purple;
      case 'STATIC_OBJECT':
        return Colors.grey;
      case 'MILITARY':
        return Colors.red;
      default:
        return Colors.white;
    }
  }
  
  String _formatAltitude(int altitudeFt, String altitudeUnit) {
    if (altitudeUnit == 'm') {
      final altitudeM = (altitudeFt * 0.3048).round();
      return '${altitudeM}m';
    } else {
      return '${altitudeFt}ft';
    }
  }
}