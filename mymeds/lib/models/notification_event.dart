import 'package:hive/hive.dart';

part 'notification_event.g.dart';

/// Represents the result of a notification interaction
enum NotificationResult {
  opened,
  ignored,
  dismissed,
}

/// Model for tracking notification events locally
/// Used by SmartNotificationService to learn user behavior patterns
@HiveType(typeId: 20) // Choose an unused typeId
class NotificationEvent {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // e.g., 'prescription_reminder', 'order_update', 'delivery_status'

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final NotificationResult result;

  @HiveField(4)
  final int hourOfDay; // Cached for quick P(t) calculations (0-23)

  @HiveField(5)
  final int dayOfWeek; // Cached for pattern analysis (1-7, Monday=1)

  NotificationEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.result,
    int? hourOfDay,
    int? dayOfWeek,
  })  : hourOfDay = hourOfDay ?? timestamp.hour,
        dayOfWeek = dayOfWeek ?? timestamp.weekday;

  /// Factory constructor for creating a new event
  factory NotificationEvent.create({
    required String type,
    required NotificationResult result,
    DateTime? timestamp,
  }) {
    final eventTime = timestamp ?? DateTime.now();
    return NotificationEvent(
      id: '${eventTime.millisecondsSinceEpoch}_$type',
      type: type,
      timestamp: eventTime,
      result: result,
      hourOfDay: eventTime.hour,
      dayOfWeek: eventTime.weekday,
    );
  }

  /// Check if the event represents an opened notification
  bool get wasOpened => result == NotificationResult.opened;

  /// Check if the event was ignored (not interacted with)
  bool get wasIgnored => result == NotificationResult.ignored;

  /// Check if the event was dismissed without opening
  bool get wasDismissed => result == NotificationResult.dismissed;

  /// Get the time slot (2-hour blocks: 0-23 in 2-hour increments)
  int get timeSlot => (hourOfDay ~/ 2) * 2;

  /// Get a human-readable time slot description
  String get timeSlotDescription {
    final end = timeSlot + 2;
    return '${timeSlot.toString().padLeft(2, '0')}:00-${end.toString().padLeft(2, '0')}:00';
  }

  @override
  String toString() {
    return 'NotificationEvent(id: $id, type: $type, timestamp: $timestamp, result: $result, slot: $timeSlotDescription)';
  }

  /// Convert to JSON for analytics (optional)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'result': result.name,
      'hourOfDay': hourOfDay,
      'dayOfWeek': dayOfWeek,
      'timeSlot': timeSlot,
    };
  }

  /// Create from JSON
  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      result: NotificationResult.values.firstWhere(
        (e) => e.name == json['result'],
      ),
      hourOfDay: json['hourOfDay'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
    );
  }
}

/// Adapter for NotificationResult enum
class NotificationResultAdapter extends TypeAdapter<NotificationResult> {
  @override
  final int typeId = 21; // Choose an unused typeId

  @override
  NotificationResult read(BinaryReader reader) {
    final index = reader.readByte();
    return NotificationResult.values[index];
  }

  @override
  void write(BinaryWriter writer, NotificationResult obj) {
    writer.writeByte(obj.index);
  }
}
