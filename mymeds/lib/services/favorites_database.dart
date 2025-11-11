import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/favorite_pharmacy.dart';

/// SQLite database service for favorite pharmacies
/// 
/// Features:
/// - Local SQLite persistence for offline access
/// - User-specific favorites with isolation
/// - Support for explicit favorites and automatic visit tracking
/// - Lightweight and fast queries
/// - Database lifecycle management
class FavoritesDatabase {
  // Singleton pattern
  static final FavoritesDatabase _instance = FavoritesDatabase._internal();
  factory FavoritesDatabase() => _instance;
  FavoritesDatabase._internal();

  static Database? _database;
  static const String _databaseName = 'mymeds_favorites.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'favorite_pharmacies';

  /// Get database instance (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite database
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      debugPrint('💾 [FavoritesDB] Initializing database at: $path');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to initialize database: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('📦 [FavoritesDB] Creating database tables...');

    await db.execute('''
      CREATE TABLE $_tableName (
        user_id TEXT NOT NULL,
        pharmacy_id TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        visits_count INTEGER NOT NULL DEFAULT 0,
        last_visited TEXT NOT NULL,
        favorite_marked_at TEXT,
        pharmacy_name TEXT,
        pharmacy_address TEXT,
        pharmacy_lat REAL,
        pharmacy_lng REAL,
        PRIMARY KEY (user_id, pharmacy_id)
      )
    ''');

    // Create indices for fast queries
    await db.execute('''
      CREATE INDEX idx_user_favorites 
      ON $_tableName (user_id, is_favorite)
    ''');

    await db.execute('''
      CREATE INDEX idx_user_visits 
      ON $_tableName (user_id, visits_count DESC)
    ''');

    debugPrint('✅ [FavoritesDB] Database tables created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 [FavoritesDB] Upgrading database from v$oldVersion to v$newVersion');
    
