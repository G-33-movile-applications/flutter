import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing application settings persistence
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Preference keys
  static const String _dataSaverModeKey = 'data_saver_mode_enabled';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _pushNotificationsEnabledKey = 'push_notifications_enabled';
  static const String _emailNotificationsEnabledKey = 'email_notifications_enabled';
  static const String _hasPromptedDataSaverKey = 'has_prompted_data_saver';
  static const String _lastMobileDataPromptKey = 'last_mobile_data_prompt_time';

  SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  /// Initialize the settings service (must be called once on app startup)
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Get whether Data Saver Mode is enabled
  bool getDataSaverMode() {
    _ensureInitialized();
    return _prefs.getBool(_dataSaverModeKey) ?? false;
  }

  /// Set Data Saver Mode
  Future<bool> setDataSaverMode(bool enabled) async {
    _ensureInitialized();
    return _prefs.setBool(_dataSaverModeKey, enabled);
  }

  /// Get whether notifications are enabled
  bool getNotificationsEnabled() {
    _ensureInitialized();
    return _prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Set notifications enabled
  Future<bool> setNotificationsEnabled(bool enabled) async {
    _ensureInitialized();
    return _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  /// Get whether push notifications are enabled
  bool getPushNotificationsEnabled() {
    _ensureInitialized();
    return _prefs.getBool(_pushNotificationsEnabledKey) ?? true;
  }

  /// Set push notifications enabled
  Future<bool> setPushNotificationsEnabled(bool enabled) async {
    _ensureInitialized();
    return _prefs.setBool(_pushNotificationsEnabledKey, enabled);
  }

  /// Get whether email notifications are enabled
  bool getEmailNotificationsEnabled() {
    _ensureInitialized();
    return _prefs.getBool(_emailNotificationsEnabledKey) ?? true;
  }

  /// Set email notifications enabled
  Future<bool> setEmailNotificationsEnabled(bool enabled) async {
    _ensureInitialized();
    return _prefs.setBool(_emailNotificationsEnabledKey, enabled);
  }

  /// Clear all settings (reset to defaults)
  Future<bool> clearAllSettings() async {
    _ensureInitialized();
    return _prefs.clear();
  }

  /// Check if user has already been prompted about Data Saver on mobile data
  bool getHasPromptedDataSaver() {
    _ensureInitialized();
    return _prefs.getBool(_hasPromptedDataSaverKey) ?? false;
  }

  /// Mark that user has been prompted about Data Saver
  Future<bool> setHasPromptedDataSaver(bool prompted) async {
    _ensureInitialized();
    return _prefs.setBool(_hasPromptedDataSaverKey, prompted);
  }

  /// Get the last time user was prompted about mobile data
  DateTime? getLastMobileDataPromptTime() {
    _ensureInitialized();
    final timestamp = _prefs.getString(_lastMobileDataPromptKey);
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      debugPrint('Error parsing last prompt time: $e');
      return null;
    }
  }

  /// Set the last time user was prompted about mobile data
  Future<bool> setLastMobileDataPromptTime(DateTime time) async {
    _ensureInitialized();
    return _prefs.setString(_lastMobileDataPromptKey, time.toIso8601String());
  }

  /// Ensure the service is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SettingsService must be initialized by calling init() before use.',
      );
    }
  }
}
