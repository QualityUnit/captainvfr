import 'package:hive/hive.dart';

part 'model.g.dart';

@HiveType(typeId: 22)
enum AircraftCategory {
  @HiveField(0)
  singleEngine,
  @HiveField(1)
  multiEngine,
  @HiveField(2)
  jet,
  @HiveField(3)
  helicopter,
  @HiveField(4)
  glider,
  @HiveField(5)
  turboprop,
}

@HiveType(typeId: 24)
class Model extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String manufacturerId;

  @HiveField(3)
  AircraftCategory category;

  @HiveField(4)
  int engineCount;

  @HiveField(5)
  int maxSeats;

  @HiveField(6)
  int typicalCruiseSpeed; // in knots

  @HiveField(7)
  int typicalServiceCeiling; // in feet

  @HiveField(8)
  String? description;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  double? fuelConsumption; // gallons per hour

  @HiveField(12)
  int? maximumClimbRate; // feet per minute

  @HiveField(13)
  int? maximumDescentRate; // feet per minute

  @HiveField(14)
  int? maxTakeoffWeight; // in pounds

  @HiveField(15)
  int? maxLandingWeight; // in pounds

  @HiveField(16)
  int? fuelCapacity; // in gallons

  Model({
    required this.id,
    required this.name,
    required this.manufacturerId,
    required this.category,
    required this.engineCount,
    required this.maxSeats,
    required this.typicalCruiseSpeed,
    required this.typicalServiceCeiling,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.fuelConsumption,
    this.maximumClimbRate,
    this.maximumDescentRate,
    this.maxTakeoffWeight,
    this.maxLandingWeight,
    this.fuelCapacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'manufacturer_id': manufacturerId,
      'category': category.index,
      'engine_count': engineCount,
      'max_seats': maxSeats,
      'typical_cruise_speed': typicalCruiseSpeed,
      'typical_service_ceiling': typicalServiceCeiling,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'fuel_consumption': fuelConsumption,
      'maximum_climb_rate': maximumClimbRate,
      'maximum_descent_rate': maximumDescentRate,
      'max_takeoff_weight': maxTakeoffWeight,
      'max_landing_weight': maxLandingWeight,
      'fuel_capacity': fuelCapacity,
    };
  }

  factory Model.fromMap(Map<String, dynamic> map) {
    return Model(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      manufacturerId: map['manufacturer_id'] ?? '',
      category: AircraftCategory.values[map['category'] ?? 0],
      engineCount: map['engine_count'] ?? 1,
      maxSeats: map['max_seats'] ?? 2,
      typicalCruiseSpeed: (map['typical_cruise_speed'] ?? 0).toInt(),
      typicalServiceCeiling: (map['typical_service_ceiling'] ?? 0).toInt(),
      description: map['description'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      fuelConsumption: map['fuel_consumption']?.toDouble(),
      maximumClimbRate: map['maximum_climb_rate']?.toInt(),
      maximumDescentRate: map['maximum_descent_rate']?.toInt(),
      maxTakeoffWeight: map['max_takeoff_weight']?.toInt(),
      maxLandingWeight: map['max_landing_weight']?.toInt(),
      fuelCapacity: map['fuel_capacity']?.toInt(),
    );
  }

  Model copyWith({
    String? id,
    String? name,
    String? manufacturerId,
    AircraftCategory? category,
    int? engineCount,
    int? maxSeats,
    int? typicalCruiseSpeed,
    int? typicalServiceCeiling,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? fuelConsumption,
    int? maximumClimbRate,
    int? maximumDescentRate,
    int? maxTakeoffWeight,
    int? maxLandingWeight,
    int? fuelCapacity,
  }) {
    return Model(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      category: category ?? this.category,
      engineCount: engineCount ?? this.engineCount,
      maxSeats: maxSeats ?? this.maxSeats,
      typicalCruiseSpeed: typicalCruiseSpeed ?? this.typicalCruiseSpeed,
      typicalServiceCeiling:
          typicalServiceCeiling ?? this.typicalServiceCeiling,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      maximumClimbRate: maximumClimbRate ?? this.maximumClimbRate,
      maximumDescentRate: maximumDescentRate ?? this.maximumDescentRate,
      maxTakeoffWeight: maxTakeoffWeight ?? this.maxTakeoffWeight,
      maxLandingWeight: maxLandingWeight ?? this.maxLandingWeight,
      fuelCapacity: fuelCapacity ?? this.fuelCapacity,
    );
  }

  @override
  String toString() {
    return 'Model{id: $id, name: $name, manufacturerId: $manufacturerId, category: $category}';
  }
}
