import 'package:flutter/foundation.dart';
import '../services/notification_scheduler_service.dart';
import '../services/smart_notification_service.dart';

/// Provider for Smart Notifications feature
/// 
/// Manages the state and configuration of smart notifications,
/// providing an interface between the UI and notification services.
class SmartNotificationProvider extends ChangeNotifier {
  final NotificationSchedulerService _schedulerService;
  
  // User preferences
  bool _smartNotificationsEnabled = true;
  int _quietStartHour = 22;
  int _quietEndHour = 7;
  
  // Analytics data
  NotificationAnalytics? _analytics;
  bool _analyticsLoading = false;
  
  SmartNotificationProvider({
    NotificationSchedulerService? schedulerService,
  }) : _schedulerService = schedulerService ?? NotificationSchedulerService();

  // Getters
  bool get smartNotificationsEnabled => _smartNotificationsEnabled;
  int get quietStartHour => _quietStartHour;
  int get quietEndHour => _quietEndHour;
  NotificationAnalytics? get analytics => _analytics;
  bool get analyticsLoading => _analyticsLoading;
  
  String get quietHoursDescription {
    return '${_quietStartHour.toString().padLeft(2, '0')}:00 - ${_quietEndHour.toString().padLeft(2, '0')}:00';
  }

  /// Initialize the provider
  Future<void> initialize() async {
    debugPrint('🔔 [SmartNotificationProvider] Initializing...');
    
    await _schedulerService.initialize();
    
    // Load preferences
    final prefs = _schedulerService.getPreferences();
    _smartNotificationsEnabled = prefs.smartNotificationsEnabled;
    _quietStartHour = prefs.quietStartHour;
    _quietEndHour = prefs.quietEndHour;
    
    // Load analytics
    await refreshAnalytics();
    
    notifyListeners();
  }

  /// Toggle smart notifications on/off
  void setSmartNotificationsEnabled(bool enabled) {
    _smartNotificationsEnabled = enabled;
    
    _schedulerService.updatePreferences(
      smartNotificationsEnabled: enabled,
    );
    
    debugPrint('⚙️ [SmartNotificationProvider] Smart notifications: ${enabled ? "ENABLED" : "DISABLED"}');
    notifyListeners();
  }

  /// Update quiet hours
  void setQuietHours({
    int? startHour,
    int? endHour,
  }) {
    if (startHour != null) {
      _quietStartHour = startHour.clamp(0, 23);
    }
    
    if (endHour != null) {
      _quietEndHour = endHour.clamp(0, 23);
    }
    
    _schedulerService.updatePreferences(
      quietStartHour: _quietStartHour,
      quietEndHour: _quietEndHour,
    );
    
    debugPrint('⚙️ [SmartNotificationProvider] Quiet hours: $_quietStartHour:00 - $_quietEndHour:00');
    notifyListeners();
  }

  /// Refresh analytics data
  Future<void> refreshAnalytics() async {
    _analyticsLoading = true;
    notifyListeners();
    
    try {
      _analytics = await _schedulerService.getAnalytics();
      debugPrint('📊 [SmartNotificationProvider] Analytics refreshed');
    } catch (e) {
      debugPrint('❌ [SmartNotificationProvider] Error loading analytics: $e');
    } finally {
      _analyticsLoading = false;
      notifyListeners();
    }
  }

  /// Clear all notification history
  Future<void> clearHistory() async {
    await _schedulerService.clearHistory();
    await refreshAnalytics();
    debugPrint('🗑️ [SmartNotificationProvider] History cleared');
  }

  /// Send a test notification
  Future<void> sendTestNotification() async {
    await _schedulerService.scheduleNotification(
      type: 'test',
      title: 'Notificación de Prueba',
      body: 'Esta es una notificación de prueba del sistema inteligente',
      isUrgent: false,
    );
    
    debugPrint('🧪 [SmartNotificationProvider] Test notification sent');
  }

  /// Get notification scheduler service (for direct access)
  NotificationSchedulerService get schedulerService => _schedulerService;

  @override
  void dispose() {
    _schedulerService.dispose();
    super.dispose();
  }
}
