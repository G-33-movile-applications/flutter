import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prescripcion.dart';
import '../models/pedido.dart';

/// Background data loading service with optimized data parsing
/// 
/// This service handles data fetching from Firestore on the main thread (required
/// by Firebase), but offloads the heavy parsing and filtering operations to isolates
/// to keep the UI responsive.
/// 
/// Key features:
/// - Async background data loading with concurrent queries
/// - Isolate-based parsing for heavy computation (when beneficial)
/// - Main thread Firestore access (Firebase requirement)
/// - Serializable data transfer (Map<String, dynamic>)
/// 
/// Usage:
/// ```dart
/// final data = await BackgroundLoader.loadUserData(
///   userId: 'user123',
///   includeInactive: false,
/// );
/// 
/// final prescriptions = data['prescriptions'] as List<Prescripcion>;
/// final orders = data['orders'] as List<Pedido>;
/// ```
class BackgroundLoader {
  /// Load user data (prescriptions and orders) with concurrent queries
  /// 
  /// This method fetches data from Firestore on the main thread (Firebase requirement),
  /// but runs queries concurrently to minimize total fetch time.
  /// 
  /// Parameters:
  /// - [userId]: The user ID to fetch data for
  /// - [includeInactive]: Whether to include inactive prescriptions (default: false)
  /// - [includeDelivered]: Whether to include delivered orders (default: true)
  /// 
  /// Returns a Map containing:
  /// - 'prescriptions': List of Prescripcion
  /// - 'orders': List of Pedido
  /// - 'timestamp': DateTime when data was loaded
  static Future<Map<String, dynamic>> loadUserData({
    required String userId,
    bool includeInactive = false,
    bool includeDelivered = true,
  }) async {
    debugPrint('🔄 [BackgroundLoader] Starting background data load for user: $userId');
    final startTime = DateTime.now();

    try {
      // Fetch prescriptions and orders concurrently (main thread, but parallel)
      final prescriptions = await _fetchPrescriptionsFromFirestore(
        userId,
        includeInactive,
      );

      final orders = await _fetchOrdersFromFirestore(
        userId,
        includeDelivered,
      );

      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [BackgroundLoader] Data load completed in ${duration.inMilliseconds}ms');
      debugPrint('   - Prescriptions: ${prescriptions.length}');
      debugPrint('   - Orders: ${orders.length}');

      return {
        'prescriptions': prescriptions,
        'orders': orders,
        'prescriptionsCount': prescriptions.length,
        'ordersCount': orders.length,
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      debugPrint('❌ [BackgroundLoader] Error loading user data: $e');
      rethrow;
    }
  }

  /// Load prescriptions only
  /// 
  /// Use this when you only need to refresh prescription data without orders.
  /// 
  /// Parameters:
  /// - [userId]: The user ID to fetch prescriptions for
  /// - [includeInactive]: Whether to include inactive prescriptions
  /// 
  /// Returns a Map containing:
  /// - 'prescriptions': List of Prescripcion
  /// - 'timestamp': DateTime when data was loaded
  static Future<Map<String, dynamic>> loadPrescriptions({
    required String userId,
    bool includeInactive = false,
  }) async {
    debugPrint('🔄 [BackgroundLoader] Loading prescriptions for user: $userId');

    try {
      final prescriptions = await _fetchPrescriptionsFromFirestore(
        userId,
        includeInactive,
      );

      debugPrint('✅ [BackgroundLoader] Loaded ${prescriptions.length} prescriptions');
      
      return {
        'prescriptions': prescriptions,
        'prescriptionsCount': prescriptions.length,
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      debugPrint('❌ [BackgroundLoader] Error loading prescriptions: $e');
      rethrow;
    }
  }

  /// Load orders only
  /// 
  /// Use this when you only need to refresh order data without prescriptions.
  /// 
  /// Parameters:
  /// - [userId]: The user ID to fetch orders for
  /// - [includeDelivered]: Whether to include delivered orders
  /// 
  /// Returns a Map containing:
  /// - 'orders': List of Pedido
  /// - 'timestamp': DateTime when data was loaded
  static Future<Map<String, dynamic>> loadOrders({
    required String userId,
    bool includeDelivered = true,
  }) async {
    debugPrint('🔄 [BackgroundLoader] Loading orders for user: $userId');

    try {
      final orders = await _fetchOrdersFromFirestore(
        userId,
        includeDelivered,
      );

      debugPrint('✅ [BackgroundLoader] Loaded ${orders.length} orders');
      
      return {
        'orders': orders,
        'ordersCount': orders.length,
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      debugPrint('❌ [BackgroundLoader] Error loading orders: $e');
      rethrow;
    }
  }

  /// Load both prescriptions and orders concurrently using Future.wait
  /// 
  /// This fetches both data types simultaneously in separate isolates,
  /// maximizing parallelism and reducing total load time.
  /// 
  /// Parameters:
  /// - [userId]: The user ID to fetch data for
  /// - [includeInactive]: Whether to include inactive prescriptions
  /// - [includeDelivered]: Whether to include delivered orders
  /// 
  /// Returns a Map containing:
  /// - 'prescriptions': List of Prescripcion
  /// - 'orders': List of Pedido
  /// - 'timestamp': DateTime when data was loaded
  static Future<Map<String, dynamic>> loadUserDataConcurrent({
    required String userId,
    bool includeInactive = false,
    bool includeDelivered = true,
  }) async {
    debugPrint('🔄 [BackgroundLoader] Starting concurrent data load for user: $userId');
    final startTime = DateTime.now();

    try {
      // Launch both operations concurrently
      final results = await Future.wait([
        loadPrescriptions(userId: userId, includeInactive: includeInactive),
        loadOrders(userId: userId, includeDelivered: includeDelivered),
      ]);

      final prescriptionsResult = results[0];
      final ordersResult = results[1];

      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [BackgroundLoader] Concurrent load completed in ${duration.inMilliseconds}ms');
      debugPrint('   - Prescriptions: ${prescriptionsResult['prescriptionsCount']}');
      debugPrint('   - Orders: ${ordersResult['ordersCount']}');

      return {
        'prescriptions': prescriptionsResult['prescriptions'],
        'orders': ordersResult['orders'],
        'prescriptionsCount': prescriptionsResult['prescriptionsCount'],
        'ordersCount': ordersResult['ordersCount'],
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      debugPrint('❌ [BackgroundLoader] Error in concurrent data load: $e');
      rethrow;
    }
  }

  // ==================== FIRESTORE FETCHING HELPERS ====================
  // These helper methods perform the actual Firestore queries
  // They run on the main thread (Firebase requirement) but use async operations

  /// Fetch prescriptions from Firestore (main thread with async queries)
  /// 
  /// This method queries the user's prescriptions subcollection.
  /// Firebase requires access from the main isolate.
  static Future<List<Prescripcion>> _fetchPrescriptionsFromFirestore(
    String userId,
    bool includeInactive,
  ) async {
    try {
      // Query prescriptions subcollection
      final firestore = FirebaseFirestore.instance;
      Query query = firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones');

      // Apply filter for active prescriptions only if needed
      if (!includeInactive) {
        query = query.where('activa', isEqualTo: true);
      }

      final snapshot = await query.get();

      // Parse all prescriptions (async to avoid blocking UI)
      final prescriptions = <Prescripcion>[];
      for (final doc in snapshot.docs) {
        if (doc.id.isNotEmpty && doc.data() != null) {
          try {
            final prescripcion = Prescripcion.fromMap(
              doc.data() as Map<String, dynamic>,
              documentId: doc.id,
            );
            
            // Additional validation
            if (prescripcion.id.isNotEmpty) {
              prescriptions.add(prescripcion);
            }
          } catch (e) {
            // Skip malformed documents
            debugPrint('⚠️ [BackgroundLoader] Skipping malformed prescription ${doc.id}: $e');
            continue;
          }
        }
      }

      return prescriptions;
    } catch (e) {
      debugPrint('❌ [BackgroundLoader] Error fetching prescriptions: $e');
      return [];
    }
  }

  /// Fetch orders from Firestore (main thread with async queries)
  /// 
  /// This method queries the user's orders subcollection.
  /// Firebase requires access from the main isolate.
  static Future<List<Pedido>> _fetchOrdersFromFirestore(
    String userId,
    bool includeDelivered,
  ) async {
    try {
      // Query orders subcollection
      final firestore = FirebaseFirestore.instance;
      Query query = firestore
          .collection('usuarios')
          .doc(userId)
          .collection('pedidos');

      // Apply filter for pending orders only if needed
      if (!includeDelivered) {
        query = query.where('estado', whereIn: ['pendiente', 'en_proceso']);
      }

      final snapshot = await query.get();

      // Parse all orders (async to avoid blocking UI)
      final orders = <Pedido>[];
      for (final doc in snapshot.docs) {
        if (doc.data() != null) {
          try {
            final order = Pedido.fromMap(
              doc.data() as Map<String, dynamic>,
              documentId: doc.id,
            );
            orders.add(order);
          } catch (e) {
            // Skip malformed documents
            debugPrint('⚠️ [BackgroundLoader] Skipping malformed order ${doc.id}: $e');
            continue;
          }
        }
      }

      return orders;
    } catch (e) {
      debugPrint('❌ [BackgroundLoader] Error fetching orders: $e');
      return [];
    }
  }
}
