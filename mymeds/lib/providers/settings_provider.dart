import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/cache_service.dart';
import '../services/data_saver_auto_detector.dart';
import '../services/profile_sync_service.dart';

/// Provider for managing application settings state
class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  final CacheService _cacheService = CacheService();
  final DataSaverAutoDetector _autoDetector = DataSaverAutoDetector();
  final ProfileSyncService _profileSyncService = ProfileSyncService();

  // Private state variables
  bool _dataSaverModeEnabled = false;
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _isLoading = false;
  int _syncQueueSize = 0;
  bool _showMobileDataPrompt = false;

  // Getters
  bool get dataSaverModeEnabled => _dataSaverModeEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get isLoading => _isLoading;
  int get syncQueueSize => _syncQueueSize;
  ConnectionType get currentConnectionType =>
      _connectivityService.currentConnectionType;
  bool get showMobileDataPrompt => _showMobileDataPrompt;
  bool get isOnMobileData => _autoDetector.isOnMobileData;

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

      // Initialize auto-detector AFTER connectivity service is ready
      // Use Future.delayed to ensure UI is built before triggering prompts
      Future.delayed(const Duration(milliseconds: 500), () {
        _initializeAutoDetector();
      });

      debugPrint('⚙️ SettingsProvider initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing SettingsProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize auto-detector after UI is ready
  Future<void> _initializeAutoDetector() async {
    try {
      await _autoDetector.init(
        onMobileDataDetected: _handleMobileDataDetected,
      );
      debugPrint('⚙️ Auto-detector initialized and listening');
    } catch (e) {
      debugPrint('❌ Error initializing auto-detector: $e');
    }
  }

  /// Handle mobile data detection (called by auto-detector)
  Future<void> _handleMobileDataDetected(bool currentlyEnabled) async {
    debugPrint('⚙️ Mobile data detected, triggering prompt');
    debugPrint('⚙️ Currently enabled: $currentlyEnabled');
    debugPrint('⚙️ Setting showMobileDataPrompt to true');
    
    // Check if already showing prompt
    if (_showMobileDataPrompt) {
      debugPrint('⚙️ Prompt already showing, skipping');
      return;
    }
    
    _showMobileDataPrompt = true;
    debugPrint('⚙️ Notifying listeners about mobile data prompt');
    notifyListeners();
  }

  /// Update sync queue size and rebuild UI
  void _updateSyncQueueSize() {
    _syncQueueSize = _syncService.queueSize;
    notifyListeners();
  }

  /// Toggle Data Saver Mode
  Future<void> toggleDataSaverMode(bool value) async {
    _dataSaverModeEnabled = value;
    _showMobileDataPrompt = false; // Hide prompt after action
    notifyListeners();

    try {
      await _settingsService.setDataSaverMode(value);

      // Notify ProfileSyncService about Data Saver mode change
      await _profileSyncService.onDataSaverModeChanged(value);

      if (value) {
        debugPrint('💾 Data Saver Mode ENABLED');
        // Clear cache on enable to ensure fresh data on next load
        // (user consciously enabled data saver)
      } else {
        debugPrint('💾 Data Saver Mode DISABLED - triggering profile sync');
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

  /// Enable Data Saver from mobile data prompt
  Future<void> enableDataSaverFromPrompt() async {
    debugPrint('⚙️ Enabling Data Saver from mobile data prompt');
    await toggleDataSaverMode(true);
  }

  /// Decline mobile data prompt without enabling Data Saver
  Future<void> declineMobileDataPrompt() async {
    debugPrint('⚙️ User declined mobile data prompt');
    _showMobileDataPrompt = false;
    notifyListeners();
  }

  /// Don't ask again for 24 hours (resets throttle)
  Future<void> dontAskAgainMobileDataPrompt() async {
    debugPrint('⚙️ User selected "don\'t ask again" for 24 hours');
    await _autoDetector.resetThrottle();
    await declineMobileDataPrompt();
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
