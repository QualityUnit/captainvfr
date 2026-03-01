// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceItemAdapter extends TypeAdapter<MaintenanceItem> {
  @override
  final int typeId = 54;

  @override
  MaintenanceItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceItem(
      id: fields[0] as String,
      aircraftId: fields[1] as String,
      name: fields[2] as String,
      description: fields[3] as String,
      maintenanceType: fields[4] as int,
      lastCompletedDate: fields[5] as DateTime?,
      lastCompletedHours: fields[6] as double?,
      lastCompletedCycles: fields[7] as int?,
      intervalDays: fields[8] as int?,
      intervalHours: fields[9] as double?,
      intervalCycles: fields[10] as int?,
      isRecurring: fields[11] as bool,
      nextDueDate: fields[12] as DateTime?,
      nextDueHours: fields[13] as double?,
      nextDueCycles: fields[14] as int?,
      notes: fields[15] as String?,
      isCompleted: fields[16] as bool,
      createdAt: fields[17] as DateTime,
      updatedAt: fields[18] as DateTime,
      adNumber: fields[19] as String?,
      isRecurringAD: fields[20] as bool?,
      complianceMethod: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceItem obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.aircraftId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.maintenanceType)
      ..writeByte(5)
      ..write(obj.lastCompletedDate)
      ..writeByte(6)
      ..write(obj.lastCompletedHours)
      ..writeByte(7)
      ..write(obj.lastCompletedCycles)
      ..writeByte(8)
      ..write(obj.intervalDays)
      ..writeByte(9)
      ..write(obj.intervalHours)
      ..writeByte(10)
      ..write(obj.intervalCycles)
      ..writeByte(11)
      ..write(obj.isRecurring)
      ..writeByte(12)
      ..write(obj.nextDueDate)
      ..writeByte(13)
      ..write(obj.nextDueHours)
      ..writeByte(14)
      ..write(obj.nextDueCycles)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.isCompleted)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.adNumber)
      ..writeByte(20)
      ..write(obj.isRecurringAD)
      ..writeByte(21)
      ..write(obj.complianceMethod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MaintenanceRecordAdapter extends TypeAdapter<MaintenanceRecord> {
  @override
  final int typeId = 55;

  @override
  MaintenanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceRecord(
      id: fields[0] as String,
      aircraftId: fields[1] as String,
      maintenanceItemId: fields[2] as String?,
      date: fields[3] as DateTime,
      aircraftHours: fields[4] as double?,
      description: fields[5] as String,
      facility: fields[6] as String?,
      cost: fields[7] as double?,
      notes: fields[8] as String?,
      documentPaths: (fields[9] as List?)?.cast<String>(),
      createdAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.aircraftId)
      ..writeByte(2)
      ..write(obj.maintenanceItemId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.aircraftHours)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.facility)
      ..writeByte(7)
      ..write(obj.cost)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.documentPaths)
      ..writeByte(10)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
