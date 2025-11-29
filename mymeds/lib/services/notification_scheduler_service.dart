import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/notification_event.dart';
import 'smart_notification_service.dart';

/// Scheduler service that integrates flutter_local_notifications with SmartNotificationService
/// 
/// This service acts as a bridge between the app's notification logic and the smart
/// notification system, ensuring notifications are sent at optimal times based on
/// user behavior patterns.
class NotificationSchedulerService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final SmartNotificationService _smartService;
  
  // Notification channel configuration
  static const String _channelId = 'smart_notifications';
  static const String _channelName = 'Smart Notifications';
  static const String _channelDescription = 'Intelligent notification scheduling based on your preferences';
  
  NotificationSchedulerService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    SmartNotificationService? smartService,
  })  : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _smartService = smartService ?? SmartNotificationService();

  /// Initialize the notification scheduler
  Future<void> initialize() async {
    debugPrint('🔔 [NotificationScheduler] Initializing...');
    
    // Initialize timezone database
    tz.initializeTimeZones();
    
    // Initialize smart notification service
    await _smartService.initialize();
    
    // Initialize flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request permissions
    await _requestPermissions();
    
    debugPrint('✅ [NotificationScheduler] Initialized successfully');
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    
    return false;
  }

  /// Schedule a smart notification
  /// 
  /// This will either send the notification immediately or schedule it for
  /// an optimal time based on user behavior patterns.
  Future<void> scheduleNotification({
    required String type,
    required String title,
    required String body,
    String? payload,
    bool isUrgent = false,
  }) async {
    debugPrint('📅 [NotificationScheduler] Scheduling notification: $type');
    
    // Check if notification should be sent now
    final shouldSendNow = await _smartService.shouldSendNotificationNow(
      type: type,
      isUrgent: isUrgent,
    );
    
    if (shouldSendNow) {
      // Send immediately
      await _sendNotificationNow(
        type: type,
        title: title,
        body: body,
        payload: payload,
      );
      
      // Record that we sent this notification
      await _smartService.recordEvent(
        type: type,
        result: NotificationResult.ignored, // Will be updated if user taps
      );
    } else {
      // Schedule for optimal time
      final optimalTime = await _smartService.getOptimalSendTime();
      
      await _scheduleNotificationAt(
        type: type,
        title: title,
        body: body,
        scheduledTime: optimalTime,
        payload: payload,
      );
      
      debugPrint('⏰ [NotificationScheduler] Rescheduled to: $optimalTime');
    }
  }

  /// Send notification immediately
  Future<void> _sendNotificationNow({
    required String type,
    required String title,
    required String body,
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload ?? type,
    );
    
    debugPrint('✅ [NotificationScheduler] Sent notification now: $title');
  }

  /// Schedule notification for a specific time
  Future<void> _scheduleNotificationAt({
    required String type,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledTime),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload ?? type,
    );
    
    debugPrint('📅 [NotificationScheduler] Scheduled notification for: $scheduledTime');
  }

  /// Convert DateTime to TZDateTime (required by flutter_local_notifications)
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    final location = tz.local;
    return tz.TZDateTime.from(dateTime, location);
  }

  /// Handle notification tap/open
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    
    debugPrint('👆 [NotificationScheduler] Notification tapped: $payload');
    
    // Record that user opened this notification
    await _smartService.recordEvent(
      type: payload,
      result: NotificationResult.opened,
    );
  }

  /// Send a prescription reminder notification
  Future<void> sendPrescriptionReminder({
    required String prescriptionId,
    required String medicationName,
    bool isUrgent = false,
  }) async {
    await scheduleNotification(
      type: 'prescription_reminder',
      title: 'Recordatorio de Prescripción',
      body: 'Es hora de tomar $medicationName',
      payload: 'prescription:$prescriptionId',
      isUrgent: isUrgent,
    );
  }

  /// Send an order update notification
  Future<void> sendOrderUpdate({
    required String orderId,
    required String status,
    required String message,
    bool isUrgent = false,
  }) async {
    await scheduleNotification(
      type: 'order_update',
      title: 'Actualización de Pedido',
      body: message,
      payload: 'order:$orderId',
      isUrgent: isUrgent,
    );
  }

  /// Send a delivery notification
  Future<void> sendDeliveryNotification({
    required String orderId,
    required String message,
    bool isUrgent = true, // Deliveries are typically urgent
  }) async {
    await scheduleNotification(
      type: 'delivery_status',
      title: 'Estado de Entrega',
      body: message,
      payload: 'delivery:$orderId',
      isUrgent: isUrgent,
    );
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('🗑️ [NotificationScheduler] Cancelled all notifications');
  }

  /// Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('🗑️ [NotificationScheduler] Cancelled notification: $id');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Update smart notification preferences
  void updatePreferences({
    bool? smartNotificationsEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    _smartService.updatePreferences(
      smartNotificationsEnabled: smartNotificationsEnabled,
      quietStartHour: quietStartHour,
      quietEndHour: quietEndHour,
    );
  }

  /// Get smart notification preferences
  SmartNotificationPreferences getPreferences() {
    return _smartService.getPreferences();
  }

  /// Get analytics for display in settings
  Future<NotificationAnalytics> getAnalytics() async {
    return await _smartService.getAnalytics();
  }

  /// Clear all notification history (for testing/reset)
  Future<void> clearHistory() async {
    await _smartService.clearAllEvents();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _smartService.dispose();
  }
}
