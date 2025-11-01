import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';

/// Service for persisting unsynced profile changes locally
/// 
/// When Data Saver Mode is active and an update is attempted:
/// - User data is saved to local storage instead of uploading immediately
/// - Data persists across app restarts
/// - Once sync conditions are met (Wi-Fi available or Data Saver disabled),
///   the service triggers a sync operation
class ProfileCacheService {
  static final ProfileCacheService _instance = ProfileCacheService._internal();

  factory ProfileCacheService() {
    return _instance;
  }

  ProfileCacheService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Storage keys
  static const String _pendingUpdateKey = 'profile_pending_update';
  static const String _pendingUpdateTimestampKey = 'profile_pending_update_timestamp';
  static const String _syncFailedCountKey = 'profile_sync_failed_count';

  /// Initialize the profile cache service
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugPrint('💾 ProfileCacheService initialized');
  }

  /// Save pending profile update locally
  /// Returns the timestamp when the update was saved
  Future<DateTime> savePendingUpdate(UserModel userData) async {
    _ensureInitialized();
    
    try {
      // Convert UserModel to Map and handle non-JSON-serializable fields
      final userMap = userData.toMap();
      final cleanMap = _cleanFirestoreFields(userMap);
      final userJson = jsonEncode(cleanMap);
      final timestamp = DateTime.now();
      
      await Future.wait([
        _prefs.setString(_pendingUpdateKey, userJson),
        _prefs.setString(_pendingUpdateTimestampKey, timestamp.toIso8601String()),
      ]);
      
      debugPrint(
        '💾 Profile update saved locally (UID: ${userData.uid}, saved at: $timestamp)',
      );
      
      return timestamp;
    } catch (e) {
      debugPrint('❌ Error saving pending profile update: $e');
      rethrow;
    }
  }

  /// Clean Firestore-specific types (Timestamp, GeoPoint) for JSON serialization
  Map<String, dynamic> _cleanFirestoreFields(Map<String, dynamic> map) {
    final cleaned = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final value = entry.value;
      
      // Handle Timestamp objects (convert to ISO8601 string)
      if (value.runtimeType.toString().contains('Timestamp')) {
        // Firestore Timestamp has toDate() method
        cleaned[entry.key] = (value as dynamic).toDate().toIso8601String();
      }
      // Handle nested maps
      else if (value is Map<String, dynamic>) {
        cleaned[entry.key] = _cleanFirestoreFields(value);
      }
      // Handle lists
      else if (value is List) {
        cleaned[entry.key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _cleanFirestoreFields(item);
          }
          return item;
        }).toList();
      }
      // Keep other values as is
      else {
        cleaned[entry.key] = value;
      }
    }
    
    return cleaned;
  }

  /// Retrieve pending profile update from local storage
  Future<UserModel?> getPendingUpdate() async {
    _ensureInitialized();
    
    try {
      final userJson = _prefs.getString(_pendingUpdateKey);
      if (userJson == null) {
        debugPrint('💾 No pending profile update found');
        return null;
      }
      
      final userMapFromJson = jsonDecode(userJson) as Map<String, dynamic>;
      
      // Convert ISO8601 date strings back to DateTime objects
      final userMap = _restoreFirestoreFields(userMapFromJson);
      
      final userData = UserModel.fromMap(
        userMap,
        documentId: userMap['uid'] as String? ?? '',
      );
      
      debugPrint('💾 Retrieved pending profile update (UID: ${userData.uid})');
      return userData;
    } catch (e) {
      debugPrint('❌ Error retrieving pending profile update: $e');
      return null;
    }
  }

  /// Restore Firestore field types from their JSON representations
  /// Converts ISO8601 date strings back to DateTime
  Map<String, dynamic> _restoreFirestoreFields(Map<String, dynamic> map) {
    final restored = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final value = entry.value;
      
      // Handle date strings that look like ISO8601 (createdAt was a Timestamp)
      if (entry.key == 'createdAt' && value is String) {
        try {
          restored[entry.key] = DateTime.parse(value);
        } catch (_) {
          restored[entry.key] = value;
        }
      }
      // Handle nested maps
      else if (value is Map<String, dynamic>) {
        restored[entry.key] = _restoreFirestoreFields(value);
      }
      // Handle lists
      else if (value is List) {
        restored[entry.key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _restoreFirestoreFields(item);
          }
          return item;
        }).toList();
      }
      // Keep other values as is
      else {
        restored[entry.key] = value;
      }
    }
    
    return restored;
  }

  /// Get timestamp of when the pending update was saved
  Future<DateTime?> getPendingUpdateTimestamp() async {
    _ensureInitialized();
    
    try {
      final timestamp = _prefs.getString(_pendingUpdateTimestampKey);
      if (timestamp == null) return null;
      
      return DateTime.parse(timestamp);
    } catch (e) {
      debugPrint('❌ Error parsing pending update timestamp: $e');
      return null;
    }
  }

  /// Check if there is a pending profile update
  Future<bool> hasPendingUpdate() async {
    _ensureInitialized();
    return _prefs.containsKey(_pendingUpdateKey);
  }

  /// Clear pending profile update
  Future<void> clearPendingUpdate() async {
    _ensureInitialized();
    
    try {
      await Future.wait([
        _prefs.remove(_pendingUpdateKey),
        _prefs.remove(_pendingUpdateTimestampKey),
        _prefs.remove(_syncFailedCountKey),
      ]);
      
      debugPrint('💾 Pending profile update cleared');
    } catch (e) {
      debugPrint('❌ Error clearing pending profile update: $e');
      rethrow;
    }
  }

  /// Increment sync failed count (for retry logic)
  Future<int> incrementSyncFailedCount() async {
    _ensureInitialized();
    
    try {
      int count = _prefs.getInt(_syncFailedCountKey) ?? 0;
      count++;
      await _prefs.setInt(_syncFailedCountKey, count);
      debugPrint('💾 Sync failed count incremented to: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Error incrementing sync failed count: $e');
      return 0;
    }
  }

  /// Get sync failed count
  int getSyncFailedCount() {
    _ensureInitialized();
    return _prefs.getInt(_syncFailedCountKey) ?? 0;
  }

  /// Reset sync failed count
  Future<void> resetSyncFailedCount() async {
    _ensureInitialized();
    
    try {
      await _prefs.remove(_syncFailedCountKey);
      debugPrint('💾 Sync failed count reset');
    } catch (e) {
      debugPrint('❌ Error resetting sync failed count: $e');
      rethrow;
    }
  }

  /// Get profile cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    _ensureInitialized();
    
    try {
      final hasPending = await hasPendingUpdate();
      final timestamp = await getPendingUpdateTimestamp();
      final failedCount = getSyncFailedCount();
      
      return {
        'hasPendingUpdate': hasPending,
        'pendingUpdateTimestamp': timestamp?.toIso8601String(),
        'syncFailedCount': failedCount,
      };
    } catch (e) {
      debugPrint('❌ Error getting cache stats: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ProfileCacheService must be initialized by calling init() before use.',
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    debugPrint('💾 ProfileCacheService disposed');
  }
}
