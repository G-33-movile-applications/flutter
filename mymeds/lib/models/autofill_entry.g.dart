// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autofill_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AutofillEntryAdapter extends TypeAdapter<AutofillEntry> {
  @override
  final int typeId = 5;

  @override
  AutofillEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AutofillEntry(
      entity: fields[0] as String,
      field: fields[1] as String,
      value: fields[2] as String,
      count: fields[3] as int,
      lastUsed: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AutofillEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.entity)
      ..writeByte(1)
      ..write(obj.field)
      ..writeByte(2)
      ..write(obj.value)
      ..writeByte(3)
      ..write(obj.count)
      ..writeByte(4)
      ..write(obj.lastUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutofillEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
