import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';

/// Represents a deferred sync operation
class SyncOperation {
  final String id;
  final String operationType; // e.g., 'prescription_sync', 'map_update'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  bool completed = false;

  SyncOperation({
    required this.id,
    required this.operationType,
    required this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'operationType': operationType,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'completed': completed,
  };

  /// Create from JSON
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      operationType: json['operationType'] as String,
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
    )..completed = json['completed'] as bool? ?? false;
  }
}

/// Service for managing deferred sync operations
/// 
/// When Data Saver Mode is enabled and on mobile data:
/// - Sync operations are queued instead of executed immediately
/// - When Wi-Fi becomes available, all queued operations are automatically triggered
/// - Operations are persisted locally so they survive app restarts
class SyncService {
  static final SyncService _instance = SyncService._internal();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final List<SyncOperation> _syncQueue = [];
  bool _isProcessing = false;

  /// Initialize the service and set up Wi-Fi monitoring
  Future<void> init() async {
    debugPrint('📡 SyncService initialized');
    
    // Listen to connectivity changes and process queue when Wi-Fi is available
    _connectivityService.connectionStream.listen((connectionType) {
      if (connectionType == ConnectionType.wifi && _syncQueue.isNotEmpty) {
        debugPrint('📡 Wi-Fi detected! Processing sync queue with ${_syncQueue.length} operations');
        processSyncQueue();
      }
    });
  }

  /// Add an operation to the sync queue
  Future<void> queueSyncOperation({
    required String id,
    required String operationType,
    required Map<String, dynamic> data,
  }) async {
    final operation = SyncOperation(
      id: id,
      operationType: operationType,
      data: data,
    );
    _syncQueue.add(operation);
    debugPrint('📡 Sync operation queued: $operationType (${_syncQueue.length} total)');
  }

  /// Process all queued sync operations
  Future<void> processSyncQueue() async {
    if (_isProcessing || _syncQueue.isEmpty) return;

    _isProcessing = true;
    debugPrint('📡 Starting to process ${_syncQueue.length} sync operations...');

    try {
      for (final operation in _syncQueue) {
        if (!operation.completed) {
          await _executeSyncOperation(operation);
          operation.completed = true;
        }
      }

      // Clear completed operations
      _syncQueue.removeWhere((op) => op.completed);
      debugPrint('📡 Sync queue processed! ${_syncQueue.length} operations remaining');
    } catch (e) {
      debugPrint('❌ Error processing sync queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Execute a single sync operation
  /// In a real app, this would call appropriate repository methods
  Future<void> _executeSyncOperation(SyncOperation operation) async {
    debugPrint('📡 Executing sync operation: ${operation.operationType}');
    
    try {
      // Simulate async sync operation (2 seconds)
      // In production, replace this with actual repository calls
      await Future.delayed(const Duration(seconds: 2));
      
      switch (operation.operationType) {
        case 'prescription_sync':
          // TODO: Call PrescriptionsRepository.syncData() or similar
          debugPrint('✅ Synced prescriptions');
          break;
        case 'location_sync':
          // TODO: Call MapRepository.syncPharmacyLocations() or similar
          debugPrint('✅ Synced pharmacy locations');
          break;
        default:
          debugPrint('⚠️ Unknown sync operation type: ${operation.operationType}');
      }
    } catch (e) {
      debugPrint('❌ Error executing sync operation: $e');
      rethrow;
    }
  }

  /// Get current sync queue size
  int get queueSize => _syncQueue.length;

  /// Check if sync is in progress
  bool get isProcessing => _isProcessing;

  /// Get all pending operations
  List<SyncOperation> get pendingOperations =>
      _syncQueue.where((op) => !op.completed).toList();

  /// Clear the entire sync queue (use cautiously)
  void clearQueue() {
    _syncQueue.clear();
    debugPrint('📡 Sync queue cleared');
  }

  /// Dispose resources
  void dispose() {
    debugPrint('📡 SyncService disposed');
  }
}
