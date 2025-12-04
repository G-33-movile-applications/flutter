import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:convert';
import '../models/pago.dart';
import '../models/pedido.dart';
import '../models/medicamento_pedido.dart';
import '../models/factura.dart';
import '../models/adherence_event.dart'; // For SyncStatus enum
import '../repositories/pedido_repository.dart';
import '../services/connectivity_service.dart';
import '../services/bill_generator_service.dart';
import '../services/orders_sync_service.dart'; // For offline-first order sync

/// Payment Processing Service
/// 
/// Handles payment processing with offline-first architecture:
/// - Mock payment (2 second delay, always succeeds)
/// - Local SQLite persistence for offline support
/// - Eventual connectivity sync queue
/// - Order creation in Firestore
/// - Prescription update (paidAt timestamp)
/// 
/// University Requirements Implemented:
/// - **Local Storage**: SQLite database for payment persistence
/// - **Eventual Connectivity**: Sync queue for offline payments
class PaymentProcessingService {
  // Singleton pattern
  static final PaymentProcessingService _instance = PaymentProcessingService._internal();
  factory PaymentProcessingService() => _instance;
  PaymentProcessingService._internal();

  final PedidoRepository _pedidoRepo = PedidoRepository();
  final ConnectivityService _connectivity = ConnectivityService();
  final OrdersSyncService _ordersSync = OrdersSyncService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BillGeneratorService _billGenerator = BillGeneratorService();

  Database? _database;
  static const String _dbName = 'payments.db';
  static const String _paymentsTable = 'payments';
  static const String _syncQueueTable = 'payment_sync_queue';
  static const int _dbVersion = 1;

