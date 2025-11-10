import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Prescription Draft Cache Service
/// 
/// Manages draft prescriptions using LRU strategy:
/// - Stores draft data in memory (LRU cache)
/// - Saves images to temporary local directory
/// - Restores drafts when user navigates back
/// - Auto-cleans old drafts (7 days)
/// 
/// Use cases:
/// - User starts creating prescription, navigates away, comes back
/// - App crashes or is killed - drafts persist
/// - Offline prescription creation with image attachments
class PrescriptionDraftCache {
  // Singleton pattern
  static final PrescriptionDraftCache _instance = 
      PrescriptionDraftCache._internal();
  factory PrescriptionDraftCache() => _instance;
  PrescriptionDraftCache._internal();

  /// LRU cache for draft metadata (in-memory)
  /// Key: draftId, Value: draft data
  final Map<String, PrescriptionDraft> _drafts = {};
  final List<String> _accessOrder = []; // Track access order for LRU
  
  static const int maxDrafts = 10; // Maximum number of drafts to keep
  static const int draftExpiryDays = 7; // Auto-delete drafts older than 7 days
  
  String? _tempDirectory;

  /// Initialize the cache and temp directory
  Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _tempDirectory = path.join(appDir.path, 'prescription_drafts');
      
      // Create directory if it doesn't exist
      final dir = Directory(_tempDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Clean up old drafts on init
      await _cleanupOldDrafts();
      
      debugPrint('📝 PrescriptionDraftCache initialized');
      debugPrint('   Temp directory: $_tempDirectory');
    } catch (e) {
      debugPrint('❌ Failed to initialize PrescriptionDraftCache: $e');
      rethrow;
    }
  }

  /// Save a draft prescription
  /// 
  /// Parameters:
  /// - [draftId]: Unique identifier for this draft (e.g., 'nfc_draft', 'ocr_draft_123')
  /// - [data]: Map containing draft data (medico, diagnostico, medications, etc.)
  /// - [imagePaths]: List of image file paths (optional)
  Future<void> saveDraft({
    required String draftId,
    required Map<String, dynamic> data,
    List<String>? imagePaths,
  }) async {
    try {
      final draft = PrescriptionDraft(
        id: draftId,
        data: data,
        imagePaths: imagePaths ?? [],
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
      );

      // If we're at capacity, remove least recently used draft
      if (_drafts.length >= maxDrafts && !_drafts.containsKey(draftId)) {
        _evictLRU();
      }

      // Update access order (move to end = most recently used)
      _accessOrder.remove(draftId);
      _accessOrder.add(draftId);
      
      _drafts[draftId] = draft;
      
      debugPrint('📝 Saved draft: $draftId');
      debugPrint('   Data keys: ${data.keys.join(", ")}');
      debugPrint('   Images: ${imagePaths?.length ?? 0}');
    } catch (e) {
      debugPrint('❌ Failed to save draft $draftId: $e');
      rethrow;
    }
  }

  /// Get a draft prescription
  /// 
  /// Returns null if draft doesn't exist or has expired
  PrescriptionDraft? getDraft(String draftId) {
    final draft = _drafts[draftId];
    
    if (draft == null) {
      debugPrint('📝 Draft not found: $draftId');
      return null;
    }

    // Check if draft has expired
    final age = DateTime.now().difference(draft.createdAt);
    if (age.inDays > draftExpiryDays) {
      debugPrint('📝 Draft expired: $draftId (${age.inDays} days old)');
      removeDraft(draftId);
      return null;
    }

    // Update access order (move to end = most recently used)
    _accessOrder.remove(draftId);
    _accessOrder.add(draftId);
    
    debugPrint('📝 Retrieved draft: $draftId');
    return draft;
  }

  /// Remove a draft prescription
  /// 
  /// Also deletes associated image files
  Future<void> removeDraft(String draftId) async {
    final draft = _drafts[draftId];
    if (draft == null) return;

    try {
      // Delete associated image files
      for (final imagePath in draft.imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('📝 Deleted image: $imagePath');
        }
      }

      _drafts.remove(draftId);
      _accessOrder.remove(draftId);
      
      debugPrint('📝 Removed draft: $draftId');
    } catch (e) {
      debugPrint('❌ Failed to remove draft $draftId: $e');
    }
  }

  /// Get all draft IDs (sorted by last modified, newest first)
  List<String> getAllDraftIds() {
    final sortedDrafts = _drafts.entries.toList()
      ..sort((a, b) => b.value.lastModified.compareTo(a.value.lastModified));
    return sortedDrafts.map((e) => e.key).toList();
  }

  /// Get count of current drafts
  int get draftCount => _drafts.length;

  /// Check if a draft exists
  bool hasDraft(String draftId) => _drafts.containsKey(draftId);

  /// Save an image to temp directory
  /// 
  /// Returns the saved file path
  Future<String> saveImageToTemp({
    required String draftId,
    required File imageFile,
  }) async {
    if (_tempDirectory == null) {
      await init();
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final filename = '${draftId}_${timestamp}$extension';
      final targetPath = path.join(_tempDirectory!, filename);

      // Copy file to temp directory
      final savedFile = await imageFile.copy(targetPath);
      
      debugPrint('📝 Saved image to temp: $targetPath');
      return savedFile.path;
    } catch (e) {
      debugPrint('❌ Failed to save image: $e');
      rethrow;
    }
  }

  /// Evict least recently used draft
  void _evictLRU() {
    if (_accessOrder.isEmpty) return;
    
    final lruDraftId = _accessOrder.first;
    debugPrint('📝 Evicting LRU draft: $lruDraftId');
    removeDraft(lruDraftId);
  }

  /// Clean up drafts older than [draftExpiryDays]
  Future<void> _cleanupOldDrafts() async {
    final now = DateTime.now();
    final expiredDrafts = <String>[];

    for (final entry in _drafts.entries) {
      final age = now.difference(entry.value.createdAt);
      if (age.inDays > draftExpiryDays) {
        expiredDrafts.add(entry.key);
      }
    }

    for (final draftId in expiredDrafts) {
      await removeDraft(draftId);
    }

    if (expiredDrafts.isNotEmpty) {
      debugPrint('📝 Cleaned up ${expiredDrafts.length} expired drafts');
    }
  }

  /// Clear all drafts (use with caution)
  Future<void> clearAll() async {
    final draftIds = _drafts.keys.toList();
    for (final draftId in draftIds) {
      await removeDraft(draftId);
    }
    debugPrint('📝 Cleared all drafts');
  }

  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    final totalSize = _drafts.values.fold<int>(
      0,
      (sum, draft) => sum + draft.imagePaths.length,
    );

    return {
      'totalDrafts': _drafts.length,
      'maxDrafts': maxDrafts,
      'totalImages': totalSize,
      'expiryDays': draftExpiryDays,
      'draftIds': getAllDraftIds(),
    };
  }

  /// Print cache statistics (for debugging)
  void printStatistics() {
    final stats = getStatistics();
    debugPrint('📝 Draft Cache Statistics:');
    debugPrint('   Total drafts: ${stats['totalDrafts']}/$maxDrafts');
    debugPrint('   Total images: ${stats['totalImages']}');
    debugPrint('   Draft IDs: ${stats['draftIds']}');
  }
}

/// Prescription Draft Model
class PrescriptionDraft {
  final String id;
  final Map<String, dynamic> data;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime lastModified;

  PrescriptionDraft({
    required this.id,
    required this.data,
    required this.imagePaths,
    required this.createdAt,
    required this.lastModified,
  });

  /// Create a copy with updated fields
  PrescriptionDraft copyWith({
    Map<String, dynamic>? data,
    List<String>? imagePaths,
    DateTime? lastModified,
  }) {
    return PrescriptionDraft(
      id: id,
      data: data ?? this.data,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt,
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'imagePaths': imagePaths,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PrescriptionDraft.fromJson(Map<String, dynamic> json) {
    return PrescriptionDraft(
      id: json['id'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      imagePaths: List<String>.from(json['imagePaths'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }
}
