import 'package:hive/hive.dart';

part 'maintenance.g.dart';

/// Type of maintenance item
enum MaintenanceType {
  calendar, // Based on date (annual, biennial)
  hours, // Based on flight hours (100-hour, oil change)
  cycles, // Based on cycles (landing gear, prop)
  ad, // Airworthiness Directive
}

/// Maintenance item for an aircraft
@HiveType(typeId: 54)
class MaintenanceItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String aircraftId;

  @HiveField(2)
  String name; // e.g., "Annual Inspection", "Oil Change", "100-Hour"

  @HiveField(3)
  String description;

  @HiveField(4)
  int maintenanceType; // MaintenanceType enum index

  @HiveField(5)
  DateTime? lastCompletedDate;

  @HiveField(6)
  double? lastCompletedHours; // Aircraft hours when last completed

  @HiveField(7)
  int? lastCompletedCycles; // Cycles when last completed

  @HiveField(8)
  int? intervalDays; // For calendar-based items

  @HiveField(9)
  double? intervalHours; // For hour-based items

  @HiveField(10)
  int? intervalCycles; // For cycle-based items

  @HiveField(11)
  bool isRecurring;

  @HiveField(12)
  DateTime? nextDueDate;

  @HiveField(13)
  double? nextDueHours;

  @HiveField(14)
  int? nextDueCycles;

  @HiveField(15)
  String? notes;

  @HiveField(16)
  bool isCompleted;

  @HiveField(17)
  DateTime createdAt;

  @HiveField(18)
  DateTime updatedAt;

  // AD-specific fields
  @HiveField(19)
  String? adNumber; // e.g., "AD 2023-01-01"

  @HiveField(20)
  bool? isRecurringAD;

  @HiveField(21)
  String? complianceMethod; // How the AD was complied with

  MaintenanceItem({
    required this.id,
    required this.aircraftId,
    required this.name,
    required this.description,
    required this.maintenanceType,
    this.lastCompletedDate,
    this.lastCompletedHours,
    this.lastCompletedCycles,
    this.intervalDays,
    this.intervalHours,
    this.intervalCycles,
    this.isRecurring = true,
    this.nextDueDate,
    this.nextDueHours,
    this.nextDueCycles,
    this.notes,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.adNumber,
    this.isRecurringAD,
    this.complianceMethod,
  });

  MaintenanceType get type => MaintenanceType.values[maintenanceType];

  /// Calculate days until due (for calendar-based items)
  int? get daysUntilDue {
    if (nextDueDate == null) return null;
    return nextDueDate!.difference(DateTime.now()).inDays;
  }

  /// Calculate hours until due (for hour-based items)
  double? hoursUntilDue(double currentHours) {
    if (nextDueHours == null) return null;
    return nextDueHours! - currentHours;
  }

  /// Check if maintenance is overdue
  bool isOverdue(double? currentHours) {
    if (type == MaintenanceType.calendar && nextDueDate != null) {
      return DateTime.now().isAfter(nextDueDate!);
    }
    if (type == MaintenanceType.hours && nextDueHours != null && currentHours != null) {
      return currentHours >= nextDueHours!;
    }
    return false;
  }

  /// Check if maintenance is due soon (within warning threshold)
  bool isDueSoon(double? currentHours, {int warningDays = 30, double warningHours = 10}) {
    if (type == MaintenanceType.calendar && nextDueDate != null) {
      final daysUntil = daysUntilDue;
      return daysUntil != null && daysUntil <= warningDays && daysUntil > 0;
    }
    if (type == MaintenanceType.hours && nextDueHours != null && currentHours != null) {
      final hoursUntil = hoursUntilDue(currentHours);
      return hoursUntil != null && hoursUntil <= warningHours && hoursUntil > 0;
    }
    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aircraft_id': aircraftId,
      'name': name,
      'description': description,
      'maintenance_type': maintenanceType,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
      'last_completed_hours': lastCompletedHours,
      'last_completed_cycles': lastCompletedCycles,
      'interval_days': intervalDays,
      'interval_hours': intervalHours,
      'interval_cycles': intervalCycles,
      'is_recurring': isRecurring,
      'next_due_date': nextDueDate?.toIso8601String(),
      'next_due_hours': nextDueHours,
      'next_due_cycles': nextDueCycles,
      'notes': notes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'ad_number': adNumber,
      'is_recurring_ad': isRecurringAD,
      'compliance_method': complianceMethod,
    };
  }

  factory MaintenanceItem.fromMap(Map<String, dynamic> map) {
    return MaintenanceItem(
      id: map['id'] ?? '',
      aircraftId: map['aircraft_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      maintenanceType: map['maintenance_type'] ?? 0,
      lastCompletedDate: map['last_completed_date'] != null
          ? DateTime.parse(map['last_completed_date'])
          : null,
      lastCompletedHours: map['last_completed_hours']?.toDouble(),
      lastCompletedCycles: map['last_completed_cycles'],
      intervalDays: map['interval_days'],
      intervalHours: map['interval_hours']?.toDouble(),
      intervalCycles: map['interval_cycles'],
      isRecurring: map['is_recurring'] ?? true,
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'])
          : null,
      nextDueHours: map['next_due_hours']?.toDouble(),
      nextDueCycles: map['next_due_cycles'],
      notes: map['notes'],
      isCompleted: map['is_completed'] ?? false,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      adNumber: map['ad_number'],
      isRecurringAD: map['is_recurring_ad'],
      complianceMethod: map['compliance_method'],
    );
  }

  MaintenanceItem copyWith({
    String? id,
    String? aircraftId,
    String? name,
    String? description,
    int? maintenanceType,
    DateTime? lastCompletedDate,
    double? lastCompletedHours,
    int? lastCompletedCycles,
    int? intervalDays,
    double? intervalHours,
    int? intervalCycles,
    bool? isRecurring,
    DateTime? nextDueDate,
    double? nextDueHours,
    int? nextDueCycles,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adNumber,
    bool? isRecurringAD,
    String? complianceMethod,
  }) {
    return MaintenanceItem(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      name: name ?? this.name,
      description: description ?? this.description,
      maintenanceType: maintenanceType ?? this.maintenanceType,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      lastCompletedHours: lastCompletedHours ?? this.lastCompletedHours,
      lastCompletedCycles: lastCompletedCycles ?? this.lastCompletedCycles,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalHours: intervalHours ?? this.intervalHours,
      intervalCycles: intervalCycles ?? this.intervalCycles,
      isRecurring: isRecurring ?? this.isRecurring,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      nextDueHours: nextDueHours ?? this.nextDueHours,
      nextDueCycles: nextDueCycles ?? this.nextDueCycles,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adNumber: adNumber ?? this.adNumber,
      isRecurringAD: isRecurringAD ?? this.isRecurringAD,
      complianceMethod: complianceMethod ?? this.complianceMethod,
    );
  }
}

