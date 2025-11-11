import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/prescripcion.dart';

/// Persistent cache service for prescriptions using Hive
/// 
/// Provides:
/// - Local storage using Hive
/// - Offline-first data access
/// - Cache invalidation and TTL management
class PrescriptionsCacheService {
  // Singleton pattern
  static final PrescriptionsCacheService _instance = PrescriptionsCacheService._internal();
  factory PrescriptionsCacheService() => _instance;
  PrescriptionsCacheService._internal();
  
  static const String _boxName = 'prescriptions_cache';
  static const String _metadataBoxName = 'prescriptions_metadata';
  static const Duration _defaultTtl = Duration(hours: 24);
  
  Box<Map>? _prescriptionsBox;
  Box<Map>? _metadataBox;
  
  /// Initialize Hive boxes for prescriptions
  Future<void> init() async {
    try {
      _prescriptionsBox = await Hive.openBox<Map>(_boxName);
      _metadataBox = await Hive.openBox<Map>(_metadataBoxName);
      debugPrint('📦 PrescriptionsCacheService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize PrescriptionsCacheService: $e');
      rethrow;
    }
  }
  
  /// Cache prescriptions for a specific user
  Future<void> cachePrescriptions(String userId, List<Prescripcion> prescriptions) async {
    if (_prescriptionsBox == null) {
      debugPrint('⚠️ PrescriptionsCacheService not initialized');
      return;
    }
    
    try {
      // Convert prescriptions to JSON maps for Hive storage
      final prescriptionsData = prescriptions.map((prescription) => prescription.toMap()).toList();
      
      await _prescriptionsBox!.put(userId, {
        'prescriptions': prescriptionsData,
        'cachedAt': DateTime.now().toIso8601String(),
      });
      
      // Store metadata
      await _metadataBox!.put(userId, {
        'lastSync': DateTime.now().toIso8601String(),
        'count': prescriptions.length,
      });
      
      debugPrint('💾 Cached ${prescriptions.length} prescriptions for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to cache prescriptions: $e');
    }
  }
  
  /// Get cached prescriptions for a user
  Future<List<Prescripcion>?> getCachedPrescriptions(String userId, {bool ignoreExpiry = false}) async {
    debugPrint('🔍 [PrescriptionsCacheService] getCachedPrescriptions called for user: $userId');
    
    if (_prescriptionsBox == null) {
      debugPrint('⚠️ PrescriptionsCacheService not initialized - box is null!');
      return null;
    }
    
    debugPrint('🔍 [PrescriptionsCacheService] Box is initialized, checking for data...');
    debugPrint('🔍 [PrescriptionsCacheService] Box keys: ${_prescriptionsBox!.keys.toList()}');
    
    try {
      final data = _prescriptionsBox!.get(userId);
      if (data == null) {
        debugPrint('📦 No cached prescriptions for user $userId');
        return null;
      }
      
      debugPrint('🔍 [PrescriptionsCacheService] Found data for user $userId');
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      final age = DateTime.now().difference(cachedAt);
      debugPrint('🔍 [PrescriptionsCacheService] Cache age: ${age.inMinutes} minutes');
      
      // Check if cache is expired (unless we're ignoring expiry)
      if (!ignoreExpiry && age > _defaultTtl) {
        debugPrint('⏰ Prescriptions cache expired for user $userId (age: ${age.inHours}h)');
        return null;
      }
      
      final prescriptionsData = data['prescriptions'] as List;
      debugPrint('🔍 [PrescriptionsCacheService] Raw prescriptions data length: ${prescriptionsData.length}');
      
      final prescriptions = prescriptionsData
          .map((prescriptionMap) => Prescripcion.fromMap(Map<String, dynamic>.from(prescriptionMap as Map)))
          .toList();
      
      debugPrint('📦 Retrieved ${prescriptions.length} cached prescriptions for user $userId (age: ${age.inMinutes}min${ignoreExpiry ? ', ignoring expiry' : ''})');
      return prescriptions;
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to get cached prescriptions: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Check if cache exists and is valid for a user
  Future<bool> hasCachedPrescriptions(String userId) async {
    if (_prescriptionsBox == null) return false;
    
    try {
      final data = _prescriptionsBox!.get(userId);
      if (data == null) return false;
      
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      final age = DateTime.now().difference(cachedAt);
      
      return age <= _defaultTtl;
    } catch (e) {
      return false;
    }
  }
  
  /// Get cache metadata (last sync time, count)
  Future<Map<String, dynamic>?> getCacheMetadata(String userId) async {
    if (_metadataBox == null) return null;
    
    try {
      final metadata = _metadataBox!.get(userId);
      if (metadata == null) return null;
      
      return Map<String, dynamic>.from(metadata);
    } catch (e) {
      debugPrint('❌ Failed to get cache metadata: $e');
      return null;
    }
  }
  
  /// Clear cache for a specific user
  Future<void> clearCache(String userId) async {
    if (_prescriptionsBox == null) return;
    
    try {
      await _prescriptionsBox!.delete(userId);
      await _metadataBox?.delete(userId);
      debugPrint('🗑️ Cleared prescriptions cache for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to clear prescriptions cache: $e');
    }
  }
  
  /// Clear all cached prescriptions
  Future<void> clearAllCache() async {
    if (_prescriptionsBox == null) return;
    
    try {
      await _prescriptionsBox!.clear();
      await _metadataBox?.clear();
      debugPrint('🗑️ Cleared all prescriptions cache');
    } catch (e) {
      debugPrint('❌ Failed to clear all prescriptions cache: $e');
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _prescriptionsBox?.close();
    await _metadataBox?.close();
    debugPrint('📦 PrescriptionsCacheService disposed');
  }
}
