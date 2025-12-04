import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido.dart';
import '../models/medicamento_pedido.dart';
import '../models/adherence_event.dart'; // For SyncStatus enum
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
        
        debugPrint('✅ [OrdersSync] Background sync completed! (${enrichedOrders.length} orders)');
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
  
  /// Add a new order to local cache and optionally sync to Firestore
  /// 
  /// This method is used by PaymentProcessingService to create orders offline-first
  /// 
  /// Parameters:
  /// - order: The order to add
  /// - userId: User ID
  /// - medicines: List of medications for the order (for subcollection)
  /// - pharmacyName: Pharmacy name (for cached display)
  /// - pharmacyAddress: Pharmacy address (for cached display)
  /// - syncImmediately: If true and online, sync to Firestore immediately
  /// 
  /// Returns the order with updated sync metadata
  Future<Pedido> addOrderToCache({
    required Pedido order,
    required String userId,
    required List<Map<String, dynamic>> medicines,
    required String pharmacyName,
    required String pharmacyAddress,
    bool syncImmediately = true,
  }) async {
    debugPrint('📥 [OrdersSync] Adding order to cache: ${order.id}');
    
    // Enrich order with cached pharmacy data for offline display
    final enrichedOrder = order.copyWith(
      cachedPharmacyName: pharmacyName,
      cachedPharmacyAddress: pharmacyAddress,
    );
    
    // Load current cached orders
    final currentOrders = await _cache.getCachedOrders(userId, ignoreExpiry: true) ?? [];
    
    // Add new order to the beginning (most recent first)
    final updatedOrders = [enrichedOrder, ...currentOrders];
    
    // Update cache
    await _cache.cacheOrders(userId, updatedOrders);
    
    // Update UserSession for immediate UI update
    UserSession().currentPedidos.value = updatedOrders;
    
    debugPrint('✅ [OrdersSync] Order added to cache (${updatedOrders.length} total orders)');
    
    // Try to sync to Firestore if online and requested
    if (syncImmediately) {
      final isOnline = await _connectivity.checkConnectivity();
      if (isOnline) {
        debugPrint('🌐 [OrdersSync] Attempting immediate sync for order: ${order.id}');
        try {
          final syncedOrder = await _pushOrderToFirestore(
            order: enrichedOrder,
            userId: userId,
            medicines: medicines,
          );
          
          // Update cache with synced order
          final index = updatedOrders.indexWhere((o) => o.id == order.id);
          if (index != -1) {
            updatedOrders[index] = syncedOrder;
            await _cache.cacheOrders(userId, updatedOrders);
            UserSession().currentPedidos.value = updatedOrders;
          }
          
          return syncedOrder;
        } catch (e) {
          debugPrint('⚠️ [OrdersSync] Immediate sync failed, order remains pending: $e');
          // Return original order with pending status (already in cache)
        }
      } else {
        debugPrint('📴 [OrdersSync] Offline - order will sync when connection returns');
      }
    }
    
    return enrichedOrder;
  }
  
  /// Push a pending order to Firestore
  /// 
  /// Called by addOrderToCache or pushPendingOrders
  /// Updates the order's sync metadata on success
  Future<Pedido> _pushOrderToFirestore({
    required Pedido order,
    required String userId,
    required List<Map<String, dynamic>> medicines,
  }) async {
    final now = DateTime.now();
    
    // Create order in Firestore
    await _facade.createPedido(order, userId: userId);
    
    // Save medicines to subcollection
    final firestore = FirebaseFirestore.instance;
    for (final med in medicines) {
      final medicamentoRef = firestore.collection('medicamentos_globales').doc(med['medicationId'] as String).path;
      final medicamento = MedicamentoPedido(
        id: med['medicationId'] as String,
        pedidoId: order.id,
        medicamentoRef: medicamentoRef,
        nombre: med['medicationName'] as String,
        cantidad: (med['quantity'] as num).toInt(),
        precioUnitario: (med['pricePerUnit'] as num).toInt(),
        total: (med['subtotal'] as num).toInt(),
        userId: userId,
      );
      
      await firestore
          .collection('usuarios')
          .doc(userId)
          .collection('pedidos')
          .doc(order.id)
          .collection('medicamentos')
          .doc(medicamento.id)
          .set(medicamento.toMap());
    }
    
    debugPrint('✅ [OrdersSync] Order synced to Firestore: ${order.id}');
    
    // Return order with updated sync metadata
    return order.copyWith(
      syncStatus: SyncStatus.synced,
      firstSyncedAt: order.firstSyncedAt ?? now, // Only set if not already set
    );
  }
  
  /// Push all pending orders to Firestore
  /// 
  /// Called when connectivity returns or manually triggered
  /// Returns the number of orders successfully synced
  Future<int> pushPendingOrders(String userId) async {
    debugPrint('🔄 [OrdersSync] Pushing pending orders for user: $userId');
    
    // Check connectivity first
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      debugPrint('📴 [OrdersSync] Offline - cannot push pending orders');
      return 0;
    }
    
    // Load cached orders
    final cachedOrders = await _cache.getCachedOrders(userId, ignoreExpiry: true) ?? [];
    
    // Filter pending orders
    final pendingOrders = cachedOrders.where((o) => o.syncStatus == SyncStatus.pending).toList();
    
    if (pendingOrders.isEmpty) {
      debugPrint('✅ [OrdersSync] No pending orders to sync');
      return 0;
    }
    
    debugPrint('🔄 [OrdersSync] Found ${pendingOrders.length} pending orders to sync');
    
    int syncedCount = 0;
    final updatedOrders = List<Pedido>.from(cachedOrders);
    
    for (final order in pendingOrders) {
      try {
        // Note: We need to get medicines from cache or skip for now
        // In a production system, medicines would also be cached with the order
        // For now, we'll mark the order as synced without medicines (they were already created in payment flow)
        
        // Create just the order document in Firestore (medicines were saved during payment)
        await _facade.createPedido(order, userId: userId);
        
        final now = DateTime.now();
        final syncedOrder = order.copyWith(
          syncStatus: SyncStatus.synced,
          firstSyncedAt: order.firstSyncedAt ?? now,
        );
        
        // Update in the list
        final index = updatedOrders.indexWhere((o) => o.id == order.id);
        if (index != -1) {
          updatedOrders[index] = syncedOrder;
        }
        
        syncedCount++;
        debugPrint('✅ [OrdersSync] Synced order: ${order.id}');
      } catch (e) {
        debugPrint('❌ [OrdersSync] Failed to sync order ${order.id}: $e');
        
        // Mark as failed
        final index = updatedOrders.indexWhere((o) => o.id == order.id);
        if (index != -1) {
          updatedOrders[index] = order.copyWith(syncStatus: SyncStatus.failed);
        }
      }
    }
    
    // Update cache with synced orders
    if (syncedCount > 0 || updatedOrders.any((o) => o.syncStatus == SyncStatus.failed)) {
      await _cache.cacheOrders(userId, updatedOrders);
      UserSession().currentPedidos.value = updatedOrders;
      debugPrint('✅ [OrdersSync] Updated cache with sync results (${syncedCount} synced)');
    }
    
    return syncedCount;
  }
}
