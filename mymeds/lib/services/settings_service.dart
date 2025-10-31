import 'package:shared_preferences/shared_preferences.dart';

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

  /// Ensure the service is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SettingsService must be initialized by calling init() before use.',
      );
    }
  }
}
