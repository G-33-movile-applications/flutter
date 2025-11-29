import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/autofill_entry.dart';
import 'user_session.dart';

/// Service for managing smart autofill suggestions
/// 
/// Features:
/// - Records user form selections with frequency tracking
/// - Calculates top-N suggestions using background Isolate computation
/// - Supports enable/disable via settings
/// - Filters sensitive fields (passwords, credit cards, etc.)
/// - Implements decay factor for stale suggestions
/// - Privacy-first: all data stored locally, no backend sync
class AutofillService {
  static final AutofillService _instance = AutofillService._internal();
  factory AutofillService() => _instance;
  AutofillService._internal();

  static const String _boxName = 'autofill_entries';
  static const String _settingsBoxName = 'autofill_settings';
  static const String _enabledKey = 'autofill_enabled';
  
  Box<AutofillEntry>? _box;
  Box? _settingsBox;
  bool _isInitialized = false;
  
  /// Fields that should never be tracked (sensitive data)
  static const Set<String> _sensitiveFields = {
    'password',
    'credit_card',
    'cvv',
    'pin',
    'ssn',
    'social_security',
    'card_number',
  };

  /// Initialize Hive boxes for autofill storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(AutofillEntryAdapter());
      }
      
      // Open boxes
      _box = await Hive.openBox<AutofillEntry>(_boxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);
      
      _isInitialized = true;
      debugPrint('✅ [AutofillService] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [AutofillService] Initialization error: $e');
      rethrow;
    }
  }

  /// Check if autofill is enabled in settings
  bool get isEnabled {
    if (_settingsBox == null) return true; // Default: enabled
    return _settingsBox!.get(_enabledKey, defaultValue: true) as bool;
  }

  /// Enable or disable autofill
  Future<void> setEnabled(bool enabled) async {
    await _settingsBox?.put(_enabledKey, enabled);
    debugPrint('🔧 [AutofillService] Autofill ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Record a form field selection
  /// 
  /// This increments the count for the given entity/field/value combination
  /// or creates a new entry if it doesn't exist.
  /// 
  /// Runs synchronously but triggers background cleanup/optimization.
  Future<void> recordSelection({
    required String entity,
    required String field,
    required String value,
  }) async {
    // Skip if disabled or not initialized
    if (!isEnabled || !_isInitialized || _box == null) {
      return;
    }

    // Skip sensitive fields
    if (_isSensitiveField(field)) {
      debugPrint('🔒 [AutofillService] Skipping sensitive field: $field');
      return;
    }

    // Skip empty values
    if (value.trim().isEmpty) {
      return;
    }

    try {
      final userId = UserSession().currentUid ?? 'anonymous';
      final key = '${userId}_${entity}_${field}_$value';
      
      // Get existing entry or create new one
      final existingEntry = _box!.get(key);
      
      if (existingEntry != null) {
        // Update existing entry
        existingEntry.count++;
        existingEntry.lastUsed = DateTime.now();
        await existingEntry.save();
        
        debugPrint('📝 [AutofillService] Updated: $entity.$field = "$value" (count: ${existingEntry.count})');
      } else {
        // Create new entry
        final newEntry = AutofillEntry(
          entity: entity,
          field: field,
          value: value,
          count: 1,
          lastUsed: DateTime.now(),
        );
        
        await _box!.put(key, newEntry);
        debugPrint('✨ [AutofillService] Created: $entity.$field = "$value"');
      }

      // Trigger background cleanup periodically (every 10 records)
      if (_box!.length % 10 == 0) {
        _cleanupStaleEntries();
      }
    } catch (e) {
      debugPrint('❌ [AutofillService] Error recording selection: $e');
    }
  }

  /// Get top-N suggestions for a field
  /// 
  /// Calculates suggestions in background isolate to avoid UI jank.
  /// Returns suggestions sorted by weighted score (frequency + recency).
  Future<List<String>> getSuggestions({
    required String entity,
    required String field,
    int topN = 3,
  }) async {
    // Skip if disabled or not initialized
    if (!isEnabled || !_isInitialized || _box == null) {
      return [];
    }

    try {
      // Get all entries for this field
      final entries = _box!.values
          .where((entry) => 
              entry.entity == entity && 
              entry.field == field &&
              !entry.isStale)
          .toList();

      if (entries.isEmpty) {
        return [];
      }

      // Calculate suggestions in background isolate
      final suggestions = await compute(_calculateTopSuggestions, {
        'entries': entries,
        'topN': topN,
      });

      debugPrint('💡 [AutofillService] Suggestions for $entity.$field: $suggestions');
      return suggestions;
    } catch (e) {
      debugPrint('❌ [AutofillService] Error getting suggestions: $e');
      return [];
    }
  }

  /// Get suggestion for a specific field with context
  /// 
  /// This is a convenience method that returns the top suggestion only
  Future<String?> getTopSuggestion({
    required String entity,
    required String field,
  }) async {
    final suggestions = await getSuggestions(
      entity: entity,
      field: field,
      topN: 1,
    );
    
    return suggestions.isNotEmpty ? suggestions.first : null;
  }

  /// Clear all autofill history
  Future<void> clearAllHistory() async {
    if (_box == null) return;
    
    try {
      final userId = UserSession().currentUid ?? 'anonymous';
      
      // Delete all entries for current user
      final keysToDelete = _box!.keys
          .where((key) => key.toString().startsWith(userId))
          .toList();
      
      await _box!.deleteAll(keysToDelete);
      
      debugPrint('🗑️ [AutofillService] Cleared ${keysToDelete.length} entries');
    } catch (e) {
      debugPrint('❌ [AutofillService] Error clearing history: $e');
    }
  }

  /// Clear history for a specific entity
  Future<void> clearEntityHistory(String entity) async {
    if (_box == null) return;
    
    try {
      final userId = UserSession().currentUid ?? 'anonymous';
      final prefix = '${userId}_$entity\_';
      
      final keysToDelete = _box!.keys
          .where((key) => key.toString().startsWith(prefix))
          .toList();
      
      await _box!.deleteAll(keysToDelete);
      
      debugPrint('🗑️ [AutofillService] Cleared $entity history: ${keysToDelete.length} entries');
    } catch (e) {
      debugPrint('❌ [AutofillService] Error clearing entity history: $e');
    }
  }

  /// Get statistics about stored autofill data
  Map<String, dynamic> getStatistics() {
    if (_box == null) return {};
    
    final userId = UserSession().currentUid ?? 'anonymous';
    final userEntries = _box!.values
        .where((entry) => _box!.keys.any((key) => key.toString().startsWith(userId)))
        .toList();
    
    final totalEntries = userEntries.length;
    final staleEntries = userEntries.where((e) => e.isStale).length;
    final entitiesCovered = userEntries.map((e) => e.entity).toSet().length;
    final fieldsCovered = userEntries.map((e) => e.field).toSet().length;
    
    return {
      'totalEntries': totalEntries,
      'staleEntries': staleEntries,
      'activeEntries': totalEntries - staleEntries,
      'entitiesCovered': entitiesCovered,
      'fieldsCovered': fieldsCovered,
      'isEnabled': isEnabled,
    };
  }

  /// Background task: Remove stale entries (not used in 90+ days)
  void _cleanupStaleEntries() {
    if (_box == null) return;
    
    compute(_findStaleKeys, _box!.values.toList()).then((staleKeys) {
      if (staleKeys.isNotEmpty) {
        _box!.deleteAll(staleKeys);
        debugPrint('🧹 [AutofillService] Cleaned up ${staleKeys.length} stale entries');
      }
    }).catchError((e) {
      debugPrint('❌ [AutofillService] Error in cleanup: $e');
    });
  }

  /// Check if a field is sensitive and should not be tracked
  bool _isSensitiveField(String field) {
    final fieldLower = field.toLowerCase();
    return _sensitiveFields.any((sensitive) => fieldLower.contains(sensitive));
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _box?.close();
    await _settingsBox?.close();
    _isInitialized = false;
  }
}

// ============================================================================
// Background Isolate Functions
// ============================================================================

/// Calculate top N suggestions based on weighted scores (runs in isolate)
List<String> _calculateTopSuggestions(Map<String, dynamic> params) {
  final entries = params['entries'] as List<AutofillEntry>;
  final topN = params['topN'] as int;
  
  // Sort by weighted score (descending)
  entries.sort((a, b) => b.weightedScore.compareTo(a.weightedScore));
  
  // Return top N values
  return entries
      .take(topN)
      .map((e) => e.value)
      .toList();
}

/// Find stale entry keys (runs in isolate)
List<String> _findStaleKeys(List<AutofillEntry> entries) {
  return entries
      .where((entry) => entry.isStale)
      .map((entry) => entry.key)
      .toList();
}
