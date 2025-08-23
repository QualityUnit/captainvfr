import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' show Position;
import '../../../models/safesky_beacon.dart';
import '../../../services/safesky_service.dart';

class SafeSkyOverlay extends StatelessWidget {
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

    return StreamBuilder<List<SafeSkyBeacon>>(
      stream: safeSkyService.beaconsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final beacons = snapshot.data!;
        
        // Build warning circles first (behind markers)
        final warningCircles = <CircleMarker>[];
        final markers = <Marker>[];
        
        for (final beacon in beacons) {
          final warning = _checkCollisionWarning(beacon);
          if (warning) {
            warningCircles.add(_buildWarningCircle(beacon));
          }
          markers.add(_buildBeaconMarker(beacon, warning));
        }
        
        return Stack(
          children: [
            // Warning circles layer (behind markers)
            CircleLayer(circles: warningCircles),
            // Aircraft markers layer
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }
  
  // Check if aircraft poses collision risk
  bool _checkCollisionWarning(SafeSkyBeacon beacon) {
    if (currentPosition == null) return false;
    
    // Check altitude difference (within 1000 feet)
    final myAltitudeFt = currentPosition!.altitude * 3.28084;
    final beaconAltitudeFt = beacon.altitude * 3.28084;
    final altDifference = (myAltitudeFt - beaconAltitudeFt).abs();
    
    if (altDifference > 1000) return false;
    
    // Calculate distance in km
    final distance = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(currentPosition!.latitude, currentPosition!.longitude),
      LatLng(beacon.latitude, beacon.longitude),
    );
    
    // Calculate time to intercept (assuming both aircraft maintain current speeds)
    final mySpeedKmh = (currentPosition?.speed ?? 0) * 3.6; // m/s to km/h
    final beaconSpeedKmh = beacon.groundSpeed * 3.6; // m/s to km/h
    
    // Simple calculation: if aircraft are getting closer
    // More sophisticated calculation would consider heading vectors
    final relativeSpeed = mySpeedKmh + beaconSpeedKmh; // Worst case scenario
    if (relativeSpeed <= 0) return false;
    
    final timeToIntercept = (distance / relativeSpeed) * 60; // Convert to minutes
    
    // Warning if within 15 minutes of potential intercept
    return timeToIntercept <= 15;
  }
  
  // Build warning circle around beacon
  CircleMarker _buildWarningCircle(SafeSkyBeacon beacon) {
    return CircleMarker(
      point: LatLng(beacon.latitude, beacon.longitude),
      radius: 50, // 50 pixel radius for warning circle
      color: Colors.red.withValues(alpha: 0.2),
      borderColor: Colors.red.withValues(alpha: 0.6),
      borderStrokeWidth: 2,
    );
  }

  Marker _buildBeaconMarker(SafeSkyBeacon beacon, bool hasWarning) {
    // Calculate opacity based on altitude difference
    final opacity = _calculateOpacity(beacon);
    
    return Marker(
      point: LatLng(beacon.latitude, beacon.longitude),
      width: hasWarning ? 56 : 48,
      height: hasWarning ? 56 : 48,
      child: GestureDetector(
        onTap: () => onBeaconTap?.call(beacon),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Warning pulse animation for collision risk
            if (hasWarning)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.8),
                    width: 3,
                  ),
                ),
              ),
            // Aircraft icon with rotation
            Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: beacon.course * (3.14159 / 180), // Convert degrees to radians
                child: Icon(
                  _getBeaconIcon(beacon.beaconType),
                  color: hasWarning ? Colors.red : _getBeaconColor(beacon.beaconType),
                  size: hasWarning ? 36 : 32,
                ),
              ),
            ),
            // Altitude label
            Positioned(
              bottom: hasWarning ? 4 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: (hasWarning ? Colors.red : Colors.black).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${beacon.altitudeFt}ft',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: hasWarning ? 10 : 9,
                    fontWeight: FontWeight.bold,
                  ),
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
    
    // Within 1000 feet: full opacity
    if (altDifference <= 1000) return 1.0;
    
    // 1000-3000 feet: gradual fade from 1.0 to 0.5
    if (altDifference <= 3000) {
      return 1.0 - ((altDifference - 1000) / 2000) * 0.5;
    }
    
    // 3000-5000 feet: gradual fade from 0.5 to 0.3
    if (altDifference <= 5000) {
      return 0.5 - ((altDifference - 3000) / 2000) * 0.2;
    }
    
    // Beyond 5000 feet: minimum opacity
    return 0.3;
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
}