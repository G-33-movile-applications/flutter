import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';

import '../models/medicamento_global.dart';
import '../repositories/medicamento_repository.dart';

/// Result of medicine validation
class MedicineValidationResult {
  final bool found;
  final MedicamentoGlobal? medicine;
  final double confidence; // 0.0 to 1.0
  final String searchedName;
  final List<MedicamentoGlobal> suggestions; // Alternative matches

  const MedicineValidationResult({
    required this.found,
    this.medicine,
    required this.confidence,
    required this.searchedName,
    this.suggestions = const [],
  });

  bool get isExactMatch => confidence >= 0.95;
  bool get isStrongMatch => confidence >= 0.75;
  bool get hasAlternatives => suggestions.isNotEmpty;
}

/// Service for validating medicine names from OCR/NFC against Firestore inventory
/// 
/// Features:
/// - Checks existence in medicamentosGlobales or pharmacy inventory
/// - Case-insensitive and fuzzy matching (Levenshtein distance)
/// - 10-minute LRU cache to avoid repeated queries
/// - Offline fallback with cached medicines list
/// - Returns suggestions for unknown medicines
class MedicineValidationService {
  // Singleton pattern
  static final MedicineValidationService _instance = MedicineValidationService._internal();
  factory MedicineValidationService() => _instance;
  MedicineValidationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicamentoRepository _medicamentoRepo = MedicamentoRepository();

  /// LRU cache for validation results
  /// Key: "normalized_medicine_name"
  /// Value: MedicineValidationResult
  final LinkedHashMap<String, _CachedValidation> _cache = LinkedHashMap<String, _CachedValidation>();
  
  /// Cache of all global medicines for offline use
  List<MedicamentoGlobal>? _globalMedicinesCache;
  DateTime? _globalMedicinesCacheTime;
  
  static const int _maxCacheSize = 100; // Maximum cached validations
  static const Duration _cacheTTL = Duration(minutes: 10); // 10-minute cache
  static const Duration _globalCacheTTL = Duration(hours: 1); // 1-hour for global list

