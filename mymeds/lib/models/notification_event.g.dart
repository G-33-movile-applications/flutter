// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationEventAdapter extends TypeAdapter<NotificationEvent> {
  @override
  final int typeId = 20;

  @override
  NotificationEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationEvent(
      id: fields[0] as String,
      type: fields[1] as String,
      timestamp: fields[2] as DateTime,
      result: fields[3] as NotificationResult,
      hourOfDay: fields[4] as int?,
      dayOfWeek: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationEvent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.result)
      ..writeByte(4)
      ..write(obj.hourOfDay)
      ..writeByte(5)
      ..write(obj.dayOfWeek);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
