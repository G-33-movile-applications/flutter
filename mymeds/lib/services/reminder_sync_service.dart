import 'package:flutter/foundation.dart';
import '../models/medication_reminder.dart';
import '../models/adherence_event.dart';
import '../services/reminders_cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/user_session.dart';
import '../repositories/reminder_repository.dart';

/// Service for syncing medication reminders between Firestore and local cache
/// 
/// Implements eventual connectivity pattern:
/// - Load from cache first (instant UI)
/// - Sync with Firestore when online
/// - Auto-retry failed syncs
/// - Queue offline operations
/// - Updates UserSession for UI synchronization
class ReminderSyncService {
  // Singleton pattern
  static final ReminderSyncService _instance = ReminderSyncService._internal();
  factory ReminderSyncService() => _instance;
  ReminderSyncService._internal();
  
  final RemindersCacheService _cache = RemindersCacheService();
  final ConnectivityService _connectivity = ConnectivityService();
  final ReminderRepository _repository = ReminderRepository();
  
  /// Load reminders with offline-first strategy
  /// 
  /// Strategy:
  /// 1. Return cached data immediately if available
  /// 2. If online, sync with Firestore in background
  /// 3. Update cache with fresh data
  /// 4. If offline, return cached data only
  Future<List<MedicationReminder>> loadReminders(String userId, {bool forceRefresh = false}) async {
    debugPrint('🔄 [RemindersSync] Loading reminders for user: $userId (forceRefresh: $forceRefresh)');
    
    // Step 1: Always try to load from cache first (even with forceRefresh)
    final cachedReminders = await _cache.getCachedReminders(userId);
    
    // Step 2: Check connectivity BEFORE attempting refresh
    final isOnline = await _connectivity.checkConnectivity();
    
    if (!isOnline) {
      debugPrint('📴 [RemindersSync] Offline - returning cached data only');
      // Return cache even if expired when offline
      if (cachedReminders != null && cachedReminders.isNotEmpty) {
        // Update UserSession for UI synchronization
        UserSession().currentReminders.value = cachedReminders;
        return cachedReminders;
      }
      // Return even expired cache as fallback
      final expiredCache = await _cache.getCachedReminders(userId, ignoreExpiry: true);
      if (expiredCache != null && expiredCache.isNotEmpty) {
        UserSession().currentReminders.value = expiredCache;
      }
      return expiredCache ?? [];
    }
    
    // If we have cache and not forcing refresh, return it and sync in background
    if (!forceRefresh && cachedReminders != null && cachedReminders.isNotEmpty) {
      debugPrint('✅ [RemindersSync] Returning ${cachedReminders.length} cached reminders');
      
      // Update UserSession for UI synchronization
      UserSession().currentReminders.value = cachedReminders;
      
      // Start background sync if online
      _backgroundSync(userId);
      
      return cachedReminders;
    }
    
    // Step 3: Fetch from Firestore (only when online)
    try {
      debugPrint('🌐 [RemindersSync] Fetching reminders from Firestore...');
      final reminders = await _fetchRemindersFromBackend(userId);
      
      // Sort by time (earliest first)
      reminders.sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });
      
      debugPrint('✅ [RemindersSync] Fetched ${reminders.length} reminders from Firestore');
      
      // Step 4: Update cache
      await _cache.cacheReminders(userId, reminders);
      
      // Update UserSession for UI synchronization
      UserSession().currentReminders.value = reminders;
      
