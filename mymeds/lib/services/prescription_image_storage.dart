import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Prescription Image Storage Service
/// 
/// Manages local storage of prescription images with:
/// - Secure local directory using path_provider
/// - SQLite database for tracking image metadata and sync status
/// - Offline-first: images saved locally before upload
/// - Automatic cleanup after successful upload
/// - Pending sync queue for offline scenarios
/// 
/// Directory Structure:
/// {app_documents}/prescriptions/
///   ├── {userId}/
///   │   ├── {prescriptionId}_image.jpg
///   │   ├── {prescriptionId}_thumbnail.jpg
///   │   └── ...
/// 
/// Database Schema:
/// prescription_images table:
/// - id: TEXT PRIMARY KEY
/// - userId: TEXT NOT NULL
/// - prescriptionId: TEXT NOT NULL
/// - localPath: TEXT NOT NULL
/// - uploadMethod: TEXT ('nfc' or 'image')
/// - syncStatus: TEXT ('pending', 'syncing', 'synced', 'failed')
/// - createdAt: TEXT (ISO8601)
/// - uploadedAt: TEXT (ISO8601, nullable)
/// - fileSize: INTEGER (bytes)
/// - metadata: TEXT (JSON)
class PrescriptionImageStorage {
  // Singleton pattern
  static final PrescriptionImageStorage _instance = 
      PrescriptionImageStorage._internal();
  factory PrescriptionImageStorage() => _instance;
  PrescriptionImageStorage._internal();

  Database? _database;
  String? _storageDirectory;

  static const String _dbName = 'prescription_images.db';
  static const String _tableName = 'prescription_images';
  static const int _dbVersion = 1;

