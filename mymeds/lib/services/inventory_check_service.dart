import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';

import '../models/prescripcion.dart';
import '../models/medicamento_prescripcion.dart';
import '../models/punto_fisico.dart';
import '../models/inventory_check_result.dart';
import '../repositories/medicamento_prescripcion_repository.dart';
import '../repositories/punto_fisico_repository.dart';

/// Service for checking medicine availability and pricing at pharmacies
/// 
/// Features:
/// - Queries pharmacy inventory from puntosFisicos/{pharmacyId}/inventario/{medicineId}
/// - Parallel queries for performance (< 2 seconds for 10 medicines)
/// - 5-minute LRU cache to avoid redundant queries
/// - Fallback pricing ($0.00) when inventory data is missing
/// - Returns structured InventoryCheckResult with per-medicine details
class InventoryCheckService {
  // Singleton pattern
  static final InventoryCheckService _instance = InventoryCheckService._internal();
  factory InventoryCheckService() => _instance;
  InventoryCheckService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicamentoPrescripcionRepository _medicamentoRepo = MedicamentoPrescripcionRepository();
  final PuntoFisicoRepository _pharmacyRepo = PuntoFisicoRepository();

  /// LRU cache for inventory check results
  /// Key: "prescriptionId_pharmacyId"
  /// Value: InventoryCheckResult
  final LinkedHashMap<String, _CachedResult> _cache = LinkedHashMap<String, _CachedResult>();
  
  static const int _maxCacheSize = 50; // Maximum cached results
  static const Duration _cacheTTL = Duration(minutes: 5); // 5-minute cache

