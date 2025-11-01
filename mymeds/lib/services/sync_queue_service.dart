import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'connectivity_service.dart';

/// Represents a sync operation type
enum SyncOperationType {
  createPedido,
  updatePrescripcion,
}

/// Represents a queued sync operation
class QueuedSyncOperation {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  QueuedSyncOperation({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory QueuedSyncOperation.fromJson(Map<String, dynamic> json) {
    return QueuedSyncOperation(
      id: json['id'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  QueuedSyncOperation copyWithRetry() {
    return QueuedSyncOperation(
      id: id,
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount + 1,
    );
  }
}

/// Service for managing offline sync operations
/// 
/// Handles queuing of operations when offline and automatic sync when online.
/// Uses SharedPreferences for persistent storage across app restarts.
class SyncQueueService {
  // Singleton pattern
  SyncQueueService._internal();
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;

  // Storage key
  static const String _storageKey = 'sync_queue';
  static const int _maxRetries = 3;

  SharedPreferences? _prefs;
  final ConnectivityService _connectivityService = ConnectivityService();
  final List<QueuedSyncOperation> _queue = [];
  bool _isSyncing = false;
  bool _isInitialized = false;

  /// Callback for executing pedido creation
  Future<void> Function(Map<String, dynamic>)? onCreatePedido;

  /// Callback for executing prescription update
  Future<void> Function(String prescripcionId, Map<String, dynamic> updates)? onUpdatePrescripcion;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadQueue();
      _listenToConnectivity();
      _isInitialized = true;
      debugPrint('✅ SyncQueueService initialized with ${_queue.length} pending operations');
    } catch (e) {
      debugPrint('❌ SyncQueueService initialization failed: $e');
      rethrow;
    }
  }

  /// Get SharedPreferences instance
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await _preferences;
      final queueJson = prefs.getString(_storageKey);

      if (queueJson != null && queueJson.isNotEmpty) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _queue.clear();
        _queue.addAll(
          queueList.map((json) => QueuedSyncOperation.fromJson(json as Map<String, dynamic>)),
        );
        debugPrint('📥 Loaded ${_queue.length} operations from queue');
      }
    } catch (e) {
      debugPrint('❌ Error loading sync queue: $e');
    }
  }

