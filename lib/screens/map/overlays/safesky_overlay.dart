import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../../models/safesky_beacon.dart';
import '../../../services/safesky_service.dart';
import '../../../services/settings_service.dart';

class SafeSkyOverlay extends StatelessWidget {
  // Constants for collision detection
  static const double collisionDistanceKm = 2.0; // Horizontal collision threshold
  static const double collisionAltitudeFt = 1000.0; // Vertical collision threshold
  static const double collisionTimeMinutes = 15.0; // Time horizon for collision detection
  static const double callsignDisplayRangeKm = 50.0; // Maximum range for callsign display
  
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

  const SafeSkyOverlay({
    super.key,
    required this.safeSkyService,
    required this.showSafeSkyLayer,
    this.onBeaconTap,
    this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSafeSkyLayer) {
      return const SizedBox.shrink();
    }

    try {
      // Get user's unit preferences
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final altitudeUnit = settingsService.altitudeUnit;

      return StreamBuilder<List<SafeSkyBeacon>>(
        stream: safeSkyService.beaconsStream,
        builder: (context, snapshot) {
          // Handle stream errors gracefully
          if (snapshot.hasError) {
            // Log error but don't crash the overlay
            return const SizedBox.shrink();
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          try {
            final beacons = snapshot.data!;
            
            // Check if we should hide labels when there are too many beacons
            final hideLabels = beacons.length > 50;
            
            // Build warning circles first (behind markers)
            final warningCircles = <CircleMarker>[];
            final markers = <Marker>[];
            
            for (final beacon in beacons) {
              try {
                final hasCollisionRisk = _checkCollisionRisk(beacon);
                final distanceKm = _getDistanceKm(beacon);
                // Show callsign only for airborne aircraft (altitude > 0) within display range
                // Hide labels when there are more than 50 beacons to optimize UI
                final showCallsign = !hideLabels && beacon.altitude > 0 && distanceKm != null && distanceKm <= callsignDisplayRangeKm;
                
                if (hasCollisionRisk) {
                  warningCircles.add(_buildWarningCircle(beacon));
                }
                
                markers.add(_buildBeaconMarker(beacon, hasCollisionRisk, showCallsign, altitudeUnit, hideLabels));
              } catch (e) {
                // Skip problematic beacon but continue with others
                continue;
              }
            }
            
            return Stack(
              children: [
                // Warning circles layer (behind markers)
                CircleLayer(circles: warningCircles),
                // Aircraft markers layer
                MarkerLayer(markers: markers),
              ],
            );
          } catch (e) {
            // If processing fails, return empty widget
            return const SizedBox.shrink();
          }
        },
      );
    } catch (e) {
      // If any error occurs in the overlay, return empty widget instead of crashing
      return const SizedBox.shrink();
    }
  }
  
  // Get distance to beacon in kilometers
  double? _getDistanceKm(SafeSkyBeacon beacon) {
    if (currentPosition == null) return null;
    
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(currentPosition!.latitude, currentPosition!.longitude),
      LatLng(beacon.latitude, beacon.longitude),
    );
  }
  
