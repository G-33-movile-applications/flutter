import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/cache_service.dart';

/// Provider for managing application settings state
class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  final CacheService _cacheService = CacheService();

  // Private state variables
  bool _dataSaverModeEnabled = false;
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _isLoading = false;
  int _syncQueueSize = 0;

  // Getters
  bool get dataSaverModeEnabled => _dataSaverModeEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get isLoading => _isLoading;
  int get syncQueueSize => _syncQueueSize;
  ConnectionType get currentConnectionType =>
      _connectivityService.currentConnectionType;

  /// Initialize the provider by loading settings from storage
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize all services
      await _connectivityService.init();
      await _syncService.init();
      await _cacheService.init();

      // Load all settings from persistent storage
      _dataSaverModeEnabled = _settingsService.getDataSaverMode();
      _notificationsEnabled = _settingsService.getNotificationsEnabled();
      _pushNotificationsEnabled = _settingsService.getPushNotificationsEnabled();
      _emailNotificationsEnabled = _settingsService.getEmailNotificationsEnabled();

      // Listen to sync queue changes
      _updateSyncQueueSize();

      debugPrint('⚙️ SettingsProvider initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing SettingsProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update sync queue size and rebuild UI
  void _updateSyncQueueSize() {
    _syncQueueSize = _syncService.queueSize;
    notifyListeners();
  }

  /// Toggle Data Saver Mode
  Future<void> toggleDataSaverMode(bool value) async {
    _dataSaverModeEnabled = value;
    notifyListeners();

    try {
      await _settingsService.setDataSaverMode(value);

      if (value) {
        debugPrint('💾 Data Saver Mode ENABLED');
        // Clear cache on enable to ensure fresh data on next load
        // (user consciously enabled data saver)
      } else {
        debugPrint('💾 Data Saver Mode DISABLED');
        // Optionally clear cache on disable
        _cacheService.clear();
      }
    } catch (e) {
      debugPrint('❌ Error saving Data Saver Mode: $e');
      // Revert on error
      _dataSaverModeEnabled = !value;
      notifyListeners();
    }
  }

  /// Toggle Notifications
  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();

    try {
      await _settingsService.setNotificationsEnabled(value);
    } catch (e) {
      debugPrint('Error saving Notifications setting: $e');
      // Revert on error
      _notificationsEnabled = !value;
      notifyListeners();
    }
  }

  /// Toggle Push Notifications
  Future<void> togglePushNotifications(bool value) async {
    _pushNotificationsEnabled = value;
    notifyListeners();

    try {
      await _settingsService.setPushNotificationsEnabled(value);
    } catch (e) {
      debugPrint('Error saving Push Notifications setting: $e');
      // Revert on error
      _pushNotificationsEnabled = !value;
      notifyListeners();
    }
  }

  /// Toggle Email Notifications
  Future<void> toggleEmailNotifications(bool value) async {
    _emailNotificationsEnabled = value;
    notifyListeners();

    try {
      await _settingsService.setEmailNotificationsEnabled(value);
    } catch (e) {
      debugPrint('Error saving Email Notifications setting: $e');
      // Revert on error
      _emailNotificationsEnabled = !value;
      notifyListeners();
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.clearAllSettings();
      _dataSaverModeEnabled = false;
      _notificationsEnabled = true;
      _pushNotificationsEnabled = true;
      _emailNotificationsEnabled = true;
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
