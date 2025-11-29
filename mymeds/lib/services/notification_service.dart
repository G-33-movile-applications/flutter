import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medication_reminder.dart';

/// Service for managing local notifications for medication reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_initialized) {
      debugPrint('✅ NotificationService already initialized, skipping');
      return;
    }

    debugPrint('🔧 Initializing NotificationService...');

    // Initialize timezone data
    tz.initializeTimeZones();
    debugPrint('🌍 Timezone database initialized');
    
    // Set local timezone - use a safe default for Colombia (Bogota)
    // You can make this configurable based on user's actual timezone if needed
    try {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
      debugPrint('🌍 Timezone set to: America/Bogota');
    } catch (e) {
      debugPrint('⚠️ Failed to set timezone to America/Bogota, using UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
    
    final now = tz.TZDateTime.now(tz.local);
    debugPrint('🕐 Current local time: $now');

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Request permissions
    await _requestPermissions();

    _initialized = true;
    debugPrint('✅ NotificationService initialized successfully');
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'medication_reminders_channel',
      'Recordatorios de Medicamentos',
      description: 'Notificaciones para recordar tomar medicamentos',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidChannel);
      debugPrint('📢 Notification channel created: medication_reminders_channel');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Step 1: Request exact alarm permission first (Android 12+, API 31+)
      // This is CRITICAL for zonedSchedule to work
      final canSchedule = await androidImplementation.canScheduleExactNotifications();
      debugPrint('📱 Can schedule exact notifications: $canSchedule');
      
      if (canSchedule == false) {
        debugPrint('⚠️ Requesting SCHEDULE_EXACT_ALARM permission...');
        final granted = await androidImplementation.requestExactAlarmsPermission();
        debugPrint('📱 Exact alarms permission requested, result: $granted');
        
        if (granted != true) {
          debugPrint('❌ CRITICAL: Exact alarm permission was DENIED. Scheduled notifications will NOT work.');
        }
      } else {
        debugPrint('✅ Exact alarm permission already granted');
      }
      
      // Step 2: Request notification permission (Android 13+, API 33+)
      final notificationPermission = await androidImplementation.requestNotificationsPermission();
      debugPrint('📱 Notification permission: ${notificationPermission ?? "not applicable"}');
      
      if (notificationPermission == false) {
        debugPrint('❌ WARNING: Notification permission was DENIED. Notifications will not display.');
      }
    }

    // For iOS - Request all permissions
    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('📱 iOS permissions requested');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation or actions when notification is tapped
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }

  /// Schedule a reminder notification based on recurrence type
  Future<void> scheduleReminderNotification(MedicationReminder reminder) async {
    if (!_initialized) await init();

    // Cancel any existing notification for this reminder
    await cancelReminderNotification(reminder.id);

    final notificationId = reminder.id.hashCode;

    debugPrint('📅 Scheduling notification for ${reminder.medicineName} (${reminder.recurrence.name})');

    switch (reminder.recurrence) {
      case RecurrenceType.once:
        await _scheduleOnceNotification(reminder, notificationId);
        break;
      case RecurrenceType.daily:
        await _scheduleDailyNotification(reminder, notificationId);
        break;
      case RecurrenceType.weekly:
        await _scheduleWeeklyNotification(reminder, notificationId);
        break;
      case RecurrenceType.specificDays:
        await _scheduleSpecificDaysNotification(reminder, notificationId);
        break;
    }

    // Verify the notification was scheduled
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('📋 Total pending notifications: ${pending.length}');
    for (var notification in pending) {
      debugPrint('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
  }

  /// Schedule a one-time notification
  Future<void> _scheduleOnceNotification(MedicationReminder reminder, int notificationId) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );
    
    // Ensure scheduled time is at least 5 seconds in the future
    while (scheduledTime.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      debugPrint('⚠️ Scheduled time was too close or in past, moved to next day');
    }
    
    final diffSeconds = scheduledTime.difference(now).inSeconds;
    debugPrint('⏰ NOW: $now');
    debugPrint('⏰ SCHEDULED (ONCE): $scheduledTime');
    debugPrint('⏰ Time until notification: ${diffSeconds}s (~${(diffSeconds / 60).toStringAsFixed(1)} minutes)');

    await _notifications.zonedSchedule(
      notificationId,
      'Recordatorio de medicamento',
      'Es hora de tomar ${reminder.medicineName}',
      scheduledTime,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.id,
    );
    
    debugPrint('✅ Once notification scheduled successfully (ID: $notificationId)');
  }

  /// Schedule a daily repeating notification
  Future<void> _scheduleDailyNotification(MedicationReminder reminder, int notificationId) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    // If the scheduled time has passed today, schedule for tomorrow
    // Ensure at least 5 seconds buffer
    while (scheduledTime.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      debugPrint('⚠️ Time passed today, scheduling for tomorrow');
    }

    final diffSeconds = scheduledTime.difference(now).inSeconds;
    debugPrint('⏰ NOW: $now');
    debugPrint('⏰ SCHEDULED (DAILY): $scheduledTime');
    debugPrint('⏰ First occurrence in: ${diffSeconds}s (~${(diffSeconds / 60).toStringAsFixed(1)} minutes)');
    debugPrint('⏰ Will repeat: Daily at ${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}');

    await _notifications.zonedSchedule(
      notificationId,
      'Recordatorio de medicamento',
      'Es hora de tomar ${reminder.medicineName}',
      scheduledTime,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: reminder.id,
    );
    
    debugPrint('✅ Daily notification scheduled successfully (ID: $notificationId)');
  }

  /// Schedule a weekly repeating notification
  Future<void> _scheduleWeeklyNotification(MedicationReminder reminder, int notificationId) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    // Schedule for same weekday as today, but ensure it's in the future
    // If time has passed, move to next week
    while (scheduledTime.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduledTime = scheduledTime.add(const Duration(days: 7));
      debugPrint('⚠️ Time passed this week, scheduling for next week');
    }

    final diffSeconds = scheduledTime.difference(now).inSeconds;
    final weekdayName = _getWeekdayName(scheduledTime.weekday);
    debugPrint('⏰ NOW: $now');
    debugPrint('⏰ SCHEDULED (WEEKLY): $scheduledTime');
    debugPrint('⏰ First occurrence in: ${diffSeconds}s (~${(diffSeconds / 60).toStringAsFixed(1)} minutes)');
    debugPrint('⏰ Will repeat: Every $weekdayName at ${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}');

    await _notifications.zonedSchedule(
      notificationId,
      'Recordatorio de medicamento',
      'Es hora de tomar ${reminder.medicineName}',
      scheduledTime,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: reminder.id,
    );
    
    debugPrint('✅ Weekly notification scheduled successfully (ID: $notificationId)');
  }

  /// Schedule notifications for specific days of the week
  Future<void> _scheduleSpecificDaysNotification(MedicationReminder reminder, int baseNotificationId) async {
    if (reminder.specificDays.isEmpty) {
      debugPrint('⚠️ No specific days selected, skipping');
      return;
    }

    debugPrint('⏰ Scheduling for specific days: ${reminder.specificDays.map((d) => d.displayName).join(", ")}');

    // Schedule a separate notification for each selected day
    for (final day in reminder.specificDays) {
      final dayNotificationId = baseNotificationId + day.index;
      final scheduledTime = _getNextOccurrenceOfDay(day, reminder.time);
      final now = tz.TZDateTime.now(tz.local);
      final diffSeconds = scheduledTime.difference(now).inSeconds;

      debugPrint('⏰ - ${day.displayName}: $scheduledTime (in ${(diffSeconds / 60).toStringAsFixed(1)} min)');

      await _notifications.zonedSchedule(
        dayNotificationId,
        'Recordatorio de medicamento',
        'Es hora de tomar ${reminder.medicineName}',
        scheduledTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: reminder.id,
      );
    }
    
    debugPrint('✅ Specific days notifications scheduled successfully (${reminder.specificDays.length} notifications)');
  }

  /// Get next occurrence of a specific day and time
  tz.TZDateTime _getNextOccurrenceOfDay(DayOfWeek dayOfWeek, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Find next occurrence of the specified weekday
    // Ensure at least 5 seconds buffer from now
    while (scheduledTime.weekday != dayOfWeek.weekdayNumber || 
           scheduledTime.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  /// Get notification details (Android and iOS specific settings)
  NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'medication_reminders_channel',
      'Recordatorios de Medicamentos',
      channelDescription: 'Notificaciones para recordar tomar medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      channelShowBadge: true,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Cancel a specific reminder notification
  Future<void> cancelReminderNotification(String reminderId) async {
    final baseNotificationId = reminderId.hashCode;
    
    // Cancel base notification
    await _notifications.cancel(baseNotificationId);
    
    // Cancel all day-specific notifications (for specificDays recurrence)
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(baseNotificationId + i);
    }

    debugPrint('🗑️ Cancelled notifications for reminder: $reminderId');
  }

  /// Cancel all reminder notifications
  Future<void> cancelAllReminderNotifications() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ Cancelled all notifications');
  }

  /// Show a test notification immediately
  Future<void> showTestNotification(MedicationReminder reminder) async {
    if (!_initialized) await init();

    final testNotificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    debugPrint('🧪 Showing test notification for ${reminder.medicineName}');

    await _notifications.show(
      testNotificationId,
      'Prueba de recordatorio',
      'Así se verá tu recordatorio para ${reminder.medicineName}',
      _notificationDetails(),
      payload: reminder.id,
    );
  }

  /// Show a reminder notification immediately (fallback for in-app scheduler)
  /// This uses show() instead of zonedSchedule, so it works reliably
  /// as long as the app is running.
  Future<void> showReminderNow(MedicationReminder reminder) async {
    if (!_initialized) await init();

    // Use hashCode but ensure it's within 32-bit signed integer range
    // by taking modulo 2^31 and keeping it positive
    final notificationId = reminder.id.hashCode.abs() % 2147483647;

    debugPrint('🔔 Showing immediate notification for: ${reminder.medicineName}');

    await _notifications.show(
      notificationId,
      'Recordatorio de medicamento',
      'Es hora de tomar ${reminder.medicineName}',
      _notificationDetails(),
      payload: reminder.id,
    );
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Helper: Get weekday name from weekday number (1=Monday, 7=Sunday)
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Lunes';
      case 2: return 'Martes';
      case 3: return 'Miércoles';
      case 4: return 'Jueves';
      case 5: return 'Viernes';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return 'Desconocido';
    }
  }

  /// Debug method: Schedule a notification to fire in 10 seconds
  /// Use this to verify that zonedSchedule works on the device
  Future<void> debugScheduleInTenSeconds() async {
    if (!_initialized) await init();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(seconds: 10));
    final testId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    debugPrint('🧪 ===== DEBUG NOTIFICATION TEST =====');
    debugPrint('🧪 NOW: $now');
    debugPrint('🧪 SCHEDULED: $scheduledTime');
    debugPrint('🧪 Difference: ${scheduledTime.difference(now).inSeconds} seconds');
    debugPrint('🧪 Notification ID: $testId');

    await _notifications.zonedSchedule(
      testId,
      'Prueba en 10 segundos',
      'Esta notificación debería aparecer en 10 segundos',
      scheduledTime,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'debug-10s',
    );

    debugPrint('🧪 Debug notification scheduled successfully');
    
    // Verify it was scheduled
    final pending = await getPendingNotifications();
    final found = pending.any((n) => n.id == testId);
    debugPrint('🧪 Verification: Notification ${found ? "FOUND" : "NOT FOUND"} in pending list');
    debugPrint('🧪 Total pending notifications: ${pending.length}');
    debugPrint('🧪 ====================================');
  }
}
