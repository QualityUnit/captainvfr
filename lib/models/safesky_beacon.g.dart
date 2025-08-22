// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safesky_beacon.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SafeSkyBeaconAdapter extends TypeAdapter<SafeSkyBeacon> {
  @override
  final int typeId = 56;

  @override
  SafeSkyBeacon read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SafeSkyBeacon(
      id: fields[0] as String,
      latitude: fields[1] as double,
      longitude: fields[2] as double,
      altitude: fields[3] as int,
      altitudeAccuracy: fields[4] as int?,
      accuracy: fields[5] as int?,
      callSign: fields[6] as String?,
      groundSpeed: fields[7] as int,
      course: fields[8] as int,
      status: fields[9] as String?,
      lastUpdate: fields[10] as int,
      turnRate: fields[11] as double?,
      verticalRate: fields[12] as int?,
      beaconType: fields[13] as String?,
      transponderType: fields[14] as String?,
      remarks: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SafeSkyBeacon obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.latitude)
      ..writeByte(2)
      ..write(obj.longitude)
      ..writeByte(3)
      ..write(obj.altitude)
      ..writeByte(4)
      ..write(obj.altitudeAccuracy)
      ..writeByte(5)
      ..write(obj.accuracy)
      ..writeByte(6)
      ..write(obj.callSign)
      ..writeByte(7)
      ..write(obj.groundSpeed)
      ..writeByte(8)
      ..write(obj.course)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.lastUpdate)
      ..writeByte(11)
      ..write(obj.turnRate)
      ..writeByte(12)
      ..write(obj.verticalRate)
      ..writeByte(13)
      ..write(obj.beaconType)
      ..writeByte(14)
      ..write(obj.transponderType)
      ..writeByte(15)
      ..write(obj.remarks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafeSkyBeaconAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
