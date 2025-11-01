import 'package:flutter/foundation.dart';
import 'dart:collection';

/// Generic LRU (Least Recently Used) Cache implementation using LinkedHashMap
/// 
/// Data Structure Choice:
/// - LinkedHashMap: Maintains insertion order + provides O(1) access
/// - When capacity is reached, removes the oldest entry (LRU eviction)
/// - Thread-safe through synchronous operations (Dart single-threaded)
/// 
/// Parameters:
/// - maxSize: Maximum number of entries (configurable per cache instance)
/// - Eviction Policy: LRU - removes least recently accessed entry
/// 
/// Why LinkedHashMap over SparseArray/ArrayMap:
/// - LinkedHashMap is native Dart, no platform bridge needed
/// - Maintains access order when [accessOrder] mode is used
/// - O(1) for get/put/remove operations
/// - Type-safe generics support
/// 
/// Cache Statistics:
/// - Tracks hits (cache found the item)
/// - Tracks misses (cache didn't have the item)
/// - Useful for debugging and performance monitoring
class LRUCache<K, V> {
  /// Maximum number of entries this cache can hold
  final int maxSize;
  
  /// Internal storage using LinkedHashMap
  /// LinkedHashMap maintains insertion order, allowing us to track LRU
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();
  
  /// Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Cache name for debugging/logging
  final String cacheName;

  /// Constructor
  /// 
  /// [maxSize] - Maximum number of entries before eviction starts
  /// [cacheName] - Identifier for this cache instance (for logging)
  LRUCache({
    required this.maxSize,
    required this.cacheName,
  }) {
    if (maxSize <= 0) {
      throw ArgumentError('maxSize must be greater than 0');
    }
    debugPrint('🧠 [$cacheName] LRU Cache created with maxSize: $maxSize');
  }

  /// Get value from cache
  /// 
  /// Returns null if key doesn't exist
  /// Updates access order (moves entry to end - most recently used)
  V? get(K key) {
    if (_cache.containsKey(key)) {
      // Cache HIT
      _hits++;
      
      // Move to end (most recently used) by removing and re-inserting
      final value = _cache.remove(key)!;
      _cache[key] = value;
      
      debugPrint('✅ [$cacheName] Cache HIT: $key (hits: $_hits, misses: $_misses)');
      return value;
    } else {
      // Cache MISS
      _misses++;
      debugPrint('❌ [$cacheName] Cache MISS: $key (hits: $_hits, misses: $_misses)');
      return null;
    }
  }

  /// Put value into cache
  /// 
  /// If cache is at capacity, removes oldest entry (LRU eviction)
  /// If key already exists, updates value and moves to end
  void put(K key, V value) {
    // If key exists, remove it first to update position
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      debugPrint('📝 [$cacheName] Updated existing entry: $key');
    } else {
      // Check if we need to evict
      if (_cache.length >= maxSize) {
        // Remove oldest entry (first entry in LinkedHashMap)
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
        _evictions++;
        debugPrint('🗑️ [$cacheName] Evicted LRU entry: $oldestKey (evictions: $_evictions)');
      }
    }
    
    // Add new entry (goes to end - most recently used)
    _cache[key] = value;
    debugPrint('➕ [$cacheName] Added entry: $key (size: ${_cache.length}/$maxSize)');
  }

  /// Remove specific entry from cache
  V? remove(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      debugPrint('🗑️ [$cacheName] Removed entry: $key');
    }
    return value;
  }

  /// Check if cache contains key
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// Get current cache size
  int get size => _cache.length;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is full
  bool get isFull => _cache.length >= maxSize;

  /// Clear entire cache
  void clear() {
    final oldSize = _cache.length;
    _cache.clear();
    debugPrint('🧹 [$cacheName] Cleared cache (removed $oldSize entries)');
  }

  /// Get all keys in access order (oldest to newest)
  Iterable<K> get keys => _cache.keys;

  /// Get all values in access order (oldest to newest)
  Iterable<V> get values => _cache.values;

  /// Get cache hit rate (0.0 to 1.0)
  double get hitRate {
    final total = _hits + _misses;
    return total == 0 ? 0.0 : _hits / total;
  }

  /// Get cache statistics as a map
  Map<String, dynamic> getStatistics() {
    return {
      'cacheName': cacheName,
      'maxSize': maxSize,
      'currentSize': _cache.length,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hitRate': (hitRate * 100).toStringAsFixed(2) + '%',
      'utilization': ((size / maxSize) * 100).toStringAsFixed(2) + '%',
    };
  }

  /// Print cache statistics to console
  void printStatistics() {
    final stats = getStatistics();
    debugPrint('📊 [$cacheName] Cache Statistics:');
    stats.forEach((key, value) {
      debugPrint('   $key: $value');
    });
  }

  /// Reset statistics counters
  void resetStatistics() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    debugPrint('🔄 [$cacheName] Statistics reset');
  }
}

/// Pending Prescription Model for Cache
/// 
/// Lightweight model for prescriptions waiting to be uploaded
/// Used in both NFC and Image upload caches
class PendingPrescription {
  final String id;
  final String userId;
  final String uploadMethod; // 'nfc' or 'image'
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? localFilePath; // Path to local file if applicable
  