      return reminders;
    } catch (e) {
      debugPrint('❌ [RemindersSync] Failed to fetch reminders: $e');
      
      // Fallback to cache if Firestore fails (even expired cache)
      if (cachedReminders != null && cachedReminders.isNotEmpty) {
        debugPrint('⚠️ [RemindersSync] Returning cache due to error');
        UserSession().currentReminders.value = cachedReminders;
        return cachedReminders;
      }
      
      // Try to return even expired cache as last resort
      final expiredCache = await _cache.getCachedReminders(userId, ignoreExpiry: true);
      if (expiredCache != null && expiredCache.isNotEmpty) {
        debugPrint('⚠️ [RemindersSync] Returning expired cache due to error');
        UserSession().currentReminders.value = expiredCache;
        return expiredCache;
      }
      
      rethrow;
    }
  }
  
  /// Background sync (non-blocking)
  void _backgroundSync(String userId) {
    Future.delayed(Duration.zero, () async {
      try {
        final isOnline = await _connectivity.checkConnectivity();
        if (!isOnline) return;
        
        debugPrint('🔄 [RemindersSync] Background sync started...');
        final reminders = await _fetchRemindersFromBackend(userId);
        reminders.sort((a, b) {
          final aMinutes = a.time.hour * 60 + a.time.minute;
          final bMinutes = b.time.hour * 60 + b.time.minute;
          return aMinutes.compareTo(bMinutes);
        });
        
        await _cache.cacheReminders(userId, reminders);
        
        // Update UserSession for UI synchronization
        UserSession().currentReminders.value = reminders;
        
        debugPrint('✅ [RemindersSync] Background sync completed (${reminders.length} reminders)');
      } catch (e) {
        debugPrint('⚠️ [RemindersSync] Background sync failed: $e');
      }
    });
  }
  
  /// Push pending reminder changes to backend
  Future<void> pushPendingReminderChanges(String userId) async {
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [RemindersSync] Offline - cannot push pending changes');
      return;
    }
    
    try {
      debugPrint('🔄 [RemindersSync] Pushing pending reminder changes...');
      
      // Get all reminders from cache
      final reminders = await _cache.getCachedReminders(userId, ignoreExpiry: true) ?? [];
      
      // Find reminders with pending sync status
      final pendingReminders = reminders.where((r) => r.syncStatus == SyncStatus.pending).toList();
      
      if (pendingReminders.isEmpty) {
        debugPrint('✅ [RemindersSync] No pending reminder changes');
        return;
      }
      
      debugPrint('📤 [RemindersSync] Found ${pendingReminders.length} pending reminders to sync');
      
      // Push each pending reminder to backend
      for (final reminder in pendingReminders) {
        try {
          await _pushReminderToBackend(userId, reminder);
          
          // Update sync status in cache
          final updatedReminder = reminder.copyWith(
            syncStatus: SyncStatus.synced,
            lastSyncedAt: DateTime.now(),
          );
          
          // Update cache with synced reminder
          final allReminders = await _cache.getCachedReminders(userId, ignoreExpiry: true) ?? [];
          final updatedReminders = allReminders.map((r) => r.id == reminder.id ? updatedReminder : r).toList();
          await _cache.cacheReminders(userId, updatedReminders);
          
          debugPrint('✅ [RemindersSync] Synced reminder: ${reminder.medicineName}');
        } catch (e) {
          debugPrint('❌ [RemindersSync] Failed to sync reminder ${reminder.medicineName}: $e');
          
          // Mark as failed
          final failedReminder = reminder.copyWith(syncStatus: SyncStatus.failed);
          final allReminders = await _cache.getCachedReminders(userId, ignoreExpiry: true) ?? [];
          final updatedReminders = allReminders.map((r) => r.id == reminder.id ? failedReminder : r).toList();
          await _cache.cacheReminders(userId, updatedReminders);
        }
      }
      
      debugPrint('✅ [RemindersSync] Completed pushing reminder changes');
    } catch (e) {
      debugPrint('❌ [RemindersSync] Error pushing pending reminder changes: $e');
    }
  }
  
  /// Push pending adherence events to backend
  Future<void> pushPendingAdherenceEvents(String userId) async {
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [RemindersSync] Offline - cannot push pending adherence events');
      return;
    }
    
    try {
      debugPrint('🔄 [RemindersSync] Pushing pending adherence events...');
      
      // Get pending adherence events from cache
      final pendingEvents = await _cache.getPendingAdherenceEvents(userId);
      
      if (pendingEvents.isEmpty) {
        debugPrint('✅ [RemindersSync] No pending adherence events');
        return;
      }
      
      debugPrint('📤 [RemindersSync] Found ${pendingEvents.length} pending adherence events to sync');
      
      // Push each pending event to backend
      for (final event in pendingEvents) {
        try {
          await _pushAdherenceEventToBackend(userId, event);
          
          // Update sync status in cache
          await _cache.updateAdherenceEventSyncStatus(userId, event.id, SyncStatus.synced);
          
          debugPrint('✅ [RemindersSync] Synced adherence event: ${event.id}');
        } catch (e) {
          debugPrint('❌ [RemindersSync] Failed to sync adherence event ${event.id}: $e');
          
          // Mark as failed
          await _cache.updateAdherenceEventSyncStatus(userId, event.id, SyncStatus.failed);
        }
      }
      
      debugPrint('✅ [RemindersSync] Completed pushing adherence events');
    } catch (e) {
      debugPrint('❌ [RemindersSync] Error pushing pending adherence events: $e');
    }
  }
  
  /// Stream reminders with real-time updates
  /// 
  /// Returns a stream that:
  /// - Emits cached data immediately
  /// - Updates with fresh data when online
  /// - Handles connectivity changes
  Stream<List<MedicationReminder>> streamReminders(String userId) async* {
    // Emit cached data first
    final cachedReminders = await _cache.getCachedReminders(userId);
    if (cachedReminders != null && cachedReminders.isNotEmpty) {
      debugPrint('📦 [RemindersSync] Emitting ${cachedReminders.length} cached reminders');
      yield cachedReminders;
    }
    
    // Check connectivity and fetch fresh data
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [RemindersSync] Offline - no fresh data available');
      return;
    }
    
    try {
      final reminders = await _fetchRemindersFromBackend(userId);
      reminders.sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });
      
      await _cache.cacheReminders(userId, reminders);
      
      debugPrint('🌐 [RemindersSync] Emitting ${reminders.length} fresh reminders');
      yield reminders;
    } catch (e) {
      debugPrint('❌ [RemindersSync] Stream error: $e');
    }
  }
  
  /// Force refresh from Firestore
  Future<List<MedicationReminder>> forceRefresh(String userId) async {
    return await loadReminders(userId, forceRefresh: true);
  }
  
  /// Clear cache for user
  Future<void> clearCache(String userId) async {
    await _cache.clearCache(userId);
  }
  
  /// Get cache metadata
  Future<Map<String, dynamic>?> getCacheMetadata(String userId) async {
    return await _cache.getCacheMetadata(userId);
  }
  
  // ========== BACKEND INTEGRATION METHODS ==========
  
  /// Fetch reminders from backend (Firestore)
  Future<List<MedicationReminder>> _fetchRemindersFromBackend(String userId) async {
    try {
      return await _repository.getUserReminders(userId);
    } catch (e) {
      debugPrint('❌ [RemindersSync] Error fetching from Firestore: $e');
      rethrow;
    }
  }
  
  /// Push reminder to backend (Firestore)
  Future<void> _pushReminderToBackend(String userId, MedicationReminder reminder) async {
    try {
      // Try to update first, if it doesn't exist, create it
      await _repository.updateReminder(userId, reminder);
    } catch (e) {
      debugPrint('❌ [RemindersSync] Error pushing reminder to Firestore: $e');
      rethrow;
    }
  }
  
  /// Push adherence event to backend (Firestore)
  /// TODO: Implement adherence events collection in Firestore
  Future<void> _pushAdherenceEventToBackend(String userId, AdherenceEvent event) async {
    // Placeholder: Adherence events tracking will be implemented later
    // This would store in usuarios/{userId}/adherenceEvents/{eventId}
    debugPrint('⚠️ [RemindersSync] Adherence events not yet implemented in Firestore');
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
