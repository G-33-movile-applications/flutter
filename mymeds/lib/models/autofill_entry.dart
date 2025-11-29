import 'package:hive/hive.dart';

part 'autofill_entry.g.dart';

/// Represents a single autofill entry that tracks user form selections
/// 
/// This model stores:
/// - entity: The context/screen where the field appears (e.g., 'delivery', 'profile')
/// - field: The specific field identifier (e.g., 'branch', 'provider', 'delivery_type')
/// - value: The selected value
/// - count: Usage frequency (incremented each time user selects this value)
/// - lastUsed: Timestamp of last selection (for decay/TTL calculations)
@HiveType(typeId: 5) // Using typeId 5 - ensure this doesn't conflict with other Hive models
class AutofillEntry extends HiveObject {
  @HiveField(0)
  String entity;

  @HiveField(1)
  String field;

  @HiveField(2)
  String value;

  @HiveField(3)
  int count;

  @HiveField(4)
  DateTime lastUsed;

  AutofillEntry({
    required this.entity,
    required this.field,
    required this.value,
    required this.count,
    required this.lastUsed,
  });

  /// Composite key for unique identification
  String get key => '${entity}_$field\_$value';

  /// Calculate age in days since last use
  int get ageInDays => DateTime.now().difference(lastUsed).inDays;

  /// Calculate a weighted score for ranking suggestions
  /// 
  /// Score considers:
  /// - Usage count (more important)
  /// - Recency (decay factor for old entries)
  /// 
  /// Decay factor: 0.98^days (entries lose ~2% value per day)
  double get weightedScore {
    final decayFactor = 0.98; // 2% decay per day
    final ageFactor = decayFactor * ageInDays;
    return count * ageFactor;
  }

  /// Check if entry is stale (not used in 90 days)
  bool get isStale => ageInDays > 90;

  @override
  String toString() {
    return 'AutofillEntry(entity: $entity, field: $field, value: $value, '
        'count: $count, lastUsed: $lastUsed, score: ${weightedScore.toStringAsFixed(2)})';
  }

  /// Create a copy with updated fields
  AutofillEntry copyWith({
    String? entity,
    String? field,
    String? value,
    int? count,
    DateTime? lastUsed,
  }) {
    return AutofillEntry(
      entity: entity ?? this.entity,
      field: field ?? this.field,
      value: value ?? this.value,
      count: count ?? this.count,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}