  /// Save queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await _preferences;
      final queueJson = jsonEncode(_queue.map((op) => op.toJson()).toList());
      await prefs.setString(_storageKey, queueJson);
      debugPrint('💾 Saved ${_queue.length} operations to queue');
    } catch (e) {
      debugPrint('❌ Error saving sync queue: $e');
    }
  }

  /// Listen to connectivity changes
  void _listenToConnectivity() {
    _connectivityService.connectionStream.listen((connectionType) {
      if (connectionType != ConnectionType.none && _queue.isNotEmpty) {
        debugPrint('🌐 Connection restored! Starting sync of ${_queue.length} operations...');
        syncPendingActions();
      }
    });
  }

  /// Queue a delivery creation operation
  Future<void> queueDeliveryCreation(Map<String, dynamic> pedidoData) async {
    final operation = QueuedSyncOperation(
      id: const Uuid().v4(),
      type: SyncOperationType.createPedido,
      data: pedidoData,
    );

    _queue.add(operation);
    await _saveQueue();
    debugPrint('📦 Queued delivery creation: ${operation.id}');
  }

  /// Queue a prescription update operation
  Future<void> queuePrescriptionUpdate(String prescripcionId, Map<String, dynamic> updates) async {
    final operation = QueuedSyncOperation(
      id: const Uuid().v4(),
      type: SyncOperationType.updatePrescripcion,
      data: {
        'prescripcionId': prescripcionId,
        'updates': updates,
      },
    );

    _queue.add(operation);
    await _saveQueue();
    debugPrint('📋 Queued prescription update: ${operation.id}');
  }

  /// Sync all pending actions
  Future<SyncResult> syncPendingActions() async {
    if (_isSyncing) {
      debugPrint('⏸️ Sync already in progress, skipping...');
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    if (_queue.isEmpty) {
      debugPrint('✅ No pending operations to sync');
      return SyncResult(success: true, message: 'No pending operations');
    }

    // Check connectivity before syncing
    final isConnected = await _connectivityService.checkConnectivity();
    if (!isConnected) {
      debugPrint('📴 No connection available, deferring sync');
      return SyncResult(success: false, message: 'No internet connection');
    }

    _isSyncing = true;
    final operationsToProcess = List<QueuedSyncOperation>.from(_queue);
    final failedOperations = <QueuedSyncOperation>[];
    int successCount = 0;

    debugPrint('🔄 Starting sync of ${operationsToProcess.length} operations...');

    for (final operation in operationsToProcess) {
      try {
        await _executeOperation(operation);
        _queue.remove(operation);
        successCount++;
        debugPrint('✅ Synced operation ${operation.id} (${operation.type})');
      } catch (e) {
        debugPrint('❌ Failed to sync operation ${operation.id}: $e');
        
        // Retry logic
        if (operation.retryCount < _maxRetries) {
          final retriedOp = operation.copyWithRetry();
          _queue[_queue.indexOf(operation)] = retriedOp;
          debugPrint('🔄 Retry ${retriedOp.retryCount}/$_maxRetries for operation ${operation.id}');
        } else {
          _queue.remove(operation);
          failedOperations.add(operation);
          debugPrint('⛔ Max retries reached for operation ${operation.id}, removing from queue');
        }
      }
    }

    await _saveQueue();
    _isSyncing = false;

    final result = SyncResult(
      success: failedOperations.isEmpty,
      successCount: successCount,
      failedCount: failedOperations.length,
      message: _buildSyncMessage(successCount, failedOperations.length),
    );

    debugPrint('🎯 Sync completed: ${result.message}');
    return result;
  }

  /// Execute a single operation
  Future<void> _executeOperation(QueuedSyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.createPedido:
        if (onCreatePedido == null) {
          throw Exception('onCreatePedido callback not set');
        }
        await onCreatePedido!(operation.data);
        break;

      case SyncOperationType.updatePrescripcion:
        if (onUpdatePrescripcion == null) {
          throw Exception('onUpdatePrescripcion callback not set');
        }
        final prescripcionId = operation.data['prescripcionId'] as String;
        final updates = operation.data['updates'] as Map<String, dynamic>;
        await onUpdatePrescripcion!(prescripcionId, updates);
        break;
    }
  }

  /// Build sync result message
  String _buildSyncMessage(int successCount, int failedCount) {
    if (successCount > 0 && failedCount == 0) {
      return 'Pending deliveries synced ($successCount operation${successCount > 1 ? 's' : ''})';
    } else if (successCount > 0 && failedCount > 0) {
      return 'Partially synced: $successCount succeeded, $failedCount failed';
    } else if (failedCount > 0) {
      return 'Sync failed: $failedCount operation${failedCount > 1 ? 's' : ''} could not be processed';
    } else {
      return 'No operations to sync';
    }
  }

  /// Get pending operation count
  int get pendingCount => _queue.length;

  /// Check if sync is in progress
  bool get isSyncing => _isSyncing;

  /// Check if there are pending operations
  bool get hasPendingOperations => _queue.isNotEmpty;

  /// Clear all pending operations (use with caution)
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    debugPrint('🗑️ Sync queue cleared');
  }

  /// Get all pending operations (for debugging/UI)
  List<QueuedSyncOperation> getPendingOperations() {
    return List.unmodifiable(_queue);
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int successCount;
  final int failedCount;
  final String message;

  SyncResult({
    required this.success,
    this.successCount = 0,
    this.failedCount = 0,
    required this.message,
  });

  @override
  String toString() => 'SyncResult(success: $success, message: $message)';
}