  /// Validate a medicine name from OCR/NFC
  /// 
  /// Search strategy:
  /// 1. Normalize name (lowercase, trim, remove accents)
  /// 2. Check cache first
  /// 3. Try exact match
  /// 4. Try partial match
  /// 5. Try fuzzy match (Levenshtein distance)
  /// 
  /// Returns MedicineValidationResult with:
  /// - found: true if medicine exists
  /// - medicine: MedicamentoGlobal if found
  /// - confidence: match confidence (0.0 to 1.0)
  /// - suggestions: alternative matches if not found
  Future<MedicineValidationResult> validateMedicine(String medicineName) async {
    debugPrint('🔍 [MedicineValidation] Validating: $medicineName');

    // Normalize input
    final normalized = _normalizeName(medicineName);
    
    if (normalized.isEmpty) {
      debugPrint('⚠️ [MedicineValidation] Empty name after normalization');
      return MedicineValidationResult(
        found: false,
        confidence: 0.0,
        searchedName: medicineName,
      );
    }

    // Check cache
    final cached = _getCached(normalized);
    if (cached != null) {
      debugPrint('✅ [MedicineValidation] Cache HIT: $normalized');
      return cached.result;
    }

    try {
      // Load global medicines (with caching)
      final medicines = await _loadGlobalMedicines();
      
      if (medicines.isEmpty) {
        debugPrint('⚠️ [MedicineValidation] No medicines in catalog');
        return MedicineValidationResult(
          found: false,
          confidence: 0.0,
          searchedName: medicineName,
        );
      }

      // 1. Try exact match
      final exactMatch = medicines.firstWhere(
        (m) => _normalizeName(m.nombre) == normalized,
        orElse: () => MedicamentoGlobal(
          id: '',
          nombre: '',
          principioActivo: '',
          presentacion: '',
          laboratorio: '',
          descripcion: '',
        ),
      );

      if (exactMatch.id.isNotEmpty) {
        debugPrint('✅ [MedicineValidation] Exact match: ${exactMatch.nombre}');
        final result = MedicineValidationResult(
          found: true,
          medicine: exactMatch,
          confidence: 1.0,
          searchedName: medicineName,
        );
        _putCache(normalized, result);
        return result;
      }

      // 2. Try partial match (contains)
      final partialMatches = medicines.where((m) {
        final medName = _normalizeName(m.nombre);
        return medName.contains(normalized) || normalized.contains(medName);
      }).toList();

      if (partialMatches.length == 1) {
        debugPrint('✅ [MedicineValidation] Partial match: ${partialMatches.first.nombre}');
        final result = MedicineValidationResult(
          found: true,
          medicine: partialMatches.first,
          confidence: 0.85,
          searchedName: medicineName,
        );
        _putCache(normalized, result);
        return result;
      }

      // 3. Try fuzzy match (Levenshtein distance)
      final fuzzyMatches = <_FuzzyMatch>[];
      for (final med in medicines) {
        final medName = _normalizeName(med.nombre);
        final distance = _levenshteinDistance(normalized, medName);
        final maxLength = normalized.length > medName.length ? normalized.length : medName.length;
        final similarity = 1.0 - (distance / maxLength);
        
        if (similarity >= 0.60) { // 60% similarity threshold
          fuzzyMatches.add(_FuzzyMatch(
            medicine: med,
            similarity: similarity,
          ));
        }
      }

      // Sort by similarity
      fuzzyMatches.sort((a, b) => b.similarity.compareTo(a.similarity));

      if (fuzzyMatches.isNotEmpty) {
        final bestMatch = fuzzyMatches.first;
        
        if (bestMatch.similarity >= 0.75) {
          // Strong fuzzy match
          debugPrint('✅ [MedicineValidation] Fuzzy match: ${bestMatch.medicine.nombre} (${(bestMatch.similarity * 100).toStringAsFixed(1)}%)');
          final result = MedicineValidationResult(
            found: true,
            medicine: bestMatch.medicine,
            confidence: bestMatch.similarity,
            searchedName: medicineName,
            suggestions: fuzzyMatches.skip(1).take(3).map((m) => m.medicine).toList(),
          );
          _putCache(normalized, result);
          return result;
        } else {
          // Weak match - return as suggestions
          debugPrint('⚠️ [MedicineValidation] No strong match, returning suggestions');
          final result = MedicineValidationResult(
            found: false,
            confidence: bestMatch.similarity,
            searchedName: medicineName,
            suggestions: fuzzyMatches.take(5).map((m) => m.medicine).toList(),
          );
          _putCache(normalized, result);
          return result;
        }
      }

      // No match found
      debugPrint('❌ [MedicineValidation] No match found for: $medicineName');
      final result = MedicineValidationResult(
        found: false,
        confidence: 0.0,
        searchedName: medicineName,
        suggestions: partialMatches.take(5).toList(),
      );
      _putCache(normalized, result);
      return result;

    } catch (e, stackTrace) {
      debugPrint('❌ [MedicineValidation] Error validating: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return MedicineValidationResult(
        found: false,
        confidence: 0.0,
        searchedName: medicineName,
      );
    }
  }

  /// Check if medicine exists in specific pharmacy inventory
  /// Queries puntosFisicos/{pharmacyId}/inventario/{medicineId}
  Future<bool> checkPharmacyInventory({
    required String medicineId,
    required String pharmacyId,
  }) async {
    try {
      final inventoryDoc = await _firestore
          .collection('puntosFisicos')
          .doc(pharmacyId)
          .collection('inventario')
          .doc(medicineId)
          .get();

      return inventoryDoc.exists && inventoryDoc.data() != null;
    } catch (e) {
      debugPrint('❌ [MedicineValidation] Error checking pharmacy inventory: $e');
      return false;
    }
  }

  /// Save unknown medicine to Firestore for admin review
  /// Stores in unknownMedicines collection
  Future<void> saveUnknownMedicine({
    required String proposedName,
    required String uploadedBy,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final docId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('unknownMedicines').doc(docId).set({
        'proposedName': proposedName,
        'uploadedBy': uploadedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, approved, rejected
        'requiresValidation': true,
        ...?additionalData,
      });

      debugPrint('✅ [MedicineValidation] Unknown medicine saved: $docId');
    } catch (e) {
      debugPrint('❌ [MedicineValidation] Error saving unknown medicine: $e');
      rethrow;
    }
  }

