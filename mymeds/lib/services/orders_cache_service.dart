import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/pedido.dart';

/// Offline-first cache service for orders (Pedidos)
/// 
/// Provides:
/// - Local storage using Hive
/// - Automatic sync with Firestore when online
/// - Offline-first data access
/// - Cache invalidation and TTL management
/// - Medicines metadata caching for offline sync
class OrdersCacheService {
  // Singleton pattern
  static final OrdersCacheService _instance = OrdersCacheService._internal();
  factory OrdersCacheService() => _instance;
  OrdersCacheService._internal();
  
  static const String _boxName = 'orders_cache';
  static const String _metadataBoxName = 'orders_metadata';
  static const String _medicinesBoxName = 'orders_medicines'; // NEW: medicines cache
  static const Duration _defaultTtl = Duration(hours: 24);
  
  Box<Map>? _ordersBox;
  Box<Map>? _metadataBox;
  Box<Map>? _medicinesBox; // NEW: box for medicines data
  
  /// Initialize Hive boxes for orders
  Future<void> init() async {
    try {
      _ordersBox = await Hive.openBox<Map>(_boxName);
      _metadataBox = await Hive.openBox<Map>(_metadataBoxName);
      _medicinesBox = await Hive.openBox<Map>(_medicinesBoxName);
      debugPrint('📦 OrdersCacheService initialized (with medicines cache)');
    } catch (e) {
      debugPrint('❌ Failed to initialize OrdersCacheService: $e');
      rethrow;
    }
  }
  
  /// Cache orders for a specific user
  Future<void> cacheOrders(String userId, List<Pedido> orders) async {
    if (_ordersBox == null) {
      debugPrint('⚠️ OrdersCacheService not initialized');
      return;
    }
    
    try {
      // Convert orders to JSON maps for Hive storage
      final ordersData = orders.map((order) => order.toJsonMap()).toList();
      
      await _ordersBox!.put(userId, {
        'orders': ordersData,
        'cachedAt': DateTime.now().toIso8601String(),
      });
      
      // Store metadata
      await _metadataBox!.put(userId, {
        'lastSync': DateTime.now().toIso8601String(),
        'count': orders.length,
      });
      
      debugPrint('💾 Cached ${orders.length} orders for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to cache orders: $e');
    }
  }
  
  /// Get cached orders for a user
  Future<List<Pedido>?> getCachedOrders(String userId, {bool ignoreExpiry = false}) async {
    if (_ordersBox == null) {
      debugPrint('⚠️ OrdersCacheService not initialized');
      return null;
    }
    
    try {
      final data = _ordersBox!.get(userId);
      if (data == null) {
        debugPrint('📦 No cached orders for user $userId');
        return null;
      }
      
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      final age = DateTime.now().difference(cachedAt);
      
      // Check if cache is expired (unless we're ignoring expiry)
      if (!ignoreExpiry && age > _defaultTtl) {
        debugPrint('⏰ Cache expired for user $userId (age: ${age.inHours}h)');
        return null;
      }
      
      final ordersData = data['orders'] as List;
      final orders = ordersData
          .map((orderMap) => Pedido.fromJsonMap(Map<String, dynamic>.from(orderMap as Map)))
          .toList();
      
      debugPrint('📦 Retrieved ${orders.length} cached orders for user $userId (age: ${age.inMinutes}min${ignoreExpiry ? ', ignoring expiry' : ''})');
      return orders;
    } catch (e) {
      debugPrint('❌ Failed to get cached orders: $e');
      return null;
    }
  }
  
  /// Check if cache exists and is valid for a user
  Future<bool> hasCachedOrders(String userId) async {
    if (_ordersBox == null) return false;
    
    try {
      final data = _ordersBox!.get(userId);
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
  
  /// Cache medicines for a specific order
  Future<void> cacheMedicinesForOrder(String orderId, List<Map<String, dynamic>> medicines) async {
    if (_medicinesBox == null) {
      debugPrint('⚠️ Medicines box not initialized');
      return;
    }
    
    try {
      await _medicinesBox!.put(orderId, {
        'medicines': medicines,
        'cachedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('💾 [OrdersQueue] Cached ${medicines.length} medicines for order $orderId');
    } catch (e) {
      debugPrint('❌ Failed to cache medicines for order $orderId: $e');
    }
  }
  
  /// Get cached medicines for a specific order
  Future<List<Map<String, dynamic>>?> getCachedMedicinesForOrder(String orderId) async {
    if (_medicinesBox == null) {
      debugPrint('⚠️ Medicines box not initialized');
      return null;
    }
    
    try {
      final data = _medicinesBox!.get(orderId);
      if (data == null) {
        debugPrint('📦 No cached medicines for order $orderId');
        return null;
      }
      
      final medicines = (data['medicines'] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      
      debugPrint('📦 [OrdersQueue] Retrieved ${medicines.length} cached medicines for order $orderId');
      return medicines;
    } catch (e) {
      debugPrint('❌ Failed to get cached medicines for order $orderId: $e');
      return null;
    }
  }
  
  /// Clear cache for a specific user
  Future<void> clearCache(String userId) async {
    if (_ordersBox == null) return;
    
    try {
      await _ordersBox!.delete(userId);
      await _metadataBox?.delete(userId);
      // Note: We don't clear medicines here as they're keyed by orderId, not userId
      debugPrint('🗑️ Cleared cache for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
    }
  }
  
  /// Clear all cached orders
  Future<void> clearAllCache() async {
    if (_ordersBox == null) return;
    
    try {
      await _ordersBox!.clear();
      await _metadataBox?.clear();
      await _medicinesBox?.clear();
      debugPrint('🗑️ Cleared all orders cache (including medicines)');
    } catch (e) {
      debugPrint('❌ Failed to clear all cache: $e');
    }
  }
  
  /// Get cache statistics
  Future<Map<String, int>> getCacheStats() async {
    if (_ordersBox == null) {
      return {'users': 0, 'totalOrders': 0};
    }
    
    try {
      int totalOrders = 0;
      for (var key in _ordersBox!.keys) {
        final data = _ordersBox!.get(key);
        if (data != null && data['orders'] != null) {
          totalOrders += (data['orders'] as List).length;
        }
      }
      
      return {
        'users': _ordersBox!.length,
        'totalOrders': totalOrders,
      };
    } catch (e) {
      debugPrint('❌ Failed to get cache stats: $e');
      return {'users': 0, 'totalOrders': 0};
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _ordersBox?.close();
    await _metadataBox?.close();
    await _medicinesBox?.close();
    debugPrint('📦 OrdersCacheService disposed');
  }
}
