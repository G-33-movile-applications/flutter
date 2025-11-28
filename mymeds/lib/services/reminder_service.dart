import '../models/medication_reminder.dart';
import 'notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Abstract interface for reminder service
abstract class ReminderService {
  Future<List<MedicationReminder>> loadReminders();
  Future<MedicationReminder> createReminder(MedicationReminder reminder);
  Future<MedicationReminder> updateReminder(MedicationReminder reminder);
  Future<void> toggleReminder(String id, bool isActive);
  Future<void> deleteReminder(String id);
  Future<void> testReminderNotification(MedicationReminder reminder);
}

/// In-memory implementation of ReminderService
/// Can be replaced with Firestore implementation later
class InMemoryReminderService implements ReminderService {
  static final InMemoryReminderService _instance = InMemoryReminderService._internal();
  factory InMemoryReminderService() => _instance;
  InMemoryReminderService._internal();

  final NotificationService _notificationService = NotificationService();
  final List<MedicationReminder> _reminders = [];
  final _uuid = const Uuid();

  @override
  Future<List<MedicationReminder>> loadReminders() async {
    // Initialize notification service if not already done
    await _notificationService.init();
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Sort by time
    final sorted = List<MedicationReminder>.from(_reminders);
    sorted.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });

    debugPrint('📋 Loaded ${sorted.length} reminders from memory');
    return sorted;
  }

  @override
  Future<MedicationReminder> createReminder(MedicationReminder reminder) async {
    // Ensure notification service is initialized
    await _notificationService.init();
    
    // Generate ID if needed
    final newReminder = reminder.copyWith(
      id: reminder.id.isEmpty ? _uuid.v4() : reminder.id,
      createdAt: DateTime.now(),
    );

    _reminders.add(newReminder);
    debugPrint('➕ Added reminder to memory: ${newReminder.medicineName} (Total: ${_reminders.length})');

    // Schedule notification if active
    if (newReminder.isActive) {
      await _notificationService.scheduleReminderNotification(newReminder);
    }

    return newReminder;
  }

  @override
  Future<MedicationReminder> updateReminder(MedicationReminder reminder) async {
    // Ensure notification service is initialized
    await _notificationService.init();
    
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) {
      throw Exception('Reminder not found: ${reminder.id}');
    }

    // Cancel old notification
    await _notificationService.cancelReminderNotification(reminder.id);

    // Update reminder
    _reminders[index] = reminder;
    debugPrint('🔄 Updated reminder in memory: ${reminder.medicineName}');

    // Schedule new notification if active
    if (reminder.isActive) {
      await _notificationService.scheduleReminderNotification(reminder);
    }

    return reminder;
  }

  @override
  Future<void> toggleReminder(String id, bool isActive) async {
    // Ensure notification service is initialized
    await _notificationService.init();
    
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) {
      throw Exception('Reminder not found: $id');
    }

    final reminder = _reminders[index].copyWith(isActive: isActive);
    _reminders[index] = reminder;
    debugPrint('🔀 Toggled reminder: ${reminder.medicineName} -> ${isActive ? "ON" : "OFF"}');

    if (isActive) {
      await _notificationService.scheduleReminderNotification(reminder);
    } else {
      await _notificationService.cancelReminderNotification(id);
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    await _notificationService.cancelReminderNotification(id);
    debugPrint('🗑️ Deleted reminder from memory (Total: ${_reminders.length})');
  }

  @override
  Future<void> testReminderNotification(MedicationReminder reminder) async {
    await _notificationService.init();
    await _notificationService.showTestNotification(reminder);
  }
}
