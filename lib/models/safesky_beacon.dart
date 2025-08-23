import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../utils/spatial_index.dart';

part 'safesky_beacon.g.dart';

@HiveType(typeId: 56)
class SafeSkyBeacon extends HiveObject implements SpatialIndexable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double latitude;

  @HiveField(2)
  final double longitude;

  @HiveField(3)
  final int altitude; // meters AMSL

  @HiveField(4)
  final int? altitudeAccuracy; // meters

  @HiveField(5)
  final int? accuracy; // coordinate accuracy in meters

  @HiveField(6)
  final String? callSign; // public profile only

  @HiveField(7)
  final int groundSpeed; // meters/second

  @HiveField(8)
  final int course; // degrees clockwise from true north

  @HiveField(9)
  final String? status; // INACTIVE, AIRBORNE, GROUNDED

  @HiveField(10)
  final int lastUpdate; // seconds since epoch UTC-0

  @HiveField(11)
  final double? turnRate; // degrees/second

  @HiveField(12)
  final int? verticalRate; // meters/second, positive = climbing

  @HiveField(13)
  final String? beaconType; // UNKNOWN, GLIDER, PARA_GLIDER, etc.

  @HiveField(14)
  final String? transponderType; // ADS-B, etc.

  @HiveField(15)
  final String? remarks; // free text comment

  SafeSkyBeacon({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.altitudeAccuracy,
    this.accuracy,
    this.callSign,
    required this.groundSpeed,
    required this.course,
    this.status,
    required this.lastUpdate,
    this.turnRate,
    this.verticalRate,
    this.beaconType,
    this.transponderType,
    this.remarks,
  });

  /// Get the position as LatLng
  LatLng get position => LatLng(latitude, longitude);

  /// Get altitude in feet
  int get altitudeFt => (altitude * 3.28084).round();

  /// Get ground speed in knots
  int get groundSpeedKnots => (groundSpeed * 1.94384).round();

  /// Get vertical rate in feet per minute
  int? get verticalRateFpm => verticalRate != null 
      ? (verticalRate! * 196.85).round() 
      : null;

  /// Get display name for the beacon
  String get displayName {
    final name = callSign ?? id;
    final type = beaconType ?? 'UNKNOWN';
    return '$type: $name';
  }

  /// Get formatted altitude string
  String get altitudeString => '${altitudeFt}ft';

  /// Get formatted ground speed string
  String get groundSpeedString => '${groundSpeedKnots}kts';

  /// Get formatted vertical rate string
  String get verticalRateString {
    if (verticalRateFpm == null) return '';
    final rate = verticalRateFpm!;
    final direction = rate > 0 ? '↗' : rate < 0 ? '↘' : '→';
    return '$direction${rate.abs()}fpm';
  }

  /// Get formatted course string
  String get courseString => '$course°';

  /// Check if beacon is airborne
  bool get isAirborne => status?.toUpperCase() == 'AIRBORNE';

  /// Check if beacon is on ground
  bool get isGrounded => status?.toUpperCase() == 'GROUNDED';

  /// Check if beacon is inactive
  bool get isInactive => status?.toUpperCase() == 'INACTIVE';

  /// Get status display string
  String get statusString {
    switch (status?.toUpperCase()) {
      case 'AIRBORNE':
        return 'Airborne';
      case 'GROUNDED':
        return 'Grounded';
      case 'INACTIVE':
        return 'Inactive';
      default:
        return 'Unknown';
    }
  }

  /// Get beacon type display string
  String get beaconTypeDisplay {
    switch (beaconType?.toUpperCase()) {
      case 'GLIDER':
        return 'Glider';
      case 'PARA_GLIDER':
        return 'Paraglider';
      case 'HAND_GLIDER':
        return 'Hang Glider';
      case 'HELICOPTER':
        return 'Helicopter';
      case 'UAV':
        return 'UAV/Drone';
      case 'PARACHUTE':
        return 'Parachute';
      case 'MOTORPLANE':
        return 'Motor Plane';
      case 'JET':
        return 'Jet';
      case 'AIRSHIP':
        return 'Airship';
      case 'BALLOON':
        return 'Balloon';
      case 'GYROCOPTER':
        return 'Gyrocopter';
      case 'FLEX_WING_TRIKES':
        return 'Flex Wing Trike';
      case 'PARA_MOTOR':
        return 'Paramotor';
      case 'THREE_AXES_LIGHT_PLANE':
        return 'Light Aircraft';
      case 'PAV':
        return 'Personal Air Vehicle';
      case 'MILITARY':
        return 'Military';
      case 'STATIC_OBJECT':
        return 'Static Object';
      case 'UNKNOWN':
      default:
        return 'Unknown';
    }
  }

  /// Get icon name for the beacon type
  String get iconName {
    switch (beaconType?.toUpperCase()) {
      case 'GLIDER':
        return 'glider';
      case 'PARA_GLIDER':
        return 'paraglider';
      case 'HAND_GLIDER':
        return 'hang_glider';
      case 'HELICOPTER':
        return 'helicopter';
      case 'UAV':
        return 'uav';
      case 'PARACHUTE':
        return 'parachute';
      case 'MOTORPLANE':
        return 'motorplane';
      case 'JET':
        return 'jet';
      case 'AIRSHIP':
        return 'airship';
      case 'BALLOON':
        return 'balloon';
      case 'GYROCOPTER':
        return 'gyrocopter';
      case 'FLEX_WING_TRIKES':
        return 'trike';
      case 'PARA_MOTOR':
        return 'paramotor';
      case 'THREE_AXES_LIGHT_PLANE':
        return 'light_aircraft';
      case 'PAV':
        return 'pav';
      case 'MILITARY':
        return 'military';
      case 'STATIC_OBJECT':
        return 'static_object';
      case 'UNKNOWN':
      default:
        return 'unknown';
    }
  }

  /// Check if the beacon data is recent (within last 60 seconds)
  bool get isRecent {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - lastUpdate) < 60;
  }

  /// Get age of the beacon data in seconds
  int get ageInSeconds {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now - lastUpdate;
  }

  factory SafeSkyBeacon.fromJson(Map<String, dynamic> json) {
    return SafeSkyBeacon(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      altitude: (json['altitude'] ?? 0).toInt(),
      altitudeAccuracy: json['altitude_accuracy']?.toInt(),
      accuracy: json['accuracy']?.toInt(),
      callSign: json['call_sign']?.toString(),
      groundSpeed: (json['ground_speed'] ?? 0).toInt(),
      course: (json['course'] ?? 0).toInt(),
      status: json['status']?.toString(),
      lastUpdate: (json['last_update'] ?? 0).toInt(),
      turnRate: json['turn_rate']?.toDouble(),
      verticalRate: json['vertical_rate']?.toInt(),
      beaconType: json['beacon_type']?.toString(),
      transponderType: json['transponder_type']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'altitude_accuracy': altitudeAccuracy,
      'accuracy': accuracy,
      'call_sign': callSign,
      'ground_speed': groundSpeed,
      'course': course,
      'status': status,
      'last_update': lastUpdate,
      'turn_rate': turnRate,
      'vertical_rate': verticalRate,
      'beacon_type': beaconType,
      'transponder_type': transponderType,
      'remarks': remarks,
    };
  }

  @override
  String get uniqueId => id;

  @override
  LatLngBounds? get boundingBox {
    // Beacons are points, so create a small bounding box around the position
    const delta = 0.001; // Small delta for point features
    return LatLngBounds(
      LatLng(position.latitude - delta, position.longitude - delta),
      LatLng(position.latitude + delta, position.longitude + delta),
    );
  }

  @override
  bool containsPoint(LatLng point) {
    // For point features, check if the point is very close
    const tolerance = 0.001;
    return (point.latitude - position.latitude).abs() < tolerance &&
           (point.longitude - position.longitude).abs() < tolerance;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SafeSkyBeacon && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SafeSkyBeacon{id: $id, callSign: $callSign, type: $beaconType, position: $position, altitude: $altitudeString, status: $statusString}';
  }
}