  /// Check prescription availability at a specific pharmacy
  /// 
  /// This method:
  /// 1. Loads prescription medications from subcollection
  /// 2. Queries inventory for each medicine in parallel
  /// 3. Returns structured result with stock, price, availability
  /// 4. Uses 5-minute cache to avoid redundant queries
  /// 5. Applies fallback pricing ($0.00) when data is missing
  /// 
  /// Performance: < 2 seconds for 10 medicines (parallel queries)
  Future<InventoryCheckResult> checkPrescriptionAvailability({
    required String prescriptionId,
    required String pharmacyId,
    required String userId,
  }) async {
    debugPrint('📋 [InventoryCheck] Checking availability for prescription $prescriptionId at pharmacy $pharmacyId');
    
    // Check cache first
    final cacheKey = '${prescriptionId}_$pharmacyId';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      debugPrint('✅ [InventoryCheck] Cache HIT: $cacheKey (age: ${DateTime.now().difference(cached.cachedAt).inSeconds}s)');
      return cached.result.copyWith(fromCache: true);
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Load prescription medications from subcollection
      debugPrint('🔍 [InventoryCheck] Loading prescription medications...');
      final medicines = await _medicamentoRepo.getMedicamentosByPrescripcion(
        userId: userId,
        prescripcionId: prescriptionId,
      );

      if (medicines.isEmpty) {
        debugPrint('⚠️ [InventoryCheck] No medicines found in prescription');
        throw Exception('Prescription has no medicines');
      }

      debugPrint('✅ [InventoryCheck] Found ${medicines.length} medicines in prescription');

      // 2. Load pharmacy information
      final pharmacy = await _pharmacyRepo.read(pharmacyId);
      if (pharmacy == null) {
        throw Exception('Pharmacy not found: $pharmacyId');
      }

      // 3. Query inventory for all medicines in parallel
      debugPrint('🔍 [InventoryCheck] Querying inventory for ${medicines.length} medicines in parallel...');
      final availabilityChecks = await Future.wait(
        medicines.map((medicine) => _checkMedicineAvailability(
          pharmacyId: pharmacyId,
          medicine: medicine,
        )),
      );

      stopwatch.stop();
      debugPrint('✅ [InventoryCheck] Inventory check completed in ${stopwatch.elapsedMilliseconds}ms');

      // 4. Calculate totals and build result
      final allAvailable = availabilityChecks.every((check) => check.available);
      final totalPrice = availabilityChecks.fold<double>(
        0.0,
        (sum, check) => sum + check.price,
      );

      final result = InventoryCheckResult(
        prescriptionId: prescriptionId,
        pharmacyId: pharmacyId,
        pharmacyName: pharmacy.nombre,
        allAvailable: allAvailable,
        medicines: availabilityChecks,
        totalPrice: totalPrice,
        checkedAt: DateTime.now(),
        fromCache: false,
      );

      // 5. Cache the result
      _putCache(cacheKey, result);

      debugPrint('📊 [InventoryCheck] Result: ${availabilityChecks.length} medicines, ${result.availableMedicines.length} available, \$${totalPrice.toStringAsFixed(2)} total');

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('❌ [InventoryCheck] Error checking availability (${stopwatch.elapsedMilliseconds}ms): $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check availability for a single medicine at a pharmacy
  /// 
  /// Queries: puntosFisicos/{pharmacyId}/inventario/{medicineId}
  /// Fields: stock, precioUnidad
  /// Fallback: price = 0.00 when data is missing
  Future<MedicineAvailability> _checkMedicineAvailability({
    required String pharmacyId,
    required MedicamentoPrescripcion medicine,
  }) async {
    try {
      // Query inventory subcollection
      final inventoryDoc = await _firestore
          .collection('puntosFisicos')
          .doc(pharmacyId)
          .collection('inventario')
          .doc(medicine.id)
          .get();

      if (!inventoryDoc.exists || inventoryDoc.data() == null) {
        // Inventory data missing - apply fallback
        debugPrint('⚠️ [InventoryCheck] No inventory data for medicine ${medicine.nombre} (${medicine.id}) - applying fallback');
        return MedicineAvailability(
          medicineId: medicine.id,
          medicineName: medicine.nombre,
          available: false,
          stock: 0,
          price: 0.00, // Fallback price
          missingData: true,
        );
      }

      final data = inventoryDoc.data()!;
      final stock = data['stock'] ?? 0;
      final precioUnidadCents = data['precioUnidad'] ?? 0;
      final priceDollars = precioUnidadCents / 100.0; // Convert cents to dollars

      final available = stock > 0;

      debugPrint('✅ [InventoryCheck] Medicine ${medicine.nombre}: stock=$stock, price=\$${priceDollars.toStringAsFixed(2)}, available=$available');

      return MedicineAvailability(
        medicineId: medicine.id,
        medicineName: medicine.nombre,
        available: available,
        stock: stock,
        price: priceDollars,
        missingData: false,
      );
    } catch (e) {
      debugPrint('❌ [InventoryCheck] Error checking medicine ${medicine.nombre}: $e');
      // Return fallback on error
      return MedicineAvailability(
        medicineId: medicine.id,
        medicineName: medicine.nombre,
        available: false,
        stock: 0,
        price: 0.00,
        missingData: true,
      );
    }
  }

  /// Get cached result if valid
  _CachedResult? _getCached(String key) {
    final cached = _cache[key];
    if (cached == null) return null;

    final age = DateTime.now().difference(cached.cachedAt);
    if (age > _cacheTTL) {
      // Cache expired
      _cache.remove(key);
      debugPrint('⏰ [InventoryCheck] Cache expired: $key (age: ${age.inMinutes}min)');
      return null;
    }

    // Move to end (most recently used)
    _cache.remove(key);
    _cache[key] = cached;

    return cached;
  }

  /// Put result in cache with LRU eviction
  void _putCache(String key, InventoryCheckResult result) {
    // If key exists, remove it first to update position
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      debugPrint('📝 [InventoryCheck] Updated cache entry: $key');
    } else {
      // Check if we need to evict
      if (_cache.length >= _maxCacheSize) {
        // Remove oldest entry (first entry in LinkedHashMap)
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
        debugPrint('🗑️ [InventoryCheck] Evicted LRU cache entry: $oldestKey');
      }
    }

    // Add new entry (goes to end - most recently used)
    _cache[key] = _CachedResult(
      result: result,
      cachedAt: DateTime.now(),
    );
    debugPrint('➕ [InventoryCheck] Cached result: $key (cache size: ${_cache.length}/$_maxCacheSize)');
  }

  /// Clear cache for a specific prescription+pharmacy combination
  void clearCache({required String prescriptionId, required String pharmacyId}) {
    final key = '${prescriptionId}_$pharmacyId';
    _cache.remove(key);
    debugPrint('🧹 [InventoryCheck] Cleared cache for: $key');
  }

  /// Clear entire cache
  void clearAllCache() {
    final oldSize = _cache.length;
    _cache.clear();
    debugPrint('🧹 [InventoryCheck] Cleared entire cache (removed $oldSize entries)');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    final validEntries = _cache.values.where((cached) {
      final age = now.difference(cached.cachedAt);
      return age <= _cacheTTL;
    }).length;

    return {
      'totalEntries': _cache.length,
      'validEntries': validEntries,
      'expiredEntries': _cache.length - validEntries,
      'maxSize': _maxCacheSize,
      'utilization': ((_cache.length / _maxCacheSize) * 100).toStringAsFixed(1) + '%',
      'ttlMinutes': _cacheTTL.inMinutes,
    };
  }

  /// Print cache statistics
  void printCacheStats() {
    final stats = getCacheStats();
    debugPrint('📊 [InventoryCheck] Cache Statistics:');
    stats.forEach((key, value) {
      debugPrint('   $key: $value');
    });
  }
}

/// Internal class for cached results
class _CachedResult {
  final InventoryCheckResult result;
  final DateTime cachedAt;

  _CachedResult({
    required this.result,
    required this.cachedAt,
  });
}

/// Extension to create a copy of InventoryCheckResult with updated fields
extension InventoryCheckResultCopyWith on InventoryCheckResult {
  InventoryCheckResult copyWith({
    String? prescriptionId,
    String? pharmacyId,
    String? pharmacyName,
    bool? allAvailable,
    List<MedicineAvailability>? medicines,
    double? totalPrice,
    DateTime? checkedAt,
    bool? fromCache,
  }) {
    return InventoryCheckResult(
      prescriptionId: prescriptionId ?? this.prescriptionId,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      allAvailable: allAvailable ?? this.allAvailable,
      medicines: medicines ?? this.medicines,
      totalPrice: totalPrice ?? this.totalPrice,
      checkedAt: checkedAt ?? this.checkedAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}
