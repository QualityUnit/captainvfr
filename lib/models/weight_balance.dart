import 'package:hive/hive.dart';

part 'weight_balance.g.dart';

/// Represents a loading station in the aircraft (seat, baggage, fuel tank, etc.)
@HiveType(typeId: 50)
class LoadingStation extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g., "Pilot", "Front Passenger", "Rear Seat", "Baggage"

  @HiveField(2)
  double momentArm; // Distance from datum in inches

  @HiveField(3)
  double maxWeight; // Maximum weight for this station in pounds

  @HiveField(4)
  double currentWeight; // Current weight loaded at this station

  @HiveField(5)
  String type; // seat, baggage, fuel, equipment

  @HiveField(6)
  int order; // Display order

  LoadingStation({
    required this.id,
    required this.name,
    required this.momentArm,
    required this.maxWeight,
    this.currentWeight = 0,
    this.type = 'seat',
    this.order = 0,
  });

  double get moment => currentWeight * momentArm;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'moment_arm': momentArm,
      'max_weight': maxWeight,
      'current_weight': currentWeight,
      'type': type,
      'order': order,
    };
  }

  factory LoadingStation.fromMap(Map<String, dynamic> map) {
    return LoadingStation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      momentArm: (map['moment_arm'] ?? 0).toDouble(),
      maxWeight: (map['max_weight'] ?? 0).toDouble(),
      currentWeight: (map['current_weight'] ?? 0).toDouble(),
      type: map['type'] ?? 'seat',
      order: map['order'] ?? 0,
    );
  }

  LoadingStation copyWith({
    String? id,
    String? name,
    double? momentArm,
    double? maxWeight,
    double? currentWeight,
    String? type,
    int? order,
  }) {
    return LoadingStation(
      id: id ?? this.id,
      name: name ?? this.name,
      momentArm: momentArm ?? this.momentArm,
      maxWeight: maxWeight ?? this.maxWeight,
      currentWeight: currentWeight ?? this.currentWeight,
      type: type ?? this.type,
      order: order ?? this.order,
    );
  }
}

/// Represents a point on the CG envelope diagram
@HiveType(typeId: 51)
class CGEnvelopePoint extends HiveObject {
  @HiveField(0)
  double weight; // Weight in pounds

  @HiveField(1)
  double cgPosition; // CG position in inches from datum

  CGEnvelopePoint({
    required this.weight,
    required this.cgPosition,
  });

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'cg_position': cgPosition,
    };
  }

  factory CGEnvelopePoint.fromMap(Map<String, dynamic> map) {
    return CGEnvelopePoint(
      weight: (map['weight'] ?? 0).toDouble(),
      cgPosition: (map['cg_position'] ?? 0).toDouble(),
    );
  }
}

/// Represents a saved loading configuration template
@HiveType(typeId: 52)
class LoadingTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g., "Solo", "With Passenger", "Full Baggage"

  @HiveField(2)
  String description;

  @HiveField(3)
  Map<String, double> stationWeights; // Station ID -> Weight

  @HiveField(4)
  DateTime createdAt;

  LoadingTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.stationWeights,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'station_weights': stationWeights,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LoadingTemplate.fromMap(Map<String, dynamic> map) {
    return LoadingTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      stationWeights: Map<String, double>.from(map['station_weights'] ?? {}),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

/// Weight & Balance calculation result
class WeightBalanceResult {
  final double totalWeight;
  final double totalMoment;
  final double cgPosition;
  final bool isWithinLimits;
  final String? warningMessage;
  final List<LoadingStation> stations;

  WeightBalanceResult({
    required this.totalWeight,
    required this.totalMoment,
    required this.cgPosition,
    required this.isWithinLimits,
    this.warningMessage,
    required this.stations,
  });

  double get cgPositionPercent {
    // Calculate CG as percentage of MAC (Mean Aerodynamic Chord) if applicable
    return cgPosition;
  }
}

/// Cruise performance profile for different altitudes
@HiveType(typeId: 53)
class CruisePerformanceProfile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int altitude; // in feet MSL

  @HiveField(2)
  int trueAirspeed; // in knots

  @HiveField(3)
  double fuelBurn; // gallons per hour

  @HiveField(4)
  int powerSetting; // RPM or % power

  @HiveField(5)
  String powerSettingType; // rpm, percent, manifold_pressure

  @HiveField(6)
  String? notes;

  CruisePerformanceProfile({
    required this.id,
    required this.altitude,
    required this.trueAirspeed,
    required this.fuelBurn,
    required this.powerSetting,
    this.powerSettingType = 'rpm',
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'altitude': altitude,
      'true_airspeed': trueAirspeed,
      'fuel_burn': fuelBurn,
      'power_setting': powerSetting,
      'power_setting_type': powerSettingType,
      'notes': notes,
    };
  }

  factory CruisePerformanceProfile.fromMap(Map<String, dynamic> map) {
    return CruisePerformanceProfile(
      id: map['id'] ?? '',
      altitude: map['altitude'] ?? 0,
      trueAirspeed: map['true_airspeed'] ?? 0,
      fuelBurn: (map['fuel_burn'] ?? 0).toDouble(),
      powerSetting: map['power_setting'] ?? 0,
      powerSettingType: map['power_setting_type'] ?? 'rpm',
      notes: map['notes'],
    );
  }
}
