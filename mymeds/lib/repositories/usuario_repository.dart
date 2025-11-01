import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/settings_service.dart';
import '../services/profile_cache_service.dart';
import '../services/connectivity_service.dart';

class UsuarioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'usuarios';
  final SettingsService _settingsService = SettingsService();
  final ProfileCacheService _profileCacheService = ProfileCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Create a new user
  Future<void> create(UserModel usuario) async {
    try {
      await _firestore.collection(_collection).doc(usuario.uid).set(usuario.toMap());
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  // Read a user by ID
  Future<UserModel?> read(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, documentId: uid);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading user: $e');
    }
  }

  // Read all users
  Future<List<UserModel>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .where((doc) => doc.id.isNotEmpty) // Filter out documents with empty IDs
          .map((doc) => UserModel.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error reading all users: $e');
    }
  }

  // Update a user
  Future<void> update(UserModel usuario) async {
    try {
      await _firestore.collection(_collection).doc(usuario.uid).update(usuario.toMap());
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  /// Update a user with Data Saver Mode support
  /// 
  /// When Data Saver Mode is enabled OR no internet available:
  /// - The update is cached locally instead of uploaded immediately
  /// - Returns a Future that resolves immediately (non-blocking)
  /// 
  /// When Data Saver Mode is disabled AND internet is available:
  /// - The update is uploaded immediately to Firebase
  /// - Returns a Future that resolves after upload completes
  /// 
  /// Returns a tuple: (success: bool, message: String, isCached: bool)
  Future<(bool success, String message, bool isCached)> updateWithDataSaverSupport(
    UserModel usuario,
  ) async {
    try {
      final isDataSaverEnabled = _settingsService.getDataSaverMode();
      final hasInternet = _connectivityService.currentConnectionType != ConnectionType.none;

      // Cache if: Data Saver enabled OR no internet available
      if (isDataSaverEnabled || !hasInternet) {
        // Cache the update locally for later sync
        await _profileCacheService.savePendingUpdate(usuario);
        
        if (!hasInternet) {
          return (
            true,
            'You are offline. Changes have been saved locally and will sync when internet is available.',
            true,
          );
        } else {
          return (
            true,
            'Your changes have been saved locally and will be uploaded when Wi-Fi is available.',
            true,
          );
        }
      } else {
        // Update immediately (Data Saver off AND internet available)
        await update(usuario);
        return (
          true,
          'Your profile has been updated successfully.',
          false,
        );
      }
    } catch (e) {
      return (
        false,
        'Error updating profile: $e',
        false,
      );
    }
  }

  // Delete a user
  Future<void> delete(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).delete();
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  // Find user by email
  Future<UserModel?> findByEmail(String email) async {
    try {
      if (email.isEmpty) {
        throw ArgumentError('Email cannot be empty');
      }
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return UserModel.fromMap(doc.data(), documentId: doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error finding user by email: $e');
    }
  }

  // Check if user exists
  Future<bool> exists(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if user exists: $e');
    }
  }

  // Stream of user changes
  Stream<UserModel?> streamUser(String uid) {
    if (uid.isEmpty) {
      return Stream.error(ArgumentError('User ID cannot be empty'));
    }
    
    return _firestore
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null 
            ? UserModel.fromMap(doc.data()!, documentId: uid) 
            : null);
  }
}