import 'package:flutter/foundation.dart';

/// Cached item with TTL support
class CachedItem<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  CachedItem({
    required this.data,
    required this.ttl,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  /// Check if this item has expired
  bool get isExpired {
    return DateTime.now().difference(cachedAt).inSeconds > ttl.inSeconds;
  }

  /// Get remaining TTL in seconds
  int get remainingTtl {
    final remaining =
        ttl.inSeconds - DateTime.now().difference(cachedAt).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}

/// LRU (Least Recently Used) Cache Service
/// 
/// Provides in-memory caching with:
/// - Time-To-Live (TTL) based expiration
/// - LRU eviction when max size is reached
/// - TTL monitoring and automatic cleanup
class CacheService {
  static final CacheService _instance = CacheService._internal();

  factory CacheService() {
    return _instance;
  }

  CacheService._internal();

  final Map<String, CachedItem> _cache = {};
  final List<String> _accessOrder = []; // Track access order for LRU
  int _maxSize = 100; // Maximum cache items
  late Duration _defaultTtl;

  /// Initialize the cache service
  Future<void> init({
    int maxSize = 100,
    Duration defaultTtl = const Duration(hours: 1),
  }) async {
    _maxSize = maxSize;
    _defaultTtl = defaultTtl;
    
    debugPrint('💾 CacheService initialized (maxSize: $_maxSize, defaultTTL: ${_defaultTtl.inMinutes}min)');
    
    // Start periodic cleanup of expired items
    _startCleanupTimer();
  }

  /// Cache an item with optional custom TTL
  void set<T>(
    String key,
    T data, {
    Duration? ttl,
  }) {
    final itemTtl = ttl ?? _defaultTtl;
    _cache[key] = CachedItem<T>(data: data, ttl: itemTtl);
    
    // Update access order (move to end = most recently used)
    _accessOrder.remove(key);
    _accessOrder.add(key);
    
    // Evict LRU items if cache is full
    if (_cache.length > _maxSize) {
      _evictLRU();
    }
    
    debugPrint('💾 Cached: $key (TTL: ${itemTtl.inMinutes}min, size: ${_cache.length}/$_maxSize)');
  }

  /// Retrieve a cached item
  T? get<T>(String key) {
    final item = _cache[key] as CachedItem<T>?;
    
    if (item == null) {
      debugPrint('💾 Cache MISS: $key');
      return null;
    }

    if (item.isExpired) {
      debugPrint('💾 Cache EXPIRED: $key');
      _cache.remove(key);
      _accessOrder.remove(key);
      return null;
    }

    // Update access order (move to end = most recently used)
    _accessOrder.remove(key);
    _accessOrder.add(key);
    
    debugPrint('💾 Cache HIT: $key (TTL remaining: ${item.remainingTtl}s)');
    return item.data;
  }

  /// Check if key exists and is not expired
  bool contains(String key) {
    final item = _cache[key];
    if (item == null) return false;
    
    if (item.isExpired) {
      _cache.remove(key);
      _accessOrder.remove(key);
      return false;
    }
    
    return true;
  }

  /// Check if cache is still valid for a key (not expired)
  bool isValid(String key) {
    final item = _cache[key];
    if (item == null) return false;
    return !item.isExpired;
  }

  /// Get remaining TTL for a cache key in seconds
  int getRemainingTtl(String key) {
    final item = _cache[key];
    if (item == null) return 0;
    return item.remainingTtl;
  }

  /// Remove a specific cached item
  void remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
    debugPrint('💾 Removed from cache: $key');
  }

  /// Clear all cached items
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    debugPrint('💾 Cache cleared');
  }

  /// Evict least recently used item
  void _evictLRU() {
    if (_accessOrder.isEmpty) return;
    
    final lruKey = _accessOrder.first;
    _cache.remove(lruKey);
    _accessOrder.removeAt(0);
    debugPrint('💾 LRU evicted: $lruKey (cache now: ${_cache.length}/$_maxSize)');
  }

  /// Start periodic cleanup of expired items
  void _startCleanupTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 5));
      _cleanupExpiredItems();
      return true; // Continue loop
    });
  }

  /// Remove all expired items
  void _cleanupExpiredItems() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
      _accessOrder.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('💾 Cleanup: removed ${expiredKeys.length} expired items');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final totalTtl = _cache.values.fold<int>(
      0,
      (sum, item) => sum + item.ttl.inSeconds,
    );

    return {
      'size': _cache.length,
      'maxSize': _maxSize,
      'usage': '${(_cache.length / _maxSize * 100).toStringAsFixed(1)}%',
      'averageTtl': totalTtl ~/ (_cache.isNotEmpty ? _cache.length : 1),
    };
  }

  /// Dispose resources
  void dispose() {
    clear();
    debugPrint('💾 CacheService disposed');
  }
}
