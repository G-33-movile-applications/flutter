import '../models/medication_reminder.dart';
import '../models/adherence_event.dart';
import '../repositories/reminder_repository.dart';
import 'notification_service.dart';
import 'reminders_cache_service.dart';
import 'connectivity_service.dart';
import 'user_session.dart';
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

/// Firestore-backed implementation of ReminderService
/// Stores reminders in Firestore with offline-first architecture
class InMemoryReminderService implements ReminderService {
  static final InMemoryReminderService _instance = InMemoryReminderService._internal();
  factory InMemoryReminderService() => _instance;
  InMemoryReminderService._internal();

  final NotificationService _notificationService = NotificationService();
  final ReminderRepository _repository = ReminderRepository();
  final RemindersCacheService _cache = RemindersCacheService();
  final ConnectivityService _connectivity = ConnectivityService();
  final _uuid = const Uuid();

  @override
  Future<List<MedicationReminder>> loadReminders() async {
    // Initialize notification service if not already done
    await _notificationService.init();
    
    // Get current user ID
    final userId = UserSession().currentUser.value?.uid;
    if (userId == null) {
      debugPrint('⚠️ [ReminderService] No user logged in');
      return [];
    }
    
    try {
      // Fetch from Firestore
      final reminders = await _repository.getUserReminders(userId);
      
      // Auto-deactivate expired "once" reminders
      final updatedReminders = await _autoDeactivateExpiredOnceReminders(userId, reminders);

      // Sort by time
      updatedReminders.sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

      debugPrint('📋 Loaded ${updatedReminders.length} reminders from Firestore');
      return updatedReminders;
    } catch (e) {
      debugPrint('❌ [ReminderService] Error loading reminders: $e');
      rethrow;
    }
  }

  /// Automatically deactivate "once" reminders that have passed their scheduled time
  Future<List<MedicationReminder>> _autoDeactivateExpiredOnceReminders(
    String userId,
    List<MedicationReminder> reminders,
  ) async {
    final now = DateTime.now();
    int deactivatedCount = 0;
    final updatedReminders = <MedicationReminder>[];

    for (final reminder in reminders) {
      // Only process active "once" reminders
      if (reminder.recurrence == RecurrenceType.once && reminder.isActive) {
        // Check if the scheduled time has passed
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          reminder.time.hour,
          reminder.time.minute,
        );

        // If scheduled time is in the past (with 1 minute buffer), deactivate
        if (scheduledTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
          final deactivated = reminder.copyWith(isActive: false);
          try {
            await _repository.updateReminder(userId, deactivated);
            await _notificationService.cancelReminderNotification(reminder.id);
            updatedReminders.add(deactivated);
            deactivatedCount++;
            debugPrint('⏰ Auto-deactivated expired "once" reminder: ${reminder.medicineName}');
          } catch (e) {
            debugPrint('❌ Error deactivating reminder: $e');
            updatedReminders.add(reminder); // Keep original on error
          }
        } else {
          updatedReminders.add(reminder);
        }
      } else {
        updatedReminders.add(reminder);
      }
    }

    if (deactivatedCount > 0) {
      debugPrint('✅ Auto-deactivated $deactivatedCount expired "once" reminder(s)');
    }
    
