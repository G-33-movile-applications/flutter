import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing persistent local storage using SharedPreferences.
/// 
/// This service handles storing and retrieving user session data to enable
/// the user to stay logged in across app restarts for up to 24 hours.
/// 
/// Usage:
/// ```dart
/// // Save session after login
/// await StorageService().saveUserSession(sessionData);
/// 
/// // Restore session on startup
/// final session = await StorageService().getUserSession();
/// 
/// // Clear session on logout
/// await StorageService().clearUserSession();
/// ```
class StorageService {
  // Singleton pattern
  StorageService._internal();
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  // Storage keys
  static const String _keyUserId = 'user_session_uid';
  static const String _keyEmail = 'user_session_email';
  static const String _keyDisplayName = 'user_session_display_name';
  static const String _keyToken = 'user_session_token';
  static const String _keyLastLogin = 'user_session_last_login';
  
  // Session validity duration (24 hours)
  static const Duration sessionDuration = Duration(hours: 24);
  
  SharedPreferences? _prefs;

  /// Initialize SharedPreferences instance
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('StorageService: Initialized successfully');
    } catch (e) {
      debugPrint('StorageService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Get SharedPreferences instance, initializing if necessary
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Save user session data to local storage
  /// 
  /// Stores the user's session information including UID, email, display name,
  /// auth token, and login timestamp for persistence across app restarts.
  /// 
  /// Parameters:
  /// - [uid]: User's unique identifier
  /// - [email]: User's email address
  /// - [displayName]: User's display name
  /// - [token]: Authentication token (optional, can be null for Firebase Auth)
  Future<void> saveUserSession({
    required String uid,
    required String email,
    required String displayName,
    String? token,
  }) async {
    try {
      final prefs = await _preferences;
      
      final now = DateTime.now().toIso8601String();
      
      await Future.wait([
        prefs.setString(_keyUserId, uid),
        prefs.setString(_keyEmail, email),
        prefs.setString(_keyDisplayName, displayName),
        prefs.setString(_keyToken, token ?? ''),
        prefs.setString(_keyLastLogin, now),
      ]);
      
      debugPrint('StorageService: Session saved for user $uid at $now');
    } catch (e) {
      debugPrint('StorageService: Failed to save session: $e');
      rethrow;
    }
  }

  /// Retrieve user session data from local storage
  /// 
  /// Returns a Map containing session data if it exists, or null if no session
  /// is stored. Does not check validity - use [isSessionValid] for that.
  /// 
  /// Returns:
  /// - Map with keys: uid, email, displayName, token, lastLogin
  /// - null if no session exists
  Future<Map<String, String>?> getUserSession() async {
    try {
      final prefs = await _preferences;
      
      final uid = prefs.getString(_keyUserId);
      
      // If no UID exists, there's no session
      if (uid == null || uid.isEmpty) {
        debugPrint('StorageService: No session found');
        return null;
      }
      
      final email = prefs.getString(_keyEmail) ?? '';
      final displayName = prefs.getString(_keyDisplayName) ?? '';
      final token = prefs.getString(_keyToken) ?? '';
      final lastLogin = prefs.getString(_keyLastLogin) ?? '';
      
      debugPrint('StorageService: Session retrieved for user $uid');
      
      return {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'token': token,
        'lastLogin': lastLogin,
      };
    } catch (e) {
      debugPrint('StorageService: Failed to retrieve session: $e');
      return null;
    }
  }

  /// Clear user session data from local storage
  /// 
  /// Removes all session-related data. Called during logout or session expiration.
  Future<void> clearUserSession() async {
    try {
      final prefs = await _preferences;
      
      await Future.wait([
        prefs.remove(_keyUserId),
        prefs.remove(_keyEmail),
        prefs.remove(_keyDisplayName),
        prefs.remove(_keyToken),
        prefs.remove(_keyLastLogin),
      ]);
      
      debugPrint('StorageService: Session cleared');
    } catch (e) {
      debugPrint('StorageService: Failed to clear session: $e');
      rethrow;
    }
  }

  /// Check if the stored session is still valid
  /// 
  /// A session is valid if:
  /// 1. Session data exists
  /// 2. The last login timestamp is within the validity period (24 hours)
  /// 
  /// Returns:
  /// - true if session exists and is valid
  /// - false if session doesn't exist or has expired
  Future<bool> isSessionValid() async {
    try {
      final session = await getUserSession();
      
      if (session == null) {
        debugPrint('StorageService: No session to validate');
        return false;
      }
      
      final lastLoginStr = session['lastLogin'] ?? '';
      if (lastLoginStr.isEmpty) {
        debugPrint('StorageService: No last login timestamp found');
        return false;
      }
      
      final lastLogin = DateTime.parse(lastLoginStr);
      final now = DateTime.now();
      final difference = now.difference(lastLogin);
      
      final isValid = difference < sessionDuration;
      
      if (isValid) {
        debugPrint('StorageService: Session is valid (${difference.inHours}h old)');
      } else {
        debugPrint('StorageService: Session expired (${difference.inHours}h old) – user must log in again');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('StorageService: Error validating session: $e');
      return false;
    }
  }

  /// Get the remaining time until session expiration
  /// 
  /// Returns null if no session exists or if there's an error.
  Future<Duration?> getSessionTimeRemaining() async {
    try {
      final session = await getUserSession();
      
      if (session == null) return null;
      
      final lastLoginStr = session['lastLogin'] ?? '';
      if (lastLoginStr.isEmpty) return null;
      
      final lastLogin = DateTime.parse(lastLoginStr);
      final expirationTime = lastLogin.add(sessionDuration);
      final now = DateTime.now();
      
      if (now.isAfter(expirationTime)) {
        return Duration.zero;
      }
      
      return expirationTime.difference(now);
    } catch (e) {
      debugPrint('StorageService: Error getting session time remaining: $e');
      return null;
    }
  }

  /// Save a generic key-value pair to storage
  Future<void> saveString(String key, String value) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('StorageService: Failed to save string for key $key: $e');
      rethrow;
    }
  }

  /// Retrieve a generic string value from storage
  Future<String?> getString(String key) async {
    try {
      final prefs = await _preferences;
      return prefs.getString(key);
    } catch (e) {
      debugPrint('StorageService: Failed to get string for key $key: $e');
      return null;
    }
  }

  /// Remove a generic key from storage
  Future<void> remove(String key) async {
    try {
      final prefs = await _preferences;
      await prefs.remove(key);
    } catch (e) {
      debugPrint('StorageService: Failed to remove key $key: $e');
      rethrow;
    }
  }

  /// Clear all data from storage (use with caution!)
  Future<void> clearAll() async {
    try {
      final prefs = await _preferences;
      await prefs.clear();
      debugPrint('StorageService: All data cleared');
    } catch (e) {
      debugPrint('StorageService: Failed to clear all data: $e');
      rethrow;
    }
  }
}
