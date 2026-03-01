// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aircraft_document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AircraftDocumentAdapter extends TypeAdapter<AircraftDocument> {
  @override
  final int typeId = 56;

  @override
  AircraftDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AircraftDocument(
      id: fields[0] as String,
      aircraftId: fields[1] as String,
      name: fields[2] as String,
      documentType: fields[3] as int,
      filePath: fields[4] as String,
      fileType: fields[5] as String?,
      fileSizeBytes: fields[6] as int?,
      expirationDate: fields[7] as DateTime?,
      notes: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      documentNumber: fields[11] as String?,
      issuingAuthority: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AircraftDocument obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.aircraftId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.documentType)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.fileType)
      ..writeByte(6)
      ..write(obj.fileSizeBytes)
      ..writeByte(7)
      ..write(obj.expirationDate)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.documentNumber)
      ..writeByte(12)
      ..write(obj.issuingAuthority);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AircraftDocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