  /// Initialize storage service
  /// 
  /// Creates:
  /// - Local storage directory
  /// - SQLite database for tracking images
  Future<void> init() async {
    try {
      // Get app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _storageDirectory = path.join(appDocDir.path, 'prescriptions');

      // Create directory if it doesn't exist
      final Directory storageDir = Directory(_storageDirectory!);
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
        debugPrint('📁 Created prescription storage directory: $_storageDirectory');
      }

      // Initialize database
      await _initDatabase();

      debugPrint('✅ PrescriptionImageStorage initialized');
      debugPrint('   Storage path: $_storageDirectory');
    } catch (e) {
      debugPrint('❌ Failed to initialize PrescriptionImageStorage: $e');
      rethrow;
    }
  }

  /// Initialize SQLite database
  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, _dbName);

    _database = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );

    debugPrint('💾 Prescription images database initialized: $dbPath');
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        prescriptionId TEXT NOT NULL,
        localPath TEXT NOT NULL,
        uploadMethod TEXT NOT NULL,
        syncStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        uploadedAt TEXT,
        fileSize INTEGER NOT NULL,
        metadata TEXT,
        UNIQUE(userId, prescriptionId)
      )
    ''');

    // Create indexes for faster queries
    await db.execute('''
      CREATE INDEX idx_userId ON $_tableName(userId)
    ''');

    await db.execute('''
      CREATE INDEX idx_syncStatus ON $_tableName(syncStatus)
    ''');

    await db.execute('''
      CREATE INDEX idx_userId_syncStatus ON $_tableName(userId, syncStatus)
    ''');

    debugPrint('📊 Created prescription_images table with indexes');
  }

  // ==================== FILE OPERATIONS ====================

  /// Save prescription image to local storage
  /// 
  /// Steps:
  /// 1. Create user-specific directory
  /// 2. Save file with unique name
  /// 3. Record in database with 'pending' status
  /// 
  /// Returns: Local file path
  Future<String> saveImage({
    required String userId,
    required String prescriptionId,
    required File imageFile,
    required String uploadMethod,
    Map<String, dynamic>? metadata,
  }) async {
    if (_database == null || _storageDirectory == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      // Create user-specific directory
      final userDir = path.join(_storageDirectory!, userId);
      final Directory userDirectory = Directory(userDir);
      if (!await userDirectory.exists()) {
        await userDirectory.create(recursive: true);
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = '${prescriptionId}_${timestamp}$extension';
      final localPath = path.join(userDir, fileName);

      // Copy file to local storage
      await imageFile.copy(localPath);

      // Get file size
      final fileSize = await File(localPath).length();

      // Record in database
      await _database!.insert(
        _tableName,
        {
          'id': '$userId-$prescriptionId-$timestamp',
          'userId': userId,
          'prescriptionId': prescriptionId,
          'localPath': localPath,
          'uploadMethod': uploadMethod,
          'syncStatus': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'uploadedAt': null,
          'fileSize': fileSize,
          'metadata': metadata != null ? metadata.toString() : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('💾 Saved prescription image: $fileName (${fileSize} bytes)');
      return localPath;
    } catch (e) {
      debugPrint('❌ Failed to save prescription image: $e');
      rethrow;
    }
  }

  /// Update sync status of an image
  Future<void> updateSyncStatus({
    required String userId,
    required String prescriptionId,
    required String status,
  }) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      final uploadedAt = status == 'synced' ? DateTime.now().toIso8601String() : null;

      await _database!.update(
        _tableName,
        {
          'syncStatus': status,
          'uploadedAt': uploadedAt,
        },
        where: 'userId = ? AND prescriptionId = ?',
        whereArgs: [userId, prescriptionId],
      );

      debugPrint('🔄 Updated sync status: $prescriptionId -> $status');
    } catch (e) {
      debugPrint('❌ Failed to update sync status: $e');
    }
  }

  /// Delete image file and database record after successful upload
  Future<void> deleteAfterUpload({
    required String userId,
    required String prescriptionId,
  }) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      // Get image record
      final images = await _database!.query(
        _tableName,
        where: 'userId = ? AND prescriptionId = ?',
        whereArgs: [userId, prescriptionId],
      );

      if (images.isEmpty) {
        debugPrint('⚠️ No image found for prescription: $prescriptionId');
        return;
      }

      // Delete file
      for (final image in images) {
        final localPath = image['localPath'] as String;
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Deleted local image: $localPath');
        }
      }

      // Delete database record
      await _database!.delete(
        _tableName,
        where: 'userId = ? AND prescriptionId = ?',
        whereArgs: [userId, prescriptionId],
      );

      debugPrint('✅ Cleaned up prescription image: $prescriptionId');
    } catch (e) {
      debugPrint('❌ Failed to delete prescription image: $e');
    }
  }

  // ==================== QUERY OPERATIONS ====================

  /// Get all pending images for a user (need to be uploaded)
  Future<List<Map<String, dynamic>>> getPendingImages(String userId) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      final results = await _database!.query(
        _tableName,
        where: 'userId = ? AND syncStatus = ?',
        whereArgs: [userId, 'pending'],
        orderBy: 'createdAt ASC',
      );

      debugPrint('📋 Found ${results.length} pending images for user: $userId');
      return results;
    } catch (e) {
      debugPrint('❌ Failed to get pending images: $e');
      return [];
    }
  }

  /// Get failed uploads that need retry
  Future<List<Map<String, dynamic>>> getFailedUploads(String userId) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      final results = await _database!.query(
        _tableName,
        where: 'userId = ? AND syncStatus = ?',
        whereArgs: [userId, 'failed'],
        orderBy: 'createdAt ASC',
      );

      debugPrint('📋 Found ${results.length} failed uploads for user: $userId');
      return results;
    } catch (e) {
      debugPrint('❌ Failed to get failed uploads: $e');
      return [];
    }
  }

  /// Get local image path for prescription
  Future<String?> getLocalImagePath({
    required String userId,
    required String prescriptionId,
  }) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      final results = await _database!.query(
        _tableName,
        columns: ['localPath'],
        where: 'userId = ? AND prescriptionId = ?',
        whereArgs: [userId, prescriptionId],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final localPath = results.first['localPath'] as String;
      
      // Verify file exists
      if (await File(localPath).exists()) {
        return localPath;
      } else {
        debugPrint('⚠️ Local image file not found: $localPath');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Failed to get local image path: $e');
      return null;
    }
  }

  /// Get storage statistics for a user
  Future<Map<String, dynamic>> getStorageStats(String userId) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      final results = await _database!.rawQuery('''
        SELECT 
          COUNT(*) as totalImages,
          SUM(fileSize) as totalSize,
          SUM(CASE WHEN syncStatus = 'pending' THEN 1 ELSE 0 END) as pendingCount,
          SUM(CASE WHEN syncStatus = 'synced' THEN 1 ELSE 0 END) as syncedCount,
          SUM(CASE WHEN syncStatus = 'failed' THEN 1 ELSE 0 END) as failedCount
        FROM $_tableName
        WHERE userId = ?
      ''', [userId]);

      final stats = results.first;
      return {
        'totalImages': stats['totalImages'] ?? 0,
        'totalSize': stats['totalSize'] ?? 0,
        'pendingCount': stats['pendingCount'] ?? 0,
        'syncedCount': stats['syncedCount'] ?? 0,
        'failedCount': stats['failedCount'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Failed to get storage stats: $e');
      return {};
    }
  }

  // ==================== CLEANUP OPERATIONS ====================

  /// Clear all images for a user (on logout)
  Future<void> clearUserImages(String userId) async {
    if (_database == null || _storageDirectory == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      // Get all images for user
      final images = await _database!.query(
        _tableName,
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Delete files
      for (final image in images) {
        final localPath = image['localPath'] as String;
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Delete user directory
      final userDir = Directory(path.join(_storageDirectory!, userId));
      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
      }

      // Delete database records
      await _database!.delete(
        _tableName,
        where: 'userId = ?',
        whereArgs: [userId],
      );

      debugPrint('🗑️ Cleared all images for user: $userId');
    } catch (e) {
      debugPrint('❌ Failed to clear user images: $e');
    }
  }

  /// Cleanup old synced images (older than 30 days)
  Future<void> cleanupOldImages({int daysOld = 30}) async {
    if (_database == null) {
      throw StateError('PrescriptionImageStorage not initialized');
    }

    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysOld))
          .toIso8601String();

      // Get old synced images
      final oldImages = await _database!.query(
        _tableName,
        where: 'syncStatus = ? AND uploadedAt < ?',
        whereArgs: ['synced', cutoffDate],
      );

      // Delete files
      for (final image in oldImages) {
        final localPath = image['localPath'] as String;
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Delete database records
      await _database!.delete(
        _tableName,
        where: 'syncStatus = ? AND uploadedAt < ?',
        whereArgs: ['synced', cutoffDate],
      );

      debugPrint('🗑️ Cleaned up ${oldImages.length} old images (>$daysOld days)');
    } catch (e) {
      debugPrint('❌ Failed to cleanup old images: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    debugPrint('📁 PrescriptionImageStorage disposed');
  }
}
