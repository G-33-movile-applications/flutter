import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/favorite_pharmacy.dart';
import '../models/punto_fisico.dart';
import '../services/favorites_database.dart';
import '../services/connectivity_service.dart';
import '../services/user_session.dart';

/// Service for managing favorite pharmacies with eventual connectivity
/// 
/// Features:
/// - Offline-first with SQLite persistence
/// - Automatic sync with Firestore when online
/// - Visit tracking for frequent pharmacies
/// - User-specific favorites with isolation
/// - Firestore subcollection: usuarios/{userId}/favorite_pharmacies/{pharmacyId}
class FavoritesService {
  // Singleton pattern
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final FavoritesDatabase _db = FavoritesDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize the service
  Future<void> init() async {
    try {
      // Database will be lazily initialized on first access
      debugPrint('✅ [FavoritesService] Service initialized');
    } catch (e) {
      debugPrint('❌ [FavoritesService] Initialization error: $e');
    }
  }

  // ==================== FAVORITES OPERATIONS ====================

  /// Get all favorites for current user
  Future<List<FavoritePharmacy>> getFavorites() async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      debugPrint('⚠️ [FavoritesService] No user logged in');
      return [];
    }

    return await _db.getFavorites(userId);
  }

  /// Get frequent pharmacies (by visit count)
  Future<List<FavoritePharmacy>> getFrequentPharmacies({int limit = 10}) async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      debugPrint('⚠️ [FavoritesService] No user logged in');
      return [];
    }

    return await _db.getFrequentPharmacies(userId, limit: limit);
  }

  /// Check if a pharmacy is favorited
  Future<bool> isFavorite(String pharmacyId) async {
    final userId = UserSession().currentUid;
    if (userId == null) return false;

    return await _db.isFavorite(userId, pharmacyId);
  }

  /// Toggle favorite status for a pharmacy
  Future<bool> toggleFavorite(PuntoFisico pharmacy) async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      // Update local database
      final isFavorite = await _db.toggleFavorite(
        userId,
        pharmacy.id,
        pharmacyName: pharmacy.nombre,
        pharmacyAddress: pharmacy.direccion,
        pharmacyLat: pharmacy.latitud,
        pharmacyLng: pharmacy.longitud,
      );

      debugPrint('💖 [FavoritesService] Toggled favorite: ${pharmacy.nombre} = $isFavorite');

      // Sync with Firestore if online
      _syncToFirestore(userId);

      return isFavorite;
    } catch (e) {
      debugPrint('❌ [FavoritesService] Failed to toggle favorite: $e');
      rethrow;
    }
  }

  /// Track a visit to a pharmacy (increment visit count)
  Future<void> trackVisit(PuntoFisico pharmacy) async {
    final userId = UserSession().currentUid;
    if (userId == null) return;

    try {
      await _db.incrementVisitCount(
        userId,
        pharmacy.id,
        pharmacyName: pharmacy.nombre,
        pharmacyAddress: pharmacy.direccion,
        pharmacyLat: pharmacy.latitud,
        pharmacyLng: pharmacy.longitud,
      );

      debugPrint('📍 [FavoritesService] Tracked visit to: ${pharmacy.nombre}');

      // Sync with Firestore if online (in background)
      _syncToFirestore(userId);
    } catch (e) {
      debugPrint('❌ [FavoritesService] Failed to track visit: $e');
    }
  }

  /// Remove a favorite
  Future<void> removeFavorite(String pharmacyId) async {
    final userId = UserSession().currentUid;
    if (userId == null) return;

    try {
      await _db.delete(userId, pharmacyId);
      debugPrint('🗑️ [FavoritesService] Removed favorite: $pharmacyId');

      // Sync with Firestore if online
      _syncToFirestore(userId);
    } catch (e) {
      debugPrint('❌ [FavoritesService] Failed to remove favorite: $e');
    }
  }

  // ==================== SYNC OPERATIONS ====================

  /// Sync local favorites to Firestore (eventual connectivity)
  Future<void> _syncToFirestore(String userId) async {
    // Check connectivity before attempting sync
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [FavoritesService] Offline - sync deferred');
      return;
    }

    try {
      final favorites = await _db.getAllForSync(userId);
      
      if (favorites.isEmpty) {
        debugPrint('📦 [FavoritesService] No favorites to sync');
        return;
      }

      debugPrint('🔄 [FavoritesService] Syncing ${favorites.length} favorites to Firestore...');

      final batch = _firestore.batch();
      final collectionRef = _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('favorite_pharmacies');

      for (final favorite in favorites) {
        final docRef = collectionRef.doc(favorite.pharmacyId);
        batch.set(docRef, favorite.toFirestore(), SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('✅ [FavoritesService] Sync completed successfully');
    } catch (e) {
      debugPrint('❌ [FavoritesService] Sync failed: $e');
      // Don't rethrow - sync failures shouldn't break the app
    }
  }

  /// Pull favorites from Firestore to local database
  Future<void> syncFromFirestore() async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      debugPrint('⚠️ [FavoritesService] No user logged in for sync');
      return;
    }

    // Check connectivity before attempting sync
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [FavoritesService] Offline - cannot sync from Firestore');
      return;
    }

    try {
      debugPrint('🔄 [FavoritesService] Syncing favorites from Firestore...');

      final snapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('favorite_pharmacies')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('📦 [FavoritesService] No favorites in Firestore');
        return;
      }

      final favorites = snapshot.docs
          .map((doc) => FavoritePharmacy.fromFirestore(doc.data()))
          .toList();

      await _db.insertOrUpdateBatch(favorites);
      debugPrint('✅ [FavoritesService] Synced ${favorites.length} favorites from Firestore');
    } catch (e) {
      debugPrint('❌ [FavoritesService] Sync from Firestore failed: $e');
    }
  }

  // ==================== USER LIFECYCLE ====================

  /// Load favorites for user on login
  Future<void> onUserLogin() async {
    final userId = UserSession().currentUid;
    if (userId == null) return;

    debugPrint('👤 [FavoritesService] User logged in: $userId');

    // Load from local database first
    final localFavorites = await _db.getFavorites(userId);
    debugPrint('📦 [FavoritesService] Loaded ${localFavorites.length} local favorites');

    // Attempt sync from Firestore in background
    syncFromFirestore();
  }

  /// Clear favorites for user on logout
  Future<void> onUserLogout() async {
    final userId = UserSession().currentUid;
    if (userId == null) return;

    try {
      debugPrint('👤 [FavoritesService] User logging out: $userId');

      // Sync to Firestore before clearing (best effort)
      await _syncToFirestore(userId);

      // Clear local cache
      await _db.clearUserFavorites(userId);
      debugPrint('✅ [FavoritesService] Cleared local favorites for user');
    } catch (e) {
      debugPrint('❌ [FavoritesService] Logout cleanup failed: $e');
    }
  }

  // ==================== STATISTICS ====================

  /// Get favorites statistics for current user
  Future<Map<String, int>> getStats() async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      return {'favorites': 0, 'visited': 0, 'totalVisits': 0};
    }

    return await _db.getStats(userId);
  }

  // ==================== CLEANUP ====================

  /// Dispose resources
  Future<void> dispose() async {
    await _db.close();
    debugPrint('🔒 [FavoritesService] Service disposed');
  }
}
