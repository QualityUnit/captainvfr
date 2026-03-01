// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_balance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoadingStationAdapter extends TypeAdapter<LoadingStation> {
  @override
  final int typeId = 50;

  @override
  LoadingStation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoadingStation(
      id: fields[0] as String,
      name: fields[1] as String,
      momentArm: fields[2] as double,
      maxWeight: fields[3] as double,
      currentWeight: fields[4] as double,
      type: fields[5] as String,
      order: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LoadingStation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.momentArm)
      ..writeByte(3)
      ..write(obj.maxWeight)
      ..writeByte(4)
      ..write(obj.currentWeight)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingStationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CGEnvelopePointAdapter extends TypeAdapter<CGEnvelopePoint> {
  @override
  final int typeId = 51;

  @override
  CGEnvelopePoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CGEnvelopePoint(
      weight: fields[0] as double,
      cgPosition: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CGEnvelopePoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.weight)
      ..writeByte(1)
      ..write(obj.cgPosition);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CGEnvelopePointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LoadingTemplateAdapter extends TypeAdapter<LoadingTemplate> {
  @override
  final int typeId = 52;

  @override
  LoadingTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoadingTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      stationWeights: (fields[3] as Map).cast<String, double>(),
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LoadingTemplate obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.stationWeights)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CruisePerformanceProfileAdapter
    extends TypeAdapter<CruisePerformanceProfile> {
  @override
  final int typeId = 53;

  @override
  CruisePerformanceProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CruisePerformanceProfile(
      id: fields[0] as String,
      altitude: fields[1] as int,
      trueAirspeed: fields[2] as int,
      fuelBurn: fields[3] as double,
      powerSetting: fields[4] as int,
      powerSettingType: fields[5] as String,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CruisePerformanceProfile obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.altitude)
      ..writeByte(2)
      ..write(obj.trueAirspeed)
      ..writeByte(3)
      ..write(obj.fuelBurn)
      ..writeByte(4)
      ..write(obj.powerSetting)
      ..writeByte(5)
      ..write(obj.powerSettingType)
      ..writeByte(6)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CruisePerformanceProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