  /// Add medicine directly to global catalog (with mock data)
  /// Use when admin confirms a new medicine
  Future<String> addMedicineToGlobalCatalog({
    required String nombre,
    String? principioActivo,
    String? presentacion,
    String? laboratorio,
  }) async {
    try {
      final docId = 'med_${DateTime.now().millisecondsSinceEpoch}';
      
      final medicine = {
        'nombre': nombre,
        'principioActivo': principioActivo ?? nombre, // Default to name
        'presentacion': presentacion ?? 'Tableta', // Default presentation
        'laboratorio': laboratorio ?? 'Laboratorio General',
        'descripcion': 'Medicamento agregado por usuario',
        'contraindicaciones': <String>[],
        'imagenUrl': null,
      };

      await _firestore.collection('medicamentosGlobales').doc(docId).set(medicine);

      // Clear cache to force reload
      _globalMedicinesCache = null;
      _globalMedicinesCacheTime = null;
      _cache.clear();

      debugPrint('✅ [MedicineValidation] Medicine added to catalog: $docId');
      return docId;
    } catch (e) {
      debugPrint('❌ [MedicineValidation] Error adding medicine: $e');
      rethrow;
    }
  }

  /// Load global medicines list with caching
  Future<List<MedicamentoGlobal>> _loadGlobalMedicines() async {
    // Check if cached and still valid
    if (_globalMedicinesCache != null && _globalMedicinesCacheTime != null) {
      final age = DateTime.now().difference(_globalMedicinesCacheTime!);
      if (age <= _globalCacheTTL) {
        debugPrint('✅ [MedicineValidation] Using cached global medicines (${_globalMedicinesCache!.length} items)');
        return _globalMedicinesCache!;
      }
    }

    // Load from Firestore
    debugPrint('🔄 [MedicineValidation] Loading global medicines from Firestore...');
    try {
      final medicines = await _medicamentoRepo.readAll();
      _globalMedicinesCache = medicines;
      _globalMedicinesCacheTime = DateTime.now();
      debugPrint('✅ [MedicineValidation] Loaded ${medicines.length} global medicines');
      return medicines;
    } catch (e) {
      debugPrint('❌ [MedicineValidation] Error loading medicines: $e');
      // Return cached data even if expired as fallback
      return _globalMedicinesCache ?? [];
    }
  }

  /// Normalize medicine name for matching
  /// - Convert to lowercase
  /// - Trim whitespace
  /// - Remove accents
  /// - Remove extra spaces
  String _normalizeName(String name) {
    var normalized = name.toLowerCase().trim();
    
    // Remove accents
    const accents = 'áéíóúÁÉÍÓÚñÑüÜ';
    const noAccents = 'aeiouAEIOUnNuU';
    for (int i = 0; i < accents.length; i++) {
      normalized = normalized.replaceAll(accents[i], noAccents[i]);
    }
    
    // Remove extra spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    return normalized;
  }

  /// Calculate Levenshtein distance between two strings
  /// Returns the minimum number of edits (insertions, deletions, substitutions)
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Get cached validation result if valid
  _CachedValidation? _getCached(String key) {
    final cached = _cache[key];
    if (cached == null) return null;

    final age = DateTime.now().difference(cached.cachedAt);
    if (age > _cacheTTL) {
      _cache.remove(key);
      return null;
    }

    // Move to end (LRU)
    _cache.remove(key);
    _cache[key] = cached;

    return cached;
  }

  /// Put validation result in cache with LRU eviction
  void _putCache(String key, MedicineValidationResult result) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      debugPrint('🗑️ [MedicineValidation] Evicted LRU cache entry: $oldestKey');
    }

    _cache[key] = _CachedValidation(
      result: result,
      cachedAt: DateTime.now(),
    );
    debugPrint('➕ [MedicineValidation] Cached result: $key');
  }

  /// Clear all caches
  void clearCache() {
    _cache.clear();
    _globalMedicinesCache = null;
    _globalMedicinesCacheTime = null;
    debugPrint('🧹 [MedicineValidation] All caches cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'validationCacheSize': _cache.length,
      'validationCacheMax': _maxCacheSize,
      'globalMedicinesCached': _globalMedicinesCache?.length ?? 0,
      'cacheTTLMinutes': _cacheTTL.inMinutes,
    };
  }
}

/// Internal class for cached validation results
class _CachedValidation {
  final MedicineValidationResult result;
  final DateTime cachedAt;

  _CachedValidation({
    required this.result,
    required this.cachedAt,
  });
}

/// Internal class for fuzzy matching
class _FuzzyMatch {
  final MedicamentoGlobal medicine;
  final double similarity;

  _FuzzyMatch({
    required this.medicine,
    required this.similarity,
  });
}