  PendingPrescription({
    required this.id,
    required this.userId,
    required this.uploadMethod,
    required this.metadata,
    required this.createdAt,
    this.localFilePath,
  });

  /// Create from JSON
  factory PendingPrescription.fromJson(Map<String, dynamic> json) {
    return PendingPrescription(
      id: json['id'] as String,
      userId: json['userId'] as String,
      uploadMethod: json['uploadMethod'] as String,
      metadata: json['metadata'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      localFilePath: json['localFilePath'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'uploadMethod': uploadMethod,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'localFilePath': localFilePath,
    };
  }
}

/// NFC Upload Cache Service
/// 
/// Specialized LRU cache for NFC-based prescription uploads
/// - Stores pending NFC scans
/// - Manages retry queue for failed uploads
/// - Tracks NFC read/write operations
class NFCUploadCache {
  // Singleton pattern
  static final NFCUploadCache _instance = NFCUploadCache._internal();
  factory NFCUploadCache() => _instance;
  NFCUploadCache._internal();

  /// LRU cache for NFC uploads
  /// Max size: 20 entries (reasonable for NFC operations)
  /// Rationale: NFC uploads are typically smaller and less frequent
  late final LRUCache<String, PendingPrescription> _cache;

  bool _initialized = false;

  /// Initialize the NFC cache
  void init({int maxSize = 20}) {
    if (_initialized) {
      debugPrint('⚠️ NFCUploadCache already initialized');
      return;
    }

    _cache = LRUCache<String, PendingPrescription>(
      maxSize: maxSize,
      cacheName: 'NFC_UPLOAD_CACHE',
    );

    _initialized = true;
    debugPrint('✅ NFCUploadCache initialized with maxSize: $maxSize');
  }

  /// Add pending NFC upload to cache
  void addPending(PendingPrescription prescription) {
    if (!_initialized) {
      throw StateError('NFCUploadCache not initialized');
    }
    _cache.put(prescription.id, prescription);
  }

  /// Get pending NFC upload from cache
  PendingPrescription? getPending(String prescriptionId) {
    if (!_initialized) return null;
    return _cache.get(prescriptionId);
  }

  /// Remove uploaded prescription from cache
  void removePending(String prescriptionId) {
    if (!_initialized) return;
    _cache.remove(prescriptionId);
  }

  /// Get all pending NFC uploads
  List<PendingPrescription> getAllPending() {
    if (!_initialized) return [];
    return _cache.values.toList();
  }

  /// Clear cache
  void clear() {
    if (!_initialized) return;
    _cache.clear();
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    if (!_initialized) return {};
    return _cache.getStatistics();
  }

  /// Print statistics
  void printStatistics() {
    if (!_initialized) return;
    _cache.printStatistics();
  }
}

/// Image Upload Cache Service
/// 
/// Specialized LRU cache for image-based prescription uploads
/// - Stores pending image uploads
/// - Manages OCR processing queue
/// - Tracks image file references
class ImageUploadCache {
  // Singleton pattern
  static final ImageUploadCache _instance = ImageUploadCache._internal();
  factory ImageUploadCache() => _instance;
  ImageUploadCache._internal();

  /// LRU cache for image uploads
  /// Max size: 50 entries (larger than NFC due to potentially more images)
  /// Rationale: Users might take multiple photos, need more cache capacity
  /// Images can be larger, but we only store metadata in memory
  late final LRUCache<String, PendingPrescription> _cache;

  bool _initialized = false;

  /// Initialize the image cache
  void init({int maxSize = 50}) {
    if (_initialized) {
      debugPrint('⚠️ ImageUploadCache already initialized');
      return;
    }

    _cache = LRUCache<String, PendingPrescription>(
      maxSize: maxSize,
      cacheName: 'IMAGE_UPLOAD_CACHE',
    );

    _initialized = true;
    debugPrint('✅ ImageUploadCache initialized with maxSize: $maxSize');
  }

  /// Add pending image upload to cache
  void addPending(PendingPrescription prescription) {
    if (!_initialized) {
      throw StateError('ImageUploadCache not initialized');
    }
    _cache.put(prescription.id, prescription);
  }

  /// Get pending image upload from cache
  PendingPrescription? getPending(String prescriptionId) {
    if (!_initialized) return null;
    return _cache.get(prescriptionId);
  }

  /// Remove uploaded prescription from cache
  void removePending(String prescriptionId) {
    if (!_initialized) return;
    _cache.remove(prescriptionId);
  }

  /// Get all pending image uploads
  List<PendingPrescription> getAllPending() {
    if (!_initialized) return [];
    return _cache.values.toList();
  }

  /// Clear cache
  void clear() {
    if (!_initialized) return;
    _cache.clear();
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    if (!_initialized) return {};
    return _cache.getStatistics();
  }

  /// Print statistics
  void printStatistics() {
    if (!_initialized) return;
    _cache.printStatistics();
  }
}