    return updatedReminders;
  }

  @override
  Future<MedicationReminder> createReminder(MedicationReminder reminder) async {
    // Ensure notification service is initialized
    await _notificationService.init();
    
    // Get current user ID
    final userId = UserSession().currentUser.value?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }
    
    // Check connectivity to determine sync status
    final isOnline = await _connectivity.checkConnectivity();
    
    // Generate ID if needed and set sync metadata
    final newReminder = reminder.copyWith(
      id: reminder.id.isEmpty ? _uuid.v4() : reminder.id,
      createdAt: DateTime.now(),
      syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pending,
      lastSyncedAt: isOnline ? DateTime.now() : null,
    );

    try {
      // Save to Firestore if online, otherwise will be synced later
      if (isOnline) {
        await _repository.createReminder(userId, newReminder);
      } else {
        // Cache locally for offline access
        await _cache.cacheReminders(userId, [newReminder]);
      }
      
      debugPrint('➕ Created reminder: ${newReminder.medicineName} (SyncStatus: ${newReminder.syncStatus.name})');

      // Schedule notification if active
      if (newReminder.isActive) {
        await _notificationService.scheduleReminderNotification(newReminder);
      }

      return newReminder;
    } catch (e) {
      debugPrint('❌ [ReminderService] Error creating reminder: $e');
      rethrow;
    }
  }

  @override
  Future<MedicationReminder> updateReminder(MedicationReminder reminder) async {
    // Ensure notification service is initialized
    await _notificationService.init();
    
    // Get current user ID
    final userId = UserSession().currentUser.value?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }

    // Check connectivity to determine sync status
    final isOnline = await _connectivity.checkConnectivity();
    
    // Cancel old notification
    await _notificationService.cancelReminderNotification(reminder.id);

    // Update reminder with incremented version and sync status
    final updatedReminder = reminder.copyWith(
      version: reminder.version + 1,
      syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pending,
      lastSyncedAt: isOnline ? DateTime.now() : reminder.lastSyncedAt,
    );
    
    try {
      // Update in Firestore if online
      if (isOnline) {
        await _repository.updateReminder(userId, updatedReminder);
      } else {
        // Cache locally for offline access
        await _cache.cacheReminders(userId, [updatedReminder]);
      }
      
      debugPrint('🔄 Updated reminder: ${updatedReminder.medicineName} (SyncStatus: ${updatedReminder.syncStatus.name})');

      // Schedule new notification if active
      if (updatedReminder.isActive) {
        await _notificationService.scheduleReminderNotification(updatedReminder);
      }

      return updatedReminder;
    } catch (e) {
      debugPrint('❌ [ReminderService] Error updating reminder: $e');
      rethrow;
    }
  }

  @override
  Future<void> toggleReminder(String id, bool isActive) async {
    // Ensure notification service is initialized
    await _notificationService.init();
    
    // Get current user ID
    final userId = UserSession().currentUser.value?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }

    // Fetch the reminder
    final reminder = await _repository.getReminderById(userId, id);
    if (reminder == null) {
      throw Exception('Reminder not found: $id');
    }

    // Prevent reactivation of expired "once" reminders
    if (isActive && reminder.recurrence == RecurrenceType.once) {
      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        reminder.time.hour,
        reminder.time.minute,
      );

      // If the scheduled time has passed, don't allow reactivation
      if (scheduledTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
        debugPrint('⚠️ Cannot reactivate expired "once" reminder: ${reminder.medicineName}');
        throw Exception('No se puede reactivar un recordatorio "Una vez" que ya ha pasado su hora programada.');
      }
    }

    // Check connectivity to determine sync status
    final isOnline = await _connectivity.checkConnectivity();
    
    final updatedReminder = reminder.copyWith(
      isActive: isActive,
      version: reminder.version + 1,
      syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pending,
      lastSyncedAt: isOnline ? DateTime.now() : reminder.lastSyncedAt,
    );
    
    try {
      // Update in Firestore if online
      if (isOnline) {
        await _repository.updateReminder(userId, updatedReminder);
      } else {
        // Cache locally for offline access
        await _cache.cacheReminders(userId, [updatedReminder]);
      }
      
      debugPrint('🔀 Toggled reminder: ${reminder.medicineName} -> ${isActive ? "ON" : "OFF"} (SyncStatus: ${updatedReminder.syncStatus.name})');

      if (isActive) {
        await _notificationService.scheduleReminderNotification(updatedReminder);
      } else {
        await _notificationService.cancelReminderNotification(id);
      }
    } catch (e) {
      debugPrint('❌ [ReminderService] Error toggling reminder: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    // Get current user ID
    final userId = UserSession().currentUser.value?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }
    
    try {
      await _repository.deleteReminder(userId, id);
      await _notificationService.cancelReminderNotification(id);
      debugPrint('🗑️ Deleted reminder from Firestore: $id');
    } catch (e) {
      debugPrint('❌ [ReminderService] Error deleting reminder: $e');
      rethrow;
    }
  }

  @override
  Future<void> testReminderNotification(MedicationReminder reminder) async {
    await _notificationService.init();
    await _notificationService.showTestNotification(reminder);
  }
}