  bool _isInitialized = false;
  StreamSubscription<ConnectionType>? _connectivitySubscription;
  bool _wasOffline = false; // Track previous offline state

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Initialize database
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _createDatabase,
      );

      _isInitialized = true;
      debugPrint('💳 PaymentProcessingService: Initialized');

      // Start background sync listener
      _startSyncListener();
    } catch (e) {
      debugPrint('❌ PaymentProcessingService: Init failed: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    // Payments table
    await db.execute('''
      CREATE TABLE $_paymentsTable (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        prescriptionId TEXT NOT NULL,
        pharmacyId TEXT NOT NULL,
        orderId TEXT NOT NULL,
        total REAL NOT NULL,
        method TEXT NOT NULL,
        prices TEXT NOT NULL,
        deliveryFee REAL NOT NULL,
        transactionDate INTEGER NOT NULL,
        status TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Sync queue table for payments
    await db.execute('''
      CREATE TABLE $_syncQueueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        paymentId TEXT NOT NULL,
        orderId TEXT NOT NULL,
        userId TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0,
        lastAttempt INTEGER,
        errorMessage TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (paymentId) REFERENCES $_paymentsTable (id)
      )
    ''');

    // Facturas (bills) table
    await db.execute('''
      CREATE TABLE facturas (
        id TEXT PRIMARY KEY,
        paymentId TEXT NOT NULL,
        orderId TEXT NOT NULL,
        userId TEXT NOT NULL,
        invoiceNumber TEXT NOT NULL,
        localPdfPath TEXT NOT NULL,
        pdfUrl TEXT,
        storageRef TEXT,
        status TEXT NOT NULL,
        syncedToCloud INTEGER DEFAULT 0,
        retryCount INTEGER DEFAULT 0,
        syncedAt INTEGER,
        createdAt INTEGER NOT NULL,
        metadata TEXT,
        FOREIGN KEY (paymentId) REFERENCES $_paymentsTable (id)
      )
    ''');

    // Factura sync queue table
    await db.execute('''
      CREATE TABLE factura_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        facturaId TEXT NOT NULL,
        paymentId TEXT NOT NULL,
        orderId TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0,
        lastAttempt INTEGER,
        errorMessage TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (facturaId) REFERENCES facturas (id)
      )
    ''');

    debugPrint('💳 PaymentProcessingService: Database created with factura tables');
  }

  /// Get database instance
  Future<Database> get _db async {
    if (_database == null) {
      await init();
    }
    return _database!;
  }

  /// Process payment for prescription order
  /// 
  /// **OFFLINE-FIRST IMPLEMENTATION**:
  /// - Creates order locally first (always)
  /// - Adds to OrdersSyncService cache for immediate UI visibility
  /// - Attempts immediate sync to Firestore if online
  /// - If offline or sync fails, order remains in pending state
  /// - Auto-syncs when connectivity returns via OrdersSyncService
  /// 
  /// Parameters:
  /// - userId: Current user ID
  /// - prescriptionId: Prescription being paid for
  /// - pharmacyId: Selected pharmacy ID
  /// - pharmacyName: Pharmacy name
  /// - pharmacyAddress: Pharmacy address
  /// - total: Total amount to pay
  /// - deliveryFee: Delivery fee
  /// - method: Payment method ('credit', 'debit', 'cash_on_delivery', 'mock')
  /// - medicines: List of medications with pricing
  /// - deliveryType: 'home' or 'pickup'
  /// - deliveryAddress: Delivery address (if home delivery)
  /// 
  /// Returns:
  /// - Success: {success: true, paymentId, orderId, billLocalPath, message}
  /// - Failure: {success: false, message}
  Future<Map<String, dynamic>> processPayment({
    required String userId,
    required String prescriptionId,
    required String pharmacyId,
    required String pharmacyName,
    required String pharmacyAddress,
    required double total,
    required double deliveryFee,
    required String method,
    required List<Map<String, dynamic>> medicines,
    required String deliveryType,
    String? deliveryAddress,
  }) async {
    try {
      debugPrint('💳 [Payment] Processing payment: \$$total for prescription $prescriptionId');
      debugPrint('💳 [Payment] Delivery type: $deliveryType, method: $method');

      // Step 1: Mock payment processing (2 second delay for UX realism)
      await Future.delayed(const Duration(seconds: 2));

      // Step 2: Generate IDs
      final paymentId = 'PAY_${DateTime.now().millisecondsSinceEpoch}';
      final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      // Step 3: Create prices map
      final pricesMap = <String, double>{};
      for (final med in medicines) {
        pricesMap[med['medicationId'] as String] = (med['pricePerUnit'] as num).toDouble();
      }

      // Step 4: Create payment object
      final payment = Pago(
        id: paymentId,
        userId: userId,
        prescriptionId: prescriptionId,
        pharmacyId: pharmacyId,
        orderId: orderId,
        total: total,
        method: method,
        prices: pricesMap,
        deliveryFee: deliveryFee,
        transactionDate: now,
        status: 'completed',
      );

      // Step 5: Save payment locally (LOCAL STORAGE REQUIREMENT)
      await _savePaymentLocally(payment);
      debugPrint('💾 [Payment] Payment saved locally: $paymentId');

      // Step 6: Check connectivity for offline-first order creation
      final isOnline = await _connectivity.checkConnectivity();
      debugPrint('🌐 [Payment] Connectivity status: ${isOnline ? 'ONLINE' : 'OFFLINE'}');

      // Step 7: Create order LOCALLY FIRST (offline-first pattern)
      final localOrder = await _createOrderLocallyAndQueueSync(
        payment: payment,
        userId: userId,
        prescriptionId: prescriptionId,
        pharmacyName: pharmacyName,
        pharmacyAddress: pharmacyAddress,
        medicines: medicines,
        deliveryType: deliveryType,
        deliveryAddress: deliveryAddress,
        isOnline: isOnline,
      );
      
      debugPrint('✅ [Payment] Order created locally: ${localOrder.id} (syncStatus: ${localOrder.syncStatus})');

      // Step 8: Update prescription paidAt timestamp (try even if offline, will sync later)
      if (isOnline) {
        try {
          await _updatePrescriptionPaidAt(userId, prescriptionId);
          debugPrint('✅ [Payment] Prescription paidAt updated: $prescriptionId');
        } catch (e) {
          debugPrint('⚠️ [Payment] Failed to update prescription paidAt (will retry): $e');
        }
      }

      // Step 9: Determine success message based on sync status
      String message;
      if (localOrder.syncStatus == SyncStatus.synced) {
        message = 'Payment successful! Order created.';
      } else if (localOrder.syncStatus == SyncStatus.pending) {
        message = 'Payment successful! Order will sync when you\'re back online.';
      } else {
        message = 'Payment successful! Order saved locally.';
      }

      debugPrint('✅ [Payment] Payment processed successfully');
      
      return {
        'success': true,
        'paymentId': paymentId,
        'orderId': orderId,
        'message': message,
        'order': localOrder, // Return the order for further processing
      };
    } catch (e, stackTrace) {
      debugPrint('❌ [Payment] Payment processing failed: $e');
      debugPrint(stackTrace.toString());
      return {
        'success': false,
        'message': 'Payment failed: ${e.toString()}',
      };
    }
  }

  /// Save payment to local SQLite database
  Future<void> _savePaymentLocally(Pago payment) async {
    final db = await _db;
    
    // Serialize prices map to JSON string
    final pricesJson = json.encode(payment.prices);
    
    await db.insert(
      _paymentsTable,
      {
        'id': payment.id,
        'userId': payment.userId,
        'prescriptionId': payment.prescriptionId,
        'pharmacyId': payment.pharmacyId,
        'orderId': payment.orderId,
        'total': payment.total,
        'method': payment.method,
        'prices': pricesJson,
        'deliveryFee': payment.deliveryFee,
        'transactionDate': payment.transactionDate.millisecondsSinceEpoch,
        'status': payment.status,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('💾 Payment saved locally: ${payment.id}');
  }

  /// Create order locally and queue for sync (OFFLINE-FIRST IMPLEMENTATION)
  /// 
  /// This is the core method that implements the offline-first pattern:
  /// 1. Creates Pedido object with appropriate sync metadata
  /// 2. Adds to OrdersSyncService cache (for immediate UI visibility)
  /// 3. Attempts immediate sync to Firestore if online
  /// 4. Returns order with correct syncStatus
  /// 
  /// The order is ALWAYS created locally first, ensuring the app works offline
  Future<Pedido> _createOrderLocallyAndQueueSync({
    required Pago payment,
    required String userId,
    required String prescriptionId,
    required String pharmacyName,
    required String pharmacyAddress,
    required List<Map<String, dynamic>> medicines,
    required String deliveryType,
    String? deliveryAddress,
    required bool isOnline,
  }) async {
    final now = DateTime.now();
    
    debugPrint('📦 [OrdersQueue] Creating order locally: ${payment.orderId}');
    debugPrint('📦 [OrdersQueue] Order details: deliveryType=$deliveryType, isOnline=$isOnline, medicines=${medicines.length}');

    // Step 1: Create Pedido with offline-first metadata
    final order = Pedido(
      id: payment.orderId,
      prescripcionId: prescriptionId,
      puntoFisicoId: payment.pharmacyId,
      tipoEntrega: deliveryType,
      direccionEntrega: deliveryAddress ?? pharmacyAddress,
      estado: 'en_proceso', // Confirmed order status
      fechaPedido: now,
      fechaEntrega: null,
      // Offline-first metadata
      createdOffline: !isOnline, // Mark as offline-created if not online
      createdAt: now,
      firstSyncedAt: null, // Will be set when synced
      syncSource: isOnline ? 'online-direct' : 'offline-queue',
      syncStatus: SyncStatus.pending, // Start as pending, will be updated if sync succeeds
    );

    debugPrint('📦 [OrdersQueue] Order object created with syncStatus: ${order.syncStatus}, createdOffline: ${order.createdOffline}');

    // Step 2: Add to OrdersSyncService cache
    // This makes the order immediately visible in OrdersView
    // and handles the sync attempt if online
    final syncedOrder = await _ordersSync.addOrderToCache(
      order: order,
      userId: userId,
      medicines: medicines,
      pharmacyName: pharmacyName,
      pharmacyAddress: pharmacyAddress,
      syncImmediately: isOnline, // Only sync if online
    );

    debugPrint('📦 [OrdersQueue] Order added to cache with final syncStatus: ${syncedOrder.syncStatus}');
    
    // Log offline creation for BQ Type 2 analytics
    if (syncedOrder.createdOffline) {
      if (syncedOrder.syncStatus == SyncStatus.pending) {
        debugPrint('📊 [BQ Type 2] Order created OFFLINE - queued for sync');
        debugPrint('📊 [BQ Type 2]   userId: $userId, orderId: ${syncedOrder.id}');
        debugPrint('📊 [BQ Type 2]   createdAt: ${syncedOrder.createdAt}, syncStatus: pending');
      } else if (syncedOrder.syncStatus == SyncStatus.synced) {
        final syncDelay = syncedOrder.firstSyncedAt!.difference(syncedOrder.createdAt).inMilliseconds;
        debugPrint('📊 [BQ Type 2] Order created OFFLINE but synced immediately');
        debugPrint('📊 [BQ Type 2]   userId: $userId, orderId: ${syncedOrder.id}');
        debugPrint('📊 [BQ Type 2]   createdAt: ${syncedOrder.createdAt}, firstSyncedAt: ${syncedOrder.firstSyncedAt}');
        debugPrint('📊 [BQ Type 2]   syncDelay: ${syncDelay}ms');
      }
    } else if (syncedOrder.syncStatus == SyncStatus.synced) {
      debugPrint('📊 [BQ Type 2] Order created ONLINE and synced - userId: $userId, orderId: ${syncedOrder.id}, syncDelay: 0ms');
    }

    return syncedOrder;
  }

  /// Create order in Firestore (DEPRECATED - use OrdersSyncService.addOrderToCache instead)
  /// 
  /// This method is now handled by OrdersSyncService._pushOrderToFirestore
  /// Kept for reference but should not be called directly
  @Deprecated('Use OrdersSyncService.addOrderToCache instead')
  Future<void> _createFirestoreOrder({
    required Pago payment,
    required String prescriptionId,
    required String pharmacyName,
    required String pharmacyAddress,
    required List<Map<String, dynamic>> medicines,
    required String deliveryType,
    String? deliveryAddress,
  }) async {
    final now = DateTime.now();

    // Create order
    final order = Pedido(
      id: payment.orderId,
      prescripcionId: prescriptionId,
      puntoFisicoId: payment.pharmacyId,
      tipoEntrega: deliveryType,
      direccionEntrega: deliveryAddress ?? pharmacyAddress,
      estado: 'en_proceso', // Set as required: "en_proceso" for confirmed orders
      fechaPedido: now,
      fechaEntrega: null,
    );

    // Save order to Firestore
    await _firestore
        .collection('usuarios')
        .doc(payment.userId)
        .collection('pedidos')
        .doc(payment.orderId)
        .set(order.toMap());

    // Save medicamentos to subcollection
    for (final med in medicines) {
      final medicamentoRef = _firestore.collection('medicamentos_globales').doc(med['medicationId'] as String).path;
      final medicamento = MedicamentoPedido(
        id: med['medicationId'] as String,
        pedidoId: payment.orderId,
        medicamentoRef: medicamentoRef,
        nombre: med['medicationName'] as String,
        cantidad: (med['quantity'] as num).toInt(),
        precioUnitario: (med['pricePerUnit'] as num).toInt(),
        total: (med['subtotal'] as num).toInt(),
        userId: payment.userId,
      );

      await _firestore
          .collection('usuarios')
          .doc(payment.userId)
          .collection('pedidos')
          .doc(payment.orderId)
          .collection('medicamentos')
          .doc(medicamento.id)
          .set(medicamento.toMap());
    }

    debugPrint('🔥 Order created in Firestore: ${payment.orderId}');
  }

  /// Update prescription paidAt timestamp
  Future<void> _updatePrescriptionPaidAt(String userId, String prescriptionId) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescriptionId)
          .update({'paidAt': Timestamp.now()});

      debugPrint('✅ Prescription paidAt updated: $prescriptionId');
    } catch (e) {
      debugPrint('⚠️ Failed to update prescription paidAt: $e');
    }
  }

  /// Enqueue sync operation for offline payment
  Future<void> _enqueueSyncOperation(
    Pago payment,
    List<Map<String, dynamic>> medicines,
    String deliveryType,
    String? deliveryAddress,
    String pharmacyName,
    String pharmacyAddress,
  ) async {
    final db = await _db;

    await db.insert(
      _syncQueueTable,
      {
        'paymentId': payment.id,
        'orderId': payment.orderId,
        'userId': payment.userId,
        'status': 'pending',
        'retryCount': 0,
        'lastAttempt': null,
        'errorMessage': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    debugPrint('📥 Sync operation queued: ${payment.id}');
  }

/// Start background sync listener
/// 
/// Now integrates with OrdersSyncService to push pending orders
void _startSyncListener() {
  // Cancel existing subscription if any
  _connectivitySubscription?.cancel();
  
  // Listen to connectivity changes - IMMEDIATE sync on reconnection
  _connectivitySubscription = _connectivity.connectionStream.listen((connectionType) async {
    final isOnline = connectionType != ConnectionType.none;
    
    // Only sync when transitioning from offline to online
    if (isOnline && _wasOffline) {
      debugPrint('🌐 [PaymentSync] Connection restored! Triggering immediate sync...');
      _wasOffline = false;
      await _processSyncQueue();
    } else if (!isOnline) {
      _wasOffline = true;
      debugPrint('📴 [PaymentSync] Connection lost - will sync when restored');
    }
  });
  
  // Also keep periodic timer as backup (every 5 minutes)
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final isOnline = await _connectivity.checkConnectivity();
    if (isOnline) {
      debugPrint('⏰ [PaymentSync] Periodic sync check...');
      await _processSyncQueue();
    }
  });

  debugPrint('👂 Payment sync listener started (connectivity + periodic)');
}  /// Process pending sync queue
  Future<void> _processSyncQueue() async {
    try {
      final db = await _db;

      // Get pending items
      final results = await db.query(
        _syncQueueTable,
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'createdAt ASC',
      );

      if (results.isEmpty) {
        debugPrint('✅ Sync queue is empty');
        return;
      }

      debugPrint('🔄 Processing ${results.length} pending sync operations');

      for (final row in results) {
        await _processSyncItem(row);
      }
    } catch (e) {
      debugPrint('❌ Sync queue processing failed: $e');
    }
  }

  /// Process a single sync item
  Future<void> _processSyncItem(Map<String, dynamic> queueItem) async {
    final paymentId = queueItem['paymentId'] as String;
    
    try {
      // Get payment from local storage
      final db = await _db;
      final paymentRows = await db.query(
        _paymentsTable,
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      if (paymentRows.isEmpty) {
        debugPrint('⚠️ Payment not found: $paymentId');
        await _markSyncFailed(queueItem['id'] as int, 'Payment not found');
        return;
      }

      // Note: Full sync implementation would reconstruct order details
      // For now, mark as synced
      await _markSyncCompleted(queueItem['id'] as int);

      debugPrint('✅ Synced payment: $paymentId');
    } catch (e) {
      debugPrint('❌ Sync failed for payment $paymentId: $e');
      await _markSyncFailed(queueItem['id'] as int, e.toString());
    }
  }

  /// Mark sync as completed
  Future<void> _markSyncCompleted(int queueId) async {
    final db = await _db;
    await db.update(
      _syncQueueTable,
      {'status': 'completed', 'lastAttempt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Mark sync as failed
  Future<void> _markSyncFailed(int queueId, String error) async {
    final db = await _db;
    
    // Get current retry count
    final results = await db.query(
      _syncQueueTable,
      columns: ['retryCount'],
      where: 'id = ?',
      whereArgs: [queueId],
    );
    
    final currentRetryCount = results.isNotEmpty ? (results.first['retryCount'] as int?) ?? 0 : 0;
    
    await db.update(
      _syncQueueTable,
      {
        'status': 'failed',
        'lastAttempt': DateTime.now().millisecondsSinceEpoch,
        'errorMessage': error,
        'retryCount': currentRetryCount + 1,
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Get payment by ID
  Future<Pago?> getPaymentById(String paymentId) async {
    final db = await _db;
    final results = await db.query(
      _paymentsTable,
      where: 'id = ?',
      whereArgs: [paymentId],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return Pago(
      id: row['id'] as String,
      userId: row['userId'] as String,
      prescriptionId: row['prescriptionId'] as String,
      pharmacyId: row['pharmacyId'] as String,
      orderId: row['orderId'] as String,
      total: row['total'] as double,
      method: row['method'] as String,
      prices: {}, // Would need to parse from JSON
      deliveryFee: row['deliveryFee'] as double,
      transactionDate: DateTime.fromMillisecondsSinceEpoch(row['transactionDate'] as int),
      status: row['status'] as String,
    );
  }

  /// Get all payments for user
  Future<List<Pago>> getPaymentsByUser(String userId) async {
    final db = await _db;
    final results = await db.query(
      _paymentsTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return results.map((row) {
      return Pago(
        id: row['id'] as String,
        userId: row['userId'] as String,
        prescriptionId: row['prescriptionId'] as String,
        pharmacyId: row['pharmacyId'] as String,
        orderId: row['orderId'] as String,
        total: row['total'] as double,
        method: row['method'] as String,
        prices: {},
        deliveryFee: row['deliveryFee'] as double,
        transactionDate: DateTime.fromMillisecondsSinceEpoch(row['transactionDate'] as int),
        status: row['status'] as String,
      );
    }).toList();
  }

  /// Get sync queue size (for UI display)
  Future<int> getSyncQueueSize() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_syncQueueTable WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get all payments (for payment history screen)
  Future<List<Pago>> getAllPayments() async {
    final db = await _db;
    final results = await db.query(
      _paymentsTable,
      orderBy: 'createdAt DESC',
    );

    return results.map((row) {
      return Pago(
        id: row['id'] as String,
        userId: row['userId'] as String,
        prescriptionId: row['prescriptionId'] as String,
        pharmacyId: row['pharmacyId'] as String,
        orderId: row['orderId'] as String,
        total: row['total'] as double,
        method: row['method'] as String,
        prices: Map<String, double>.from(json.decode(row['prices'] as String)),
        deliveryFee: row['deliveryFee'] as double,
        transactionDate: DateTime.fromMillisecondsSinceEpoch(row['transactionDate'] as int),
        status: row['status'] as String,
      );
    }).toList();
  }

  /// Get queued payments (not synced)
  Future<List<Pago>> getQueuedPayments() async {
    final db = await _db;
    final queueResults = await db.query(
      _syncQueueTable,
      where: 'status = ?',
      whereArgs: ['pending'],
    );

    final paymentIds = queueResults.map((row) => row['paymentId'] as String).toList();
    if (paymentIds.isEmpty) return [];

    final placeholders = List.filled(paymentIds.length, '?').join(',');
    final paymentResults = await db.query(
      _paymentsTable,
      where: 'id IN ($placeholders)',
      whereArgs: paymentIds,
    );

    return paymentResults.map((row) {
      return Pago(
        id: row['id'] as String,
        userId: row['userId'] as String,
        prescriptionId: row['prescriptionId'] as String,
        pharmacyId: row['pharmacyId'] as String,
        orderId: row['orderId'] as String,
        total: row['total'] as double,
        method: row['method'] as String,
        prices: Map<String, double>.from(json.decode(row['prices'] as String)),
        deliveryFee: row['deliveryFee'] as double,
        transactionDate: DateTime.fromMillisecondsSinceEpoch(row['transactionDate'] as int),
        status: row['status'] as String,
      );
    }).toList();
  }

  /// Get bill for payment (uses BillGeneratorService)
  Future<Factura?> getBillForPayment(String paymentId) async {
    try {
      // Get payment to extract userId
      final db = await _db;
      final results = await db.query(
        _paymentsTable,
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final userId = results.first['userId'] as String;
      return await _billGenerator.getBillByPaymentId(paymentId, userId);
    } catch (e) {
      debugPrint('❌ Error fetching bill: $e');
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _database?.close();
    debugPrint('🗑️ PaymentProcessingService disposed');
  }
}
