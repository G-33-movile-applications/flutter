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
    // For Android 13+ (API 33+) - Request notification permission
    final notificationPermission = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    debugPrint('📱 Notification permission: ${notificationPermission ?? "not applicable"}');

    // For Android 12+ (API 31+) - Request exact alarm permission
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final canSchedule = await androidImplementation.canScheduleExactNotifications();
      debugPrint('📱 Can schedule exact notifications: $canSchedule');
      
      if (canSchedule == false) {
        final granted = await androidImplementation.requestExactAlarmsPermission();
        debugPrint('📱 Exact alarms permission requested, result: $granted');
      } else {
        debugPrint('✅ Exact alarm permission already granted');
      }
    }

    // For iOS
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
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
    var scheduledTime = _getNextScheduledTime(reminder.time);
    
    // Ensure scheduled time is in the future
    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      debugPrint('⚠️ Scheduled time is in the past/now, adding 1 day');
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    final diffSeconds = scheduledTime.difference(now).inSeconds;
    debugPrint('⏰ NOW: $now');
    debugPrint('⏰ SCHEDULED (ONCE): $scheduledTime');
    debugPrint('⏰ Time until notification: ${diffSeconds}s (~${diffSeconds ~/ 60} minutes)');

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
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    debugPrint('⏰ Scheduling DAILY notification for ${scheduledTime}');

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

    // Find next occurrence of the same weekday
    while (scheduledTime.isBefore(now) || scheduledTime.weekday != now.weekday) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

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
  }

  /// Schedule notifications for specific days of the week
  Future<void> _scheduleSpecificDaysNotification(MedicationReminder reminder, int baseNotificationId) async {
    if (reminder.specificDays.isEmpty) return;

    // Schedule a separate notification for each selected day
    for (final day in reminder.specificDays) {
      final dayNotificationId = baseNotificationId + day.index;
      final scheduledTime = _getNextOccurrenceOfDay(day, reminder.time);

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
    while (scheduledTime.weekday != dayOfWeek.weekdayNumber || scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  /// Get next scheduled time for a given TimeOfDay
  tz.TZDateTime _getNextScheduledTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
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

  /// Debug method: Schedule a notification to fire in 10 seconds
  /// Use this to verify that zonedSchedule works on the device
  Future<void> debugScheduleInTenSeconds() async {
    if (!_initialized) await init();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(seconds: 10));

    debugPrint('🧪 Debug scheduling notification for $scheduledTime');
    debugPrint('🧪 NOW: $now');
    debugPrint('🧪 SCHEDULED: $scheduledTime');
    debugPrint('🧪 Difference: ${scheduledTime.difference(now).inSeconds} seconds');

    await _notifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID based on timestamp
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
  }
}
