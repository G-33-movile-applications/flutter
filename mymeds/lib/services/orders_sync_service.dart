import 'package:flutter/foundation.dart';
import '../models/pedido.dart';
import '../facade/app_repository_facade.dart';
import '../services/orders_cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/user_session.dart';

/// Service for syncing orders between Firestore and local cache
/// 
/// Implements eventual connectivity pattern:
/// - Load from cache first (instant UI)
/// - Sync with Firestore when online
/// - Auto-retry failed syncs
/// - Queue offline operations
/// - Updates UserSession for UI synchronization
class OrdersSyncService {
  // Singleton pattern
  static final OrdersSyncService _instance = OrdersSyncService._internal();
  factory OrdersSyncService() => _instance;
  OrdersSyncService._internal();
  
  final AppRepositoryFacade _facade = AppRepositoryFacade();
  final OrdersCacheService _cache = OrdersCacheService();
  final ConnectivityService _connectivity = ConnectivityService();
  
  /// Load orders with offline-first strategy
  /// 
  /// Strategy:
  /// 1. Return cached data immediately if available
  /// 2. If online, sync with Firestore in background
  /// 3. Update cache with fresh data
  /// 4. If offline, return cached data only
  Future<List<Pedido>> loadOrders(String userId, {bool forceRefresh = false}) async {
    debugPrint('🔄 [OrdersSync] Loading orders for user: $userId (forceRefresh: $forceRefresh)');
    
    // Step 1: Always try to load from cache first (even with forceRefresh)
    final cachedOrders = await _cache.getCachedOrders(userId);
    
    // Step 2: Check connectivity BEFORE attempting refresh
    final isOnline = await _connectivity.checkConnectivity();
    
    if (!isOnline) {
      debugPrint('📴 [OrdersSync] Offline - returning cached data only');
      // Return cache even if expired when offline
      if (cachedOrders != null && cachedOrders.isNotEmpty) {
        // Update UserSession for UI synchronization
        UserSession().currentPedidos.value = cachedOrders;
        return cachedOrders;
      }
      // Return even expired cache as fallback
      final expiredCache = await _cache.getCachedOrders(userId, ignoreExpiry: true);
      if (expiredCache != null && expiredCache.isNotEmpty) {
        UserSession().currentPedidos.value = expiredCache;
      }
      return expiredCache ?? [];
    }
    
    // If we have cache and not forcing refresh, return it and sync in background
    if (!forceRefresh && cachedOrders != null && cachedOrders.isNotEmpty) {
      debugPrint('✅ [OrdersSync] Returning ${cachedOrders.length} cached orders');
      
      // Update UserSession for UI synchronization
      UserSession().currentPedidos.value = cachedOrders;
      
      // Start background sync if online
      _backgroundSync(userId);
      
      return cachedOrders;
    }
    
    // Step 3: Fetch from Firestore (only when online)
    try {
      debugPrint('🌐 [OrdersSync] Fetching orders from Firestore...');
      final orders = await _facade.getUserPedidos(userId);
      
      // Sort by date (newest first)
      orders.sort((a, b) => b.fechaPedido.compareTo(a.fechaPedido));
      
      debugPrint('✅ [OrdersSync] Fetched ${orders.length} orders from Firestore');
      
      // Step 3.5: Enrich orders with pharmacy data for offline display
      final enrichedOrders = await _enrichOrdersWithPharmacyData(orders);
      
      // Step 4: Update cache with enriched orders
      await _cache.cacheOrders(userId, enrichedOrders);
      
      // Update UserSession for UI synchronization
      UserSession().currentPedidos.value = enrichedOrders;
      
      return enrichedOrders;
    } catch (e) {
      debugPrint('❌ [OrdersSync] Failed to fetch orders: $e');
      
      // Fallback to cache if Firestore fails (even expired cache)
      if (cachedOrders != null && cachedOrders.isNotEmpty) {
        debugPrint('⚠️ [OrdersSync] Returning cache due to error');
        UserSession().currentPedidos.value = cachedOrders;
        return cachedOrders;
      }
      
      // Try to return even expired cache as last resort
      final expiredCache = await _cache.getCachedOrders(userId, ignoreExpiry: true);
      if (expiredCache != null && expiredCache.isNotEmpty) {
        debugPrint('⚠️ [OrdersSync] Returning expired cache due to error');
        UserSession().currentPedidos.value = expiredCache;
        return expiredCache;
      }
      
      rethrow;
    }
  }
  
