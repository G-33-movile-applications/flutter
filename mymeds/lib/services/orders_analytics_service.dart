import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido.dart';
import '../services/orders_cache_service.dart';

/// Analytics service for computing offline order sync statistics
/// 
/// Implements Type 2 Business Question:
/// "What proportion of orders is created offline, and how long do they take to synchronize once connection is available?"
/// 
/// This service:
/// - Computes offline vs online order statistics from cached orders
/// - Calculates average sync delay for offline orders
/// - Provides data for both local UI display and backend/BigQuery analytics
class OrdersAnalyticsService {
  // Singleton pattern
  static final OrdersAnalyticsService _instance = OrdersAnalyticsService._internal();
  factory OrdersAnalyticsService() => _instance;
  OrdersAnalyticsService._internal();
  
  final OrdersCacheService _cache = OrdersCacheService();
  
  /// Compute offline sync statistics for a user
  /// 
  /// Returns:
  /// - Total orders count
  /// - Offline-created orders count and percentage
  /// - Average offline-to-sync delay
  Future<OrdersOfflineSyncStats> computeOfflineSyncStats(String userId) async {
    try {
      debugPrint('📊 [OrdersAnalytics] Computing offline sync stats for user: $userId');
      
      // Load cached orders (ignore expiry to get all historical data)
      final orders = await _cache.getCachedOrders(userId, ignoreExpiry: true) ?? [];
      
      if (orders.isEmpty) {
        debugPrint('📊 [OrdersAnalytics] No orders found for user');
        return OrdersOfflineSyncStats.empty();
      }
      
      final totalOrders = orders.length;
      final offlineOrders = orders.where((o) => o.createdOffline).toList();
      final offlineCount = offlineOrders.length;
      
      // Calculate offline percentage
      double offlinePercentage = 0;
      if (totalOrders > 0) {
        offlinePercentage = (offlineCount / totalOrders) * 100.0;
      }
      
      // Calculate average sync delay for offline orders that have been synced
      final syncedOfflineOrders = offlineOrders
          .where((o) => o.firstSyncedAt != null)
          .toList();
      
      Duration? avgDelay;
      if (syncedOfflineOrders.isNotEmpty) {
        final delays = syncedOfflineOrders
            .map((o) => o.firstSyncedAt!.difference(o.createdAt))
            .where((d) => !d.isNegative) // Guard against clock skew
            .toList();
        
        if (delays.isNotEmpty) {
          final totalSeconds = delays.fold<int>(0, (sum, d) => sum + d.inSeconds);
          avgDelay = Duration(seconds: totalSeconds ~/ delays.length);
          debugPrint('📊 [OrdersAnalytics] Average sync delay: ${avgDelay.inMinutes} minutes (${delays.length} synced orders)');
        }
      }
      
      debugPrint('📊 [OrdersAnalytics] Results: total=$totalOrders, offline=$offlineCount (${offlinePercentage.toStringAsFixed(1)}%)');
      
      return OrdersOfflineSyncStats(
        totalOrders: totalOrders,
        offlineOrders: offlineCount,
        offlinePercentage: offlinePercentage,
        avgOfflineSyncDelay: avgDelay,
        syncedOfflineOrders: syncedOfflineOrders.length,
        pendingOfflineOrders: offlineCount - syncedOfflineOrders.length,
      );
    } catch (e, stack) {
      debugPrint('❌ [OrdersAnalytics] Error computing stats: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
  
  /// Write aggregated statistics to Firestore for backend/BigQuery analytics
  /// 
  /// This creates a summary document at:
  /// `usuarios/{userId}/analytics/offlineSyncStats`
  /// 
  /// The document can be used by external dashboards or analytics pipelines
  Future<void> publishStatsToFirestore(String userId, OrdersOfflineSyncStats stats) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('analytics')
          .doc('offlineSyncStats')
          .set({
        'totalOrders': stats.totalOrders,
        'offlineOrders': stats.offlineOrders,
        'offlinePercentage': stats.offlinePercentage,
        'avgOfflineSyncDelaySeconds': stats.avgOfflineSyncDelay?.inSeconds,
        'syncedOfflineOrders': stats.syncedOfflineOrders,
        'pendingOfflineOrders': stats.pendingOfflineOrders,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      debugPrint('📊 [OrdersAnalytics] Published stats to Firestore for user: $userId');
    } catch (e) {
      debugPrint('⚠️ [OrdersAnalytics] Failed to publish stats to Firestore: $e');
      // Don't throw - this is optional functionality
    }
  }
}

/// Statistics about offline order creation and synchronization
/// 
/// Used for Type 2 Business Question analytics:
/// "What proportion of orders is created offline, and how long do they take to synchronize?"
class OrdersOfflineSyncStats {
  final int totalOrders;                 // Total number of orders
  final int offlineOrders;               // Number of orders created offline
  final double offlinePercentage;        // Percentage of orders created offline (0.0 - 100.0)
  final Duration? avgOfflineSyncDelay;   // Average time from creation to first sync (null if no data)
  final int syncedOfflineOrders;         // Number of offline orders that have been synced
  final int pendingOfflineOrders;        // Number of offline orders still waiting to sync
  
  OrdersOfflineSyncStats({
    required this.totalOrders,
    required this.offlineOrders,
    required this.offlinePercentage,
    this.avgOfflineSyncDelay,
    this.syncedOfflineOrders = 0,
    this.pendingOfflineOrders = 0,
  });
  
  /// Create empty stats (no data)
  factory OrdersOfflineSyncStats.empty() {
    return OrdersOfflineSyncStats(
      totalOrders: 0,
      offlineOrders: 0,
      offlinePercentage: 0.0,
      avgOfflineSyncDelay: null,
      syncedOfflineOrders: 0,
      pendingOfflineOrders: 0,
    );
  }
  
  /// Percentage of orders created online
  double get onlinePercentage => 100.0 - offlinePercentage;
  
  /// Number of orders created online
  int get onlineOrders => totalOrders - offlineOrders;
  
  @override
  String toString() {
    return 'OrdersOfflineSyncStats(total: $totalOrders, offline: $offlineOrders (${offlinePercentage.toStringAsFixed(1)}%), avgDelay: ${avgOfflineSyncDelay?.inMinutes ?? 0} min)';
  }
}
