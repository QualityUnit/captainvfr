// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'airspace_frequency.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AirspaceFrequencyAdapter extends TypeAdapter<AirspaceFrequency> {
  @override
  final int typeId = 31;

  @override
  AirspaceFrequency read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AirspaceFrequency(
      frequency: fields[0] as double,
      type: fields[1] as String,
      description: fields[2] as String?,
      callsign: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AirspaceFrequency obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.frequency)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.callsign);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AirspaceFrequencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
