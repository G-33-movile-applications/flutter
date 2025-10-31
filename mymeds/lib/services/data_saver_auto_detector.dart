import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import 'settings_service.dart';

/// Callback function signature for auto-detection triggers
typedef OnMobileDataDetected = Future<void> Function(
  bool enableDataSaver,
);

/// Service for automatically detecting mobile data usage and prompting Data Saver Mode
/// 
/// Features:
/// - Monitors connectivity changes
/// - Detects when device switches to mobile data
/// - Shows a prompt asking if user wants to enable Data Saver Mode
/// - Saves user preference to avoid repeated prompts
/// - Respects user's manual settings (doesn't force anything)
class DataSaverAutoDetector {
  static final DataSaverAutoDetector _instance =
      DataSaverAutoDetector._internal();

  factory DataSaverAutoDetector() {
    return _instance;
  }

  DataSaverAutoDetector._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final SettingsService _settingsService = SettingsService();

  bool _isInitialized = false;
  OnMobileDataDetected? _onMobileDataDetected;

  // Last connection type to detect transitions
  ConnectionType? _lastConnectionType;

  // Throttle prompts (don't show more than once per 24 hours)
  static const Duration _promptThrottleDuration = Duration(hours: 24);

  /// Initialize the auto-detector
  /// Pass [onMobileDataDetected] callback to handle when mobile data is detected
  Future<void> init({
    required OnMobileDataDetected onMobileDataDetected,
  }) async {
    if (_isInitialized) {
      debugPrint('📊 DataSaverAutoDetector already initialized, skipping');
      return;
    }

    _onMobileDataDetected = onMobileDataDetected;
    _lastConnectionType = _connectivityService.currentConnectionType;

    debugPrint('📊 DataSaverAutoDetector initializing...');
    debugPrint('📊 Current connection type: $_lastConnectionType');
    debugPrint('📊 Data Saver already enabled: ${_settingsService.getDataSaverMode()}');

    // Listen to connectivity changes and detect mobile data transitions
    _connectivityService.connectionStream.listen(
      (connectionType) {
        debugPrint('📊 Stream event: connectionType = $connectionType');
        _handleConnectionTypeChange(connectionType);
      },
      onError: (error) {
        debugPrint('❌ Connection stream error: $error');
      },
      onDone: () {
        debugPrint('📊 Connection stream closed');
      },
    );

    _isInitialized = true;
    debugPrint('📊 DataSaverAutoDetector initialized and listening');
  }

  /// Handle changes in connection type
  Future<void> _handleConnectionTypeChange(ConnectionType newType) async {
    debugPrint(
      '📊 Connection type changed: $_lastConnectionType → $newType',
    );

    // Only trigger if transitioning TO mobile data (not already on it)
    final wasNotMobile = _lastConnectionType != ConnectionType.mobile;
    final isNowMobile = newType == ConnectionType.mobile;

    if (wasNotMobile && isNowMobile) {
      await _handleMobileDataDetected();
    }

    _lastConnectionType = newType;
  }

  /// Handle the detection of mobile data connection
  Future<void> _handleMobileDataDetected() async {
    debugPrint('📊 Mobile data detected!');

    // Check if user already has Data Saver enabled
    if (_settingsService.getDataSaverMode()) {
      debugPrint('📊 Data Saver already enabled, skipping prompt');
      return;
    }

    // Check if we should show the prompt (throttle to avoid spam)
    if (!_shouldShowPrompt()) {
      debugPrint(
        '📊 Throttling prompt (shown within last 24 hours), skipping',
      );
      return;
    }

    // Show the prompt
    debugPrint('📊 Showing mobile data prompt...');
    await _onMobileDataDetected?.call(_settingsService.getDataSaverMode());

    // Record that we showed the prompt
    await _settingsService.setLastMobileDataPromptTime(DateTime.now());
  }

  /// Check if we should show the prompt based on throttle duration
  bool _shouldShowPrompt() {
    final lastPromptTime = _settingsService.getLastMobileDataPromptTime();

    // No previous prompt, show it
    if (lastPromptTime == null) {
      return true;
    }

    // Check if enough time has passed since last prompt
    final timeSinceLastPrompt = DateTime.now().difference(lastPromptTime);
    final shouldShow = timeSinceLastPrompt >= _promptThrottleDuration;

    if (!shouldShow) {
      final minutesUntilNextPrompt =
          (_promptThrottleDuration - timeSinceLastPrompt).inMinutes;
      debugPrint(
        '📊 Prompt throttled. Next prompt available in ~$minutesUntilNextPrompt minutes',
      );
    }

    return shouldShow;
  }

  /// Force reset the throttle timer (for testing or after manual user action)
  Future<void> resetThrottle() async {
    await _settingsService.setLastMobileDataPromptTime(
      DateTime.now().subtract(_promptThrottleDuration),
    );
    debugPrint('📊 Throttle timer reset');
  }

  /// FOR TESTING: Manually trigger mobile data detected (ignore throttle)
  Future<void> debugTriggerMobileDataPrompt() async {
    debugPrint('📊 [DEBUG] Manually triggering mobile data prompt');
    await _onMobileDataDetected?.call(_settingsService.getDataSaverMode());
  }

  /// Get current connection type
  ConnectionType get currentConnectionType =>
      _connectivityService.currentConnectionType;

  /// Check if currently on mobile data
  bool get isOnMobileData => currentConnectionType == ConnectionType.mobile;

  /// Dispose resources
  void dispose() {
    debugPrint('📊 DataSaverAutoDetector disposed');
  }
}
