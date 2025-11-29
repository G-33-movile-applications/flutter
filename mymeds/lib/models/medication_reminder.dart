import 'package:flutter/material.dart';
import 'adherence_event.dart';

/// Represents a medication reminder with recurrence support
class MedicationReminder {
  final String id;
  final String medicineId;
  final String medicineName;
  final TimeOfDay time;
  final RecurrenceType recurrence;
  final Set<DayOfWeek> specificDays;
  final bool isActive;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final int version;

  const MedicationReminder({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.time,
    required this.recurrence,
    this.specificDays = const {},
    this.isActive = true,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.version = 1,
  });

  MedicationReminder copyWith({
    String? id,
    String? medicineId,
    String? medicineName,
    TimeOfDay? time,
    RecurrenceType? recurrence,
    Set<DayOfWeek>? specificDays,
    bool? isActive,
    DateTime? createdAt,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    int? version,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      time: time ?? this.time,
      recurrence: recurrence ?? this.recurrence,
      specificDays: specificDays ?? this.specificDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'recurrence': recurrence.name,
      'specificDays': specificDays.map((d) => d.name).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus.name,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'version': version,
    };
  }

  static MedicationReminder fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    final specificDaysList = (json['specificDays'] as List<dynamic>?) ?? [];
    
    return MedicationReminder(
      id: json['id'] as String,
      medicineId: json['medicineId'] as String,
      medicineName: json['medicineName'] as String,
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      recurrence: RecurrenceType.values.firstWhere(
        (e) => e.name == json['recurrence'],
        orElse: () => RecurrenceType.daily,
      ),
      specificDays: specificDaysList
          .map((d) => DayOfWeek.values.firstWhere(
                (e) => e.name == d,
                orElse: () => DayOfWeek.monday,
              ))
          .toSet(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      version: json['version'] as int? ?? 1,
    );
  }

  String getRecurrenceDisplayText() {
    switch (recurrence) {
      case RecurrenceType.once:
        return 'Una vez';
      case RecurrenceType.daily:
        return 'Diario';
      case RecurrenceType.weekly:
        return 'Semanal';
      case RecurrenceType.specificDays:
        if (specificDays.isEmpty) return 'Días específicos';
        final dayAbbreviations = specificDays.map((d) => d.abbreviation).join(', ');
        return 'Días específicos: $dayAbbreviations';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum RecurrenceType {
  once,
  daily,
  weekly,
  specificDays,
}

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get displayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Lunes';
      case DayOfWeek.tuesday:
        return 'Martes';
      case DayOfWeek.wednesday:
        return 'Miércoles';
      case DayOfWeek.thursday:
        return 'Jueves';
      case DayOfWeek.friday:
        return 'Viernes';
      case DayOfWeek.saturday:
        return 'Sábado';
      case DayOfWeek.sunday:
        return 'Domingo';
    }
  }

  String get abbreviation {
    switch (this) {
      case DayOfWeek.monday:
        return 'L';
      case DayOfWeek.tuesday:
        return 'M';
      case DayOfWeek.wednesday:
        return 'X';
      case DayOfWeek.thursday:
        return 'J';
      case DayOfWeek.friday:
        return 'V';
      case DayOfWeek.saturday:
        return 'S';
      case DayOfWeek.sunday:
        return 'D';
    }
  }

  int get weekdayNumber {
    // DateTime.weekday: Monday = 1, Sunday = 7
    return index + 1;
  }
}