/// Maintenance history record
@HiveType(typeId: 55)
class MaintenanceRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String aircraftId;

  @HiveField(2)
  String? maintenanceItemId; // Link to MaintenanceItem if applicable

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  double? aircraftHours; // Aircraft hours at time of maintenance

  @HiveField(5)
  String description;

  @HiveField(6)
  String? facility; // Shop or mechanic name

  @HiveField(7)
  double? cost;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  List<String>? documentPaths; // Receipts, work orders, etc.

  @HiveField(10)
  DateTime createdAt;

  MaintenanceRecord({
    required this.id,
    required this.aircraftId,
    this.maintenanceItemId,
    required this.date,
    this.aircraftHours,
    required this.description,
    this.facility,
    this.cost,
    this.notes,
    this.documentPaths,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aircraft_id': aircraftId,
      'maintenance_item_id': maintenanceItemId,
      'date': date.toIso8601String(),
      'aircraft_hours': aircraftHours,
      'description': description,
      'facility': facility,
      'cost': cost,
      'notes': notes,
      'document_paths': documentPaths,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] ?? '',
      aircraftId: map['aircraft_id'] ?? '',
      maintenanceItemId: map['maintenance_item_id'],
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      aircraftHours: map['aircraft_hours']?.toDouble(),
      description: map['description'] ?? '',
      facility: map['facility'],
      cost: map['cost']?.toDouble(),
      notes: map['notes'],
      documentPaths: (map['document_paths'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
