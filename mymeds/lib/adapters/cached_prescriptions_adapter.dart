import 'package:flutter/foundation.dart';
import '../models/prescripcion.dart';
import '../repositories/prescripcion_repository.dart';
import '../services/cache_service.dart';
import '../services/sync_service.dart';

/// Adapter that wraps PrescripcionRepository with caching logic
/// 
/// When Data Saver Mode is enabled:
/// - Returns cached prescriptions if available
/// - Queues sync operations instead of making immediate requests
/// - Uses offline-first strategy with local cache as primary source
class CachedPrescriptionsAdapter {
  final PrescripcionRepository _repository = PrescripcionRepository();
  final CacheService _cacheService = CacheService();
  final SyncService _syncService = SyncService();

  bool _dataSaverEnabled = false;

  /// Set Data Saver Mode state
  void setDataSaverMode(bool enabled) {
    _dataSaverEnabled = enabled;
    debugPrint(
      '📋 CachedPrescriptionsAdapter Data Saver: ${enabled ? 'ENABLED' : 'DISABLED'}',
    );
  }

  /// Get all prescriptions with caching support
  /// 
  /// If Data Saver is enabled:
  /// - First tries to return from cache
  /// - If cache miss and on Wi-Fi, fetches fresh data and caches it
  /// - If cache miss and on mobile, returns empty list or queues sync
  Future<List<Prescripcion>> readAll({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'prescriptions_all';

    // If not in Data Saver mode, use normal repository
    if (!_dataSaverEnabled) {
      return _repository.readAll();
    }

    // Try cache first
    if (!forceRefresh) {
      final cached = _cacheService.get<List<Prescripcion>>(cacheKey);
      if (cached != null) {
        debugPrint('📋 Prescriptions from cache (${cached.length} items)');
        return cached;
      }
    }

    // If cache miss, queue a sync operation and return empty
    debugPrint('📋 Prescriptions cache miss - queueing sync');
    await _syncService.queueSyncOperation(
      id: 'prescription_fetch_all',
      operationType: 'prescription_sync',
      data: {'action': 'fetch_all'},
    );

    return [];
  }

  /// Get a specific prescription with caching
  Future<Prescripcion?> read(String id) async {
    final cacheKey = 'prescription_$id';

    if (!_dataSaverEnabled) {
      return _repository.read(id);
    }

    // Try cache first
    final cached = _cacheService.get<Prescripcion>(cacheKey);
    if (cached != null) {
      debugPrint('📋 Prescription $id from cache');
      return cached;
    }

    return null;
  }

  /// Create a prescription with caching
  /// 
  /// When Data Saver enabled:
  /// - Cache the new prescription optimistically
  /// - Queue the sync operation
  /// - Return the optimistic result
  Future<void> create(Prescripcion prescription) async {
    if (!_dataSaverEnabled) {
      return _repository.create(prescription);
    }

    // Optimistic update: cache immediately
    final cacheKey = 'prescription_${prescription.id}';
    _cacheService.set<Prescripcion>(cacheKey, prescription);

    // Queue sync operation with toMap() for serialization
    await _syncService.queueSyncOperation(
      id: 'prescription_create_${prescription.id}',
      operationType: 'prescription_sync',
      data: prescription.toMap(),
    );

    debugPrint('📋 Prescription created (queued sync)');
  }

  /// Update a prescription with caching
  Future<void> update(Prescripcion prescription) async {
    if (!_dataSaverEnabled) {
      return _repository.update(prescription);
    }

    // Optimistic update: cache immediately
    final cacheKey = 'prescription_${prescription.id}';
    _cacheService.set<Prescripcion>(cacheKey, prescription);

    // Queue sync operation
    await _syncService.queueSyncOperation(
      id: 'prescription_update_${prescription.id}',
      operationType: 'prescription_sync',
      data: prescription.toMap(),
    );

    debugPrint('📋 Prescription updated (queued sync)');
  }

  /// Delete a prescription with caching
  Future<void> delete(String id) async {
    if (!_dataSaverEnabled) {
      return _repository.delete(id);
    }

    // Optimistic deletion: remove from cache
    _cacheService.remove('prescription_$id');

    // Queue sync operation
    await _syncService.queueSyncOperation(
      id: 'prescription_delete_$id',
      operationType: 'prescription_sync',
      data: {'id': id, 'action': 'delete'},
    );

    debugPrint('📋 Prescription deleted (queued sync)');
  }

  /// Clear the prescription cache
  void clearCache() {
    _cacheService.clear();
    debugPrint('📋 Prescription cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _cacheService.getStats();
  }
}
