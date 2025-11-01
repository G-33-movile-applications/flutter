import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import 'profile_cache_service.dart';
import 'settings_service.dart';
import '../repositories/usuario_repository.dart';

/// Callback for profile sync events
typedef OnProfileSyncEvent = Future<void> Function(ProfileSyncEvent event);

/// Represents different profile sync events
enum ProfileSyncEventType {
  syncStarted,
  syncSuccess,
  syncFailed,
  syncCancelled,
}

class ProfileSyncEvent {
  final ProfileSyncEventType type;
  final String message;
  final dynamic data;
  final DateTime timestamp;

  ProfileSyncEvent({
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Service for managing deferred profile sync operations
/// 
/// When Data Saver Mode is active:
/// - Profile updates are cached locally instead of uploading immediately
/// - Once Wi-Fi is available or Data Saver is disabled, sync is triggered
/// - Handles retry logic and failure scenarios
class ProfileSyncService {
  static final ProfileSyncService _instance = ProfileSyncService._internal();

  factory ProfileSyncService() {
    return _instance;
  }

  ProfileSyncService._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final ProfileCacheService _profileCacheService = ProfileCacheService();
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  final SettingsService _settingsService = SettingsService();

  bool _isInitialized = false;
  bool _isSyncing = false;
  OnProfileSyncEvent? _onSyncEvent;
  
  // Track previous Data Saver state to detect transitions
  bool _lastDataSaverState = false;

  // Maximum retries before giving up
  static const int _maxRetries = 3;

  // Retry delay
  static const Duration _retryDelay = Duration(seconds: 5);

  /// Initialize the profile sync service
  Future<void> init({
    required OnProfileSyncEvent onSyncEvent,
  }) async {
    if (_isInitialized) {
      debugPrint('📤 ProfileSyncService already initialized, skipping');
      return;
    }

    _onSyncEvent = onSyncEvent;
    _lastDataSaverState = _settingsService.getDataSaverMode();

    debugPrint('📤 ProfileSyncService initializing...');
    debugPrint('📤 Initial Data Saver state: $_lastDataSaverState');

    // Listen to connectivity changes
    _connectivityService.connectionStream.listen((connectionType) {
      _handleConnectivityChange(connectionType);
    });

    _isInitialized = true;
    debugPrint('📤 ProfileSyncService initialized and listening for changes');

    // Try to sync on startup if there are pending updates and Wi-Fi is available
    await Future.delayed(const Duration(seconds: 1));
    
    // Only auto-sync on startup if Wi-Fi is available (respect Data Saver)
    if (_connectivityService.isWiFi) {
      await _attemptSync();
    }
  }

  /// Handle connectivity changes
  Future<void> _handleConnectivityChange(ConnectionType connectionType) async {
    debugPrint('📤 Connectivity changed: $connectionType');

    // Check current Data Saver state and detect transitions
    final currentDataSaverState = _settingsService.getDataSaverMode();
    final dataSaverDisabled = _lastDataSaverState && !currentDataSaverState;
    _lastDataSaverState = currentDataSaverState;

    // Sync if:
    // 1. Wi-Fi is available (always sync on Wi-Fi, regardless of Data Saver)
    // 2. Mobile data is available AND Data Saver is disabled (user wants to sync on mobile)
    // 3. Data Saver Mode was just disabled (user explicitly disabled it)
    final isWiFiNow = connectionType == ConnectionType.wifi;
    final isMobileDataNow = connectionType == ConnectionType.mobile;
    final hasConnection = connectionType != ConnectionType.none;
    final hasPending = await _profileCacheService.hasPendingUpdate();

    if (isWiFiNow && hasPending) {
      // Wi-Fi is available and we have pending updates
      // SYNC REGARDLESS OF DATA SAVER MODE!
      // (User connected to Wi-Fi explicitly, so they intend to sync)
      debugPrint('📤 Wi-Fi available with pending updates, attempting sync');
      await _attemptSync();
    } else if (isMobileDataNow && !currentDataSaverState && hasPending) {
      // Mobile data available AND Data Saver disabled AND pending updates
      debugPrint('📤 Mobile data available and Data Saver disabled, attempting sync');
      await _attemptSync();
    } else if (dataSaverDisabled && hasPending) {
      // Data Saver was disabled, attempt sync if we have connection
      if (hasConnection) {
        debugPrint('📤 Data Saver Mode disabled and connection available, attempting sync');
        await _attemptSync();
      }
    }
  }

  /// Attempt to sync pending profile data
  /// This is called when Wi-Fi becomes available or Data Saver is disabled
  Future<void> _attemptSync() async {
    if (_isSyncing) {
      debugPrint('📤 Sync already in progress, skipping');
      return;
    }

    final hasPending = await _profileCacheService.hasPendingUpdate();
    if (!hasPending) {
      debugPrint('📤 No pending updates to sync');
      return;
    }

    _isSyncing = true;

    try {
      await _fireEvent(
        ProfileSyncEvent(
          type: ProfileSyncEventType.syncStarted,
          message: 'Starting profile sync...',
        ),
      );

      final userData = await _profileCacheService.getPendingUpdate();
      if (userData == null) {
        debugPrint('❌ Failed to retrieve pending update');
        await _fireEvent(
          ProfileSyncEvent(
            type: ProfileSyncEventType.syncFailed,
            message: 'Failed to retrieve locally cached data',
          ),
        );
        return;
      }

      // Attempt to upload with retries
      bool syncSuccess = false;
      int attempts = 0;

      while (attempts < _maxRetries && !syncSuccess) {
        try {
          debugPrint('📤 Sync attempt ${attempts + 1}/$_maxRetries');

          await _usuarioRepository.update(userData);

          // Success!
          await _profileCacheService.clearPendingUpdate();
          await _profileCacheService.resetSyncFailedCount();

          syncSuccess = true;

          await _fireEvent(
            ProfileSyncEvent(
              type: ProfileSyncEventType.syncSuccess,
              message: 'Profile data synced successfully!',
              data: userData,
            ),
          );

          debugPrint('✅ Profile sync completed successfully');
        } catch (e) {
          attempts++;
          debugPrint('⚠️ Sync attempt $attempts failed: $e');

          if (attempts < _maxRetries) {
            debugPrint('📤 Retrying in ${_retryDelay.inSeconds}s...');
            await Future.delayed(_retryDelay);
          } else {
            // Max retries reached
            await _profileCacheService.incrementSyncFailedCount();

            await _fireEvent(
              ProfileSyncEvent(
                type: ProfileSyncEventType.syncFailed,
                message:
                    'Failed to sync after $_maxRetries attempts. Data remains cached.',
                data: userData,
              ),
            );

            debugPrint('❌ Profile sync failed after $_maxRetries attempts');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Unexpected error during sync: $e');

      await _fireEvent(
        ProfileSyncEvent(
          type: ProfileSyncEventType.syncFailed,
          message: 'Unexpected error: $e',
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Manually trigger sync (useful after user disables Data Saver)
  Future<void> triggerManualSync() async {
    debugPrint('📤 Manual sync triggered');
    await _attemptSync();
  }

  /// Check Data Saver state and trigger sync if it was disabled
  /// Call this from settings UI when Data Saver toggle changes
  Future<void> onDataSaverModeChanged(bool isEnabled) async {
    debugPrint('📤 Data Saver mode changed: $isEnabled');
    
    if (!isEnabled && await _profileCacheService.hasPendingUpdate()) {
      debugPrint('📤 Data Saver disabled with pending updates, attempting sync');
      await triggerManualSync();
    }
    
    _lastDataSaverState = isEnabled;
  }

  /// Get whether sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final hasPending = await _profileCacheService.hasPendingUpdate();
    final timestamp = await _profileCacheService.getPendingUpdateTimestamp();
    final failedCount = _profileCacheService.getSyncFailedCount();

    return {
      'hasPendingUpdate': hasPending,
      'pendingUpdateTimestamp': timestamp?.toIso8601String(),
      'syncFailedCount': failedCount,
      'isSyncing': _isSyncing,
      'currentConnectionType': _connectivityService.currentConnectionType.toString(),
      'isWiFiAvailable': _connectivityService.isWiFi,
    };
  }

  /// Fire a sync event to listeners
  Future<void> _fireEvent(ProfileSyncEvent event) async {
    try {
      await _onSyncEvent?.call(event);
    } catch (e) {
      debugPrint('❌ Error firing sync event: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    debugPrint('📤 ProfileSyncService disposed');
  }
}