  // Check if aircraft poses real collision risk based on converging paths
  bool _checkCollisionRisk(SafeSkyBeacon beacon) {
    if (currentPosition == null) return false;
    
    // Check altitude difference (within collision altitude threshold)
    final myAltitudeFt = currentPosition!.altitude * 3.28084;
    final beaconAltitudeFt = beacon.altitude * 3.28084;
    final altDifference = (myAltitudeFt - beaconAltitudeFt).abs();
    
    if (altDifference > collisionAltitudeFt) return false;
    
    // Get current positions
    final myLat = currentPosition!.latitude;
    final myLon = currentPosition!.longitude;
    final beaconLat = beacon.latitude;
    final beaconLon = beacon.longitude;
    
    // Get speeds in m/s
    final mySpeed = currentPosition?.speed ?? 0;
    final beaconSpeed = beacon.groundSpeed;
    
    // Skip if either aircraft is not moving significantly (< 5 m/s or ~10 knots)
    const double minSpeedThreshold = 5.0; // m/s
    if (mySpeed < minSpeedThreshold || beaconSpeed < minSpeedThreshold) return false;
    
    // Get headings in radians
    final myHeading = (currentPosition?.heading ?? 0) * math.pi / 180;
    final beaconHeading = beacon.course * math.pi / 180;
    
    // Calculate velocity vectors (m/s in lat/lon approximately)
    // Note: This is simplified and assumes small distances
    final myVelLat = mySpeed * math.cos(myHeading) / 111320; // degrees/second
    final myVelLon = mySpeed * math.sin(myHeading) / (111320 * math.cos(myLat * math.pi / 180));
    final beaconVelLat = beaconSpeed * math.cos(beaconHeading) / 111320;
    final beaconVelLon = beaconSpeed * math.sin(beaconHeading) / (111320 * math.cos(beaconLat * math.pi / 180));
    
    // Calculate closest point of approach (CPA) time
    // Using simplified 2D vector math
    final deltaLat = beaconLat - myLat;
    final deltaLon = beaconLon - myLon;
    final deltaVelLat = beaconVelLat - myVelLat;
    final deltaVelLon = beaconVelLon - myVelLon;
    
    // If relative velocity is near zero, aircraft are moving in parallel
    final relVelSquared = deltaVelLat * deltaVelLat + deltaVelLon * deltaVelLon;
    if (relVelSquared < 0.0000001) return false; // Nearly parallel paths
    
    // Time to closest point of approach
    final tcpa = -(deltaLat * deltaVelLat + deltaLon * deltaVelLon) / relVelSquared;
    
    // Only consider future collisions (positive time) within time horizon
    final collisionTimeSeconds = collisionTimeMinutes * 60;
    if (tcpa < 0 || tcpa > collisionTimeSeconds) return false;
    
    // Calculate distance at CPA
    final cpaLat = deltaLat + deltaVelLat * tcpa;
    final cpaLon = deltaLon + deltaVelLon * tcpa;
    final cpaDistanceKm = math.sqrt(cpaLat * cpaLat + cpaLon * cpaLon) * 111.32; // Convert to km
    
    // Collision risk if CPA is within threshold horizontally
    return cpaDistanceKm < collisionDistanceKm;
  }
  
  // Build warning circle around beacon
  CircleMarker _buildWarningCircle(SafeSkyBeacon beacon) {
    return CircleMarker(
      point: LatLng(beacon.latitude, beacon.longitude),
      radius: 60, // Slightly larger radius for better visibility
      color: Colors.red.withValues(alpha: 0.15),
      borderColor: Colors.red.withValues(alpha: 0.8),
      borderStrokeWidth: 3,
    );
  }

  Marker _buildBeaconMarker(SafeSkyBeacon beacon, bool hasCollisionRisk, bool showCallsign, String altitudeUnit, bool hideLabels) {
    // Calculate opacity based on altitude difference
    final opacity = _calculateOpacity(beacon);
    
    // Determine marker size based on collision risk
    final markerSize = hasCollisionRisk ? markerSizeCollision : markerSizeDefault;
    final iconSize = hasCollisionRisk ? iconSizeCollision : iconSizeDefault;
    
    // Calculate height to accommodate callsign label
    final markerHeight = showCallsign ? markerSize + 20 : markerSize;
    
    return Marker(
      point: LatLng(beacon.latitude, beacon.longitude),
      width: markerSize + (showCallsign ? 40 : 0), // Extra width for callsign
      height: markerHeight,
      child: GestureDetector(
        onTap: () => onBeaconTap?.call(beacon),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Warning ring for collision risk
                if (hasCollisionRisk)
                  Container(
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
                // Aircraft icon with rotation based on heading/course
                Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    // Rotate icon to show aircraft heading
                    // Most icons point up (north) by default, which is 0°
                    // Heading is in degrees clockwise from north
                    angle: _getRotationAngle(beacon.beaconType, beacon.course.toDouble()),
                    child: Icon(
                      _getBeaconIcon(beacon.beaconType),
                      color: hasCollisionRisk ? Colors.red : _getBeaconColor(beacon.beaconType),
                      size: iconSize,
                    ),
                  ),
                ),
              ],
            ),
            // Combined callsign and altitude label
            // Hidden when there are more than 50 beacons to optimize UI
            if (!hideLabels)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: hasCollisionRisk 
                    ? Colors.red.withValues(alpha: 0.9)
                    : Colors.red.withValues(alpha: 0.7),  // Changed from black to red for better visibility
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  (showCallsign || (hasCollisionRisk && beacon.altitude > 0))
                    ? '${beacon.callSign ?? beacon.id} • ${_formatAltitude(beacon.altitudeFt, altitudeUnit)}'
                    : _formatAltitude(beacon.altitudeFt, altitudeUnit),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: hasCollisionRisk ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Calculate marker opacity based on altitude difference
  double _calculateOpacity(SafeSkyBeacon beacon) {
    if (currentPosition == null) return 1.0;
    
    final myAltitudeFt = currentPosition!.altitude * 3.28084;
    final beaconAltitudeFt = beacon.altitude * 3.28084;
    final altDifference = (myAltitudeFt - beaconAltitudeFt).abs();
    
    // Within collision altitude threshold: full opacity
    if (altDifference <= collisionAltitudeFt) return opacityNear;
    
    // Between threshold and fade start: gradual fade
    if (altDifference <= altitudeFadeStartFt) {
      final fadeRange = altitudeFadeStartFt - collisionAltitudeFt;
      final fadeProgress = (altDifference - collisionAltitudeFt) / fadeRange;
      return opacityNear - (fadeProgress * (opacityNear - 0.5));
    }
    
    // Between fade start and fade end: continue fading
    if (altDifference <= altitudeFadeEndFt) {
      final fadeRange = altitudeFadeEndFt - altitudeFadeStartFt;
      final fadeProgress = (altDifference - altitudeFadeStartFt) / fadeRange;
      return 0.5 - (fadeProgress * (0.5 - opacityFar));
    }
    
    // Beyond fade end: minimum opacity
    return opacityFar;
  }