    // Future migration logic goes here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $_tableName ADD COLUMN new_field TEXT');
    // }
  }

  // ==================== CRUD OPERATIONS ====================

  /// Insert or update favorite pharmacy
  Future<void> insertOrUpdate(FavoritePharmacy favorite) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        favorite.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('💾 [FavoritesDB] Saved: ${favorite.pharmacyId} for user ${favorite.userId}');
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to insert/update: $e');
      rethrow;
    }
  }

  /// Insert or update multiple favorites (batch operation)
  Future<void> insertOrUpdateBatch(List<FavoritePharmacy> favorites) async {
    if (favorites.isEmpty) return;

    try {
      final db = await database;
      final batch = db.batch();

      for (final favorite in favorites) {
        batch.insert(
          _tableName,
          favorite.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      debugPrint('💾 [FavoritesDB] Batch saved ${favorites.length} favorites');
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to batch insert/update: $e');
      rethrow;
    }
  }

  /// Get all favorites for a user
  Future<List<FavoritePharmacy>> getFavorites(String userId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'user_id = ? AND is_favorite = ?',
        whereArgs: [userId, 1],
        orderBy: 'favorite_marked_at DESC',
      );

      return maps.map((map) => FavoritePharmacy.fromDb(map)).toList();
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to get favorites: $e');
      return [];
    }
  }

  /// Get frequent pharmacies (ordered by visit count)
  Future<List<FavoritePharmacy>> getFrequentPharmacies(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'visits_count DESC, last_visited DESC',
        limit: limit,
      );

      return maps.map((map) => FavoritePharmacy.fromDb(map)).toList();
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to get frequent pharmacies: $e');
      return [];
    }
  }

  /// Get specific favorite/pharmacy data
  Future<FavoritePharmacy?> getFavorite(String userId, String pharmacyId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'user_id = ? AND pharmacy_id = ?',
        whereArgs: [userId, pharmacyId],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return FavoritePharmacy.fromDb(maps.first);
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to get favorite: $e');
      return null;
    }
  }

  /// Check if pharmacy is favorited
  Future<bool> isFavorite(String userId, String pharmacyId) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        columns: ['is_favorite'],
        where: 'user_id = ? AND pharmacy_id = ? AND is_favorite = ?',
        whereArgs: [userId, pharmacyId, 1],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to check favorite status: $e');
      return false;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(
    String userId,
    String pharmacyId, {
    String? pharmacyName,
    String? pharmacyAddress,
    double? pharmacyLat,
    double? pharmacyLng,
  }) async {
    try {
      final existing = await getFavorite(userId, pharmacyId);
      final now = DateTime.now();

      final favorite = existing?.copyWith(
            isFavorite: !existing.isFavorite,
            favoriteMarkedAt: !existing.isFavorite ? now : null,
            lastVisited: now,
          ) ??
          FavoritePharmacy(
            userId: userId,
            pharmacyId: pharmacyId,
            isFavorite: true,
            visitsCount: 0,
            lastVisited: now,
            favoriteMarkedAt: now,
            pharmacyName: pharmacyName,
            pharmacyAddress: pharmacyAddress,
            pharmacyLat: pharmacyLat,
            pharmacyLng: pharmacyLng,
          );

      await insertOrUpdate(favorite);
      return favorite.isFavorite;
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to toggle favorite: $e');
      rethrow;
    }
  }

  /// Increment visit count for a pharmacy
  Future<void> incrementVisitCount(
    String userId,
    String pharmacyId, {
    String? pharmacyName,
    String? pharmacyAddress,
    double? pharmacyLat,
    double? pharmacyLng,
  }) async {
    try {
      final existing = await getFavorite(userId, pharmacyId);
      final now = DateTime.now();

      final favorite = existing?.copyWith(
            visitsCount: existing.visitsCount + 1,
            lastVisited: now,
          ) ??
          FavoritePharmacy(
            userId: userId,
            pharmacyId: pharmacyId,
            isFavorite: false,
            visitsCount: 1,
            lastVisited: now,
            pharmacyName: pharmacyName,
            pharmacyAddress: pharmacyAddress,
            pharmacyLat: pharmacyLat,
            pharmacyLng: pharmacyLng,
          );

      await insertOrUpdate(favorite);
      debugPrint('📈 [FavoritesDB] Incremented visits for $pharmacyId: ${favorite.visitsCount}');
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to increment visit count: $e');
    }
  }

  /// Delete a favorite
  Future<void> delete(String userId, String pharmacyId) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'user_id = ? AND pharmacy_id = ?',
        whereArgs: [userId, pharmacyId],
      );
      debugPrint('🗑️ [FavoritesDB] Deleted favorite: $pharmacyId');
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to delete favorite: $e');
    }
  }

  /// Clear all favorites for a user (on logout)
  Future<void> clearUserFavorites(String userId) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      debugPrint('🗑️ [FavoritesDB] Cleared all favorites for user: $userId');
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to clear user favorites: $e');
    }
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete(_tableName);
      debugPrint('🗑️ [FavoritesDB] Cleared all favorites');
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to clear all: $e');
    }
  }

  /// Get all favorites for syncing
  Future<List<FavoritePharmacy>> getAllForSync(String userId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      return maps.map((map) => FavoritePharmacy.fromDb(map)).toList();
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to get favorites for sync: $e');
      return [];
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getStats(String userId) async {
    try {
      final db = await database;
      
      final favoritesCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE user_id = ? AND is_favorite = ?',
        [userId, 1],
      )) ?? 0;
      
      final visitedCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE user_id = ? AND visits_count > ?',
        [userId, 0],
      )) ?? 0;
      
      final totalVisits = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT SUM(visits_count) FROM $_tableName WHERE user_id = ?',
        [userId],
      )) ?? 0;

      return {
        'favorites': favoritesCount,
        'visited': visitedCount,
        'totalVisits': totalVisits,
      };
    } catch (e) {
      debugPrint('❌ [FavoritesDB] Failed to get stats: $e');
      return {'favorites': 0, 'visited': 0, 'totalVisits': 0};
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('🔒 [FavoritesDB] Database closed');
    }
  }
}
