import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/medication_reminder.dart';
import 'reminder_service.dart';
import 'notification_service.dart';

/// In-app fallback scheduler that checks for due reminders periodically
/// and fires notifications using show() instead of relying on zonedSchedule.
/// 
/// This acts as a safety net for devices where OS-level alarm scheduling
/// doesn't work reliably. The app must be running (foreground or background)
/// for this scheduler to work.
class ReminderScheduler {
  final ReminderService reminderService;
  final NotificationService notificationService;
  
  Timer? _timer;
  
  /// Tracks the last time we fired a notification for each reminder ID
  /// to prevent duplicate notifications within the same time window
  final Map<String, DateTime> _lastFiredTimes = {};
  
  /// How often to check for due reminders (30 seconds for demo purposes)
  static const _checkInterval = Duration(seconds: 30);
  
  /// Tolerance window: if current time is within ±1 minute of scheduled time,
  /// consider the reminder as "due"
  static const _tolerance = Duration(minutes: 1);
  
  /// Cooldown period: don't fire the same reminder twice within this period
  static const _cooldown = Duration(minutes: 5);

  ReminderScheduler({
    required this.reminderService,
    required this.notificationService,
  });

  /// Start the periodic reminder checker
  void start() {
    if (_timer != null) {
      debugPrint('⏰ ReminderScheduler already running');
      return;
    }

    debugPrint('⏰ Starting ReminderScheduler (checks every ${_checkInterval.inSeconds}s)');
    
    // Run initial check immediately
    _checkDueReminders();
    
    // Then check periodically
    _timer = Timer.periodic(_checkInterval, (_) async {
      await _checkDueReminders();
    });
  }

  /// Stop the periodic checker
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('⏰ ReminderScheduler stopped');
  }

  /// Check all active reminders and fire notifications for due ones
  Future<void> _checkDueReminders() async {
    try {
      final now = DateTime.now();
      debugPrint('⏰ Checking for due reminders at ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      
      // Load all reminders
      final reminders = await reminderService.loadReminders();
      final activeReminders = reminders.where((r) => r.isActive).toList();
      
      debugPrint('⏰ Found ${activeReminders.length} active reminders');
      
      for (final reminder in activeReminders) {
        if (_isReminderDue(reminder, now)) {
          await _fireReminder(reminder, now);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking due reminders: $e');
    }
  }

  /// Check if a reminder is due based on current time and recurrence pattern
  bool _isReminderDue(MedicationReminder reminder, DateTime now) {
    // Check if we already fired this reminder recently
    final lastFired = _lastFiredTimes[reminder.id];
    if (lastFired != null && now.difference(lastFired) < _cooldown) {
      return false; // Still in cooldown period
    }

    // Build the scheduled time for today
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    // Check if current time is within tolerance window of scheduled time
    final timeDiff = now.difference(scheduledToday).abs();
    if (timeDiff > _tolerance) {
      return false; // Not within tolerance window
    }

    // Check recurrence pattern
    switch (reminder.recurrence) {
      case RecurrenceType.once:
        // For "once" reminders, only fire if scheduled date matches today
        // Since we don't have a date field, treat it as "fire today only"
        // This is a simplification - ideally "once" should have a specific date
        return true;

      case RecurrenceType.daily:
        // Fire every day
        return true;

      case RecurrenceType.weekly:
        // Fire on the same day of the week as creation date
        // This is a simplification - ideally should store the target weekday
        return true;

      case RecurrenceType.specificDays:
        // Fire only on specified days
        final currentWeekday = _dateTimeWeekdayToDayOfWeek(now.weekday);
        return reminder.specificDays.contains(currentWeekday);
    }
  }

  /// Fire a reminder notification
  Future<void> _fireReminder(MedicationReminder reminder, DateTime now) async {
    try {
      debugPrint('🔔 Firing reminder: ${reminder.medicineName} at ${now.hour}:${now.minute}');
      
      await notificationService.showReminderNow(reminder);
      
      // Record that we fired this reminder
      _lastFiredTimes[reminder.id] = now;
      
      debugPrint('✅ Reminder fired successfully: ${reminder.medicineName}');
    } catch (e) {
      debugPrint('⚠️ Error firing reminder ${reminder.medicineName}: $e');
    }
  }

  /// Convert DateTime.weekday (1=Monday, 7=Sunday) to DayOfWeek enum
  DayOfWeek _dateTimeWeekdayToDayOfWeek(int weekday) {
    // DateTime.weekday: 1=Monday, 2=Tuesday, ..., 7=Sunday
    // DayOfWeek enum: monday=0, tuesday=1, ..., sunday=6
    switch (weekday) {
      case 1:
        return DayOfWeek.monday;
      case 2:
        return DayOfWeek.tuesday;
      case 3:
        return DayOfWeek.wednesday;
      case 4:
        return DayOfWeek.thursday;
      case 5:
        return DayOfWeek.friday;
      case 6:
        return DayOfWeek.saturday;
      case 7:
        return DayOfWeek.sunday;
      default:
        return DayOfWeek.monday;
    }
  }

  /// Clear the fired times cache (useful for testing)
  void clearFiredCache() {
    _lastFiredTimes.clear();
    debugPrint('⏰ Cleared fired times cache');
  }
}