  /// Background sync (non-blocking)
  void _backgroundSync(String userId) {
    Future.delayed(Duration.zero, () async {
      try {
        final isOnline = await _connectivity.checkConnectivity();
        if (!isOnline) return;
        
        debugPrint('🔄 [OrdersSync] Background sync started...');
        final orders = await _facade.getUserPedidos(userId);
        orders.sort((a, b) => b.fechaPedido.compareTo(a.fechaPedido));
        
        // Enrich orders with pharmacy data
        final enrichedOrders = await _enrichOrdersWithPharmacyData(orders);
        
        await _cache.cacheOrders(userId, enrichedOrders);
        
        // Update UserSession for UI synchronization
        UserSession().currentPedidos.value = enrichedOrders;
        
        debugPrint('✅ [OrdersSync] Background sync completed (${enrichedOrders.length} orders)');
      } catch (e) {
        debugPrint('⚠️ [OrdersSync] Background sync failed: $e');
      }
    });
  }
  
  /// Enrich orders with pharmacy data for offline display
  /// 
  /// Fetches pharmacy name and address for each order to enable
  /// proper display when offline (prevents "Cargando..." gray screens)
  Future<List<Pedido>> _enrichOrdersWithPharmacyData(List<Pedido> orders) async {
    final enrichedOrders = <Pedido>[];
    
    for (final order in orders) {
      try {
        // Fetch pharmacy data - use facade method to get pharmacy
        final pharmacyMap = await _facade.getPharmacyWithMedicamentos(order.puntoFisicoId);
        final pharmacy = pharmacyMap['pharmacy'];
        
        // Create enriched order with cached pharmacy data
        final enrichedOrder = order.copyWith(
          cachedPharmacyName: pharmacy?.nombre,
          cachedPharmacyAddress: pharmacy?.direccion,
        );
        
        enrichedOrders.add(enrichedOrder);
      } catch (e) {
        debugPrint('⚠️ [OrdersSync] Failed to enrich order ${order.id}: $e');
        // Add original order if enrichment fails
        enrichedOrders.add(order);
      }
    }
    
    return enrichedOrders;
  }
  
  /// Stream orders with real-time updates
  /// 
  /// Returns a stream that:
  /// - Emits cached data immediately
  /// - Updates with fresh data when online
  /// - Handles connectivity changes
  Stream<List<Pedido>> streamOrders(String userId) async* {
    // Emit cached data first
    final cachedOrders = await _cache.getCachedOrders(userId);
    if (cachedOrders != null && cachedOrders.isNotEmpty) {
      debugPrint('📦 [OrdersSync] Emitting ${cachedOrders.length} cached orders');
      yield cachedOrders;
    }
    
    // Check connectivity and fetch fresh data
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [OrdersSync] Offline - no fresh data available');
      return;
    }
    
    try {
      final orders = await _facade.getUserPedidos(userId);
      orders.sort((a, b) => b.fechaPedido.compareTo(a.fechaPedido));
      
      await _cache.cacheOrders(userId, orders);
      
      debugPrint('🌐 [OrdersSync] Emitting ${orders.length} fresh orders');
      yield orders;
    } catch (e) {
      debugPrint('❌ [OrdersSync] Stream error: $e');
    }
  }
  
  /// Force refresh from Firestore
  Future<List<Pedido>> forceRefresh(String userId) async {
    return await loadOrders(userId, forceRefresh: true);
  }
  
  /// Clear cache for user
  Future<void> clearCache(String userId) async {
    await _cache.clearCache(userId);
  }
  
  /// Get cache metadata
  Future<Map<String, dynamic>?> getCacheMetadata(String userId) async {
    return await _cache.getCacheMetadata(userId);
  }
}