  IconData _getBeaconIcon(String? beaconType) {
    switch (beaconType?.toUpperCase()) {
      case 'JET':
      case 'MOTORPLANE':
      case 'THREE_AXES_LIGHT_PLANE':
        return Icons.flight;
      case 'HELICOPTER':
      case 'GYROCOPTER':
        return Icons.toys;
      case 'GLIDER':
      case 'HAND_GLIDER':
        return Icons.sailing;
      case 'BALLOON':
      case 'AIRSHIP':
        return Icons.filter_drama; // Using cloud as balloon alternative
      case 'PARA_GLIDER':
      case 'PARA_MOTOR':
      case 'PARACHUTE':
        return Icons.paragliding;
      case 'UAV':
      case 'PAV':
        return Icons.radio_button_checked;
      case 'STATIC_OBJECT':
        return Icons.location_on;
      case 'MILITARY':
        return Icons.security;
      case 'UNKNOWN':
      default:
        return Icons.airplanemode_active;
    }
  }
  
  // Get rotation angle for beacon based on type and course
  double _getRotationAngle(String? beaconType, double course) {
    // Convert course to radians
    final courseRadians = course * (math.pi / 180);
    
    switch (beaconType?.toUpperCase()) {
      case 'JET':
      case 'MOTORPLANE':
      case 'THREE_AXES_LIGHT_PLANE':
        // Icons.flight points up-right by default, needs adjustment
        return courseRadians + (math.pi / 4); // Add 45° to align properly
      case 'HELICOPTER':
      case 'GYROCOPTER':
        // Icons.toys helicopter already points up
        return courseRadians;
      case 'GLIDER':
      case 'HAND_GLIDER':
        // Icons.sailing points right by default
        return courseRadians - (math.pi / 2); // Subtract 90° to align
      case 'BALLOON':
      case 'AIRSHIP':
        // Balloons don't really have heading, keep them upright
        return 0.0;
      case 'PARA_GLIDER':
      case 'PARA_MOTOR':
      case 'PARACHUTE':
        // Icons.paragliding points up
        return courseRadians;
      case 'UAV':
      case 'PAV':
        // Drones - rotate based on heading
        return courseRadians;
      case 'STATIC_OBJECT':
        // Static objects don't rotate
        return 0.0;
      case 'MILITARY':
        // Military aircraft - rotate based on heading
        return courseRadians;
      case 'UNKNOWN':
      default:
        // Icons.airplanemode_active points up-right by default
        return courseRadians + (math.pi / 4); // Add 45° to align
    }
  }

  Color _getBeaconColor(String? beaconType) {
    switch (beaconType?.toUpperCase()) {
      case 'JET':
      case 'MOTORPLANE':
      case 'THREE_AXES_LIGHT_PLANE':
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
      case 'PARACHUTE':
        return Colors.green;
      case 'UAV':
      case 'PAV':
        return Colors.purple;
      case 'STATIC_OBJECT':
        return Colors.grey;
      case 'MILITARY':
        return Colors.red;
      case 'UNKNOWN':
      default:
        return Colors.white;
    }
  }
  
  String _formatAltitude(int altitudeFt, String altitudeUnit) {
    if (altitudeUnit == 'm') {
      // Convert feet to meters
      final altitudeM = (altitudeFt * 0.3048).round();
      return '${altitudeM}m';
    } else {
      // Display in feet
      return '${altitudeFt}ft';
    }
  }
}