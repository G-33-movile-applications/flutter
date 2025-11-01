import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for favorite/frequent pharmacy tracking
/// 
/// This model supports:
/// - Explicit favorites (user-marked with heart icon)
/// - Automatic frequent pharmacy tracking (visit count)
/// - Offline-first with SQLite persistence
/// - Eventual connectivity sync with Firestore
class FavoritePharmacy {
  final String userId;
  final String pharmacyId;
  final bool isFavorite; // Explicitly marked as favorite
  final int visitsCount; // Number of orders from this pharmacy
  final DateTime lastVisited; // Most recent order/interaction
  final DateTime? favoriteMarkedAt; // When user explicitly favorited
  
  // Denormalized pharmacy data for offline display
  final String? pharmacyName;
  final String? pharmacyAddress;
  final double? pharmacyLat;
  final double? pharmacyLng;

  const FavoritePharmacy({
    required this.userId,
    required this.pharmacyId,
    this.isFavorite = false,
    this.visitsCount = 0,
    required this.lastVisited,
    this.favoriteMarkedAt,
    this.pharmacyName,
    this.pharmacyAddress,
    this.pharmacyLat,
    this.pharmacyLng,
  });

  /// Create from SQLite database row
  factory FavoritePharmacy.fromDb(Map<String, dynamic> map) {
    return FavoritePharmacy(
      userId: map['user_id'] as String,
      pharmacyId: map['pharmacy_id'] as String,
      isFavorite: (map['is_favorite'] as int) == 1,
      visitsCount: map['visits_count'] as int,
      lastVisited: DateTime.parse(map['last_visited'] as String),
      favoriteMarkedAt: map['favorite_marked_at'] != null
          ? DateTime.parse(map['favorite_marked_at'] as String)
          : null,
      pharmacyName: map['pharmacy_name'] as String?,
      pharmacyAddress: map['pharmacy_address'] as String?,
      pharmacyLat: map['pharmacy_lat'] as double?,
      pharmacyLng: map['pharmacy_lng'] as double?,
    );
  }

  /// Create from Firestore document (for sync)
  factory FavoritePharmacy.fromFirestore(Map<String, dynamic> map) {
    return FavoritePharmacy(
      userId: map['userId'] as String,
      pharmacyId: map['pharmacyId'] as String,
      isFavorite: map['isFavorite'] as bool? ?? false,
      visitsCount: map['visitsCount'] as int? ?? 0,
      lastVisited: (map['lastVisited'] as Timestamp).toDate(),
      favoriteMarkedAt: map['favoriteMarkedAt'] != null
          ? (map['favoriteMarkedAt'] as Timestamp).toDate()
          : null,
      pharmacyName: map['pharmacyName'] as String?,
      pharmacyAddress: map['pharmacyAddress'] as String?,
      pharmacyLat: map['pharmacyLat'] as double?,
      pharmacyLng: map['pharmacyLng'] as double?,
    );
  }

  /// Convert to SQLite database map
  Map<String, dynamic> toDb() {
    return {
      'user_id': userId,
      'pharmacy_id': pharmacyId,
      'is_favorite': isFavorite ? 1 : 0,
      'visits_count': visitsCount,
      'last_visited': lastVisited.toIso8601String(),
      'favorite_marked_at': favoriteMarkedAt?.toIso8601String(),
      'pharmacy_name': pharmacyName,
      'pharmacy_address': pharmacyAddress,
      'pharmacy_lat': pharmacyLat,
      'pharmacy_lng': pharmacyLng,
    };
  }

  /// Convert to Firestore document (for sync)
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'pharmacyId': pharmacyId,
      'isFavorite': isFavorite,
      'visitsCount': visitsCount,
      'lastVisited': Timestamp.fromDate(lastVisited),
      'favoriteMarkedAt': favoriteMarkedAt != null
          ? Timestamp.fromDate(favoriteMarkedAt!)
          : null,
      'pharmacyName': pharmacyName,
      'pharmacyAddress': pharmacyAddress,
      'pharmacyLat': pharmacyLat,
      'pharmacyLng': pharmacyLng,
      'syncedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with updated fields
  FavoritePharmacy copyWith({
    String? userId,
    String? pharmacyId,
    bool? isFavorite,
    int? visitsCount,
    DateTime? lastVisited,
    DateTime? favoriteMarkedAt,
    String? pharmacyName,
    String? pharmacyAddress,
    double? pharmacyLat,
    double? pharmacyLng,
  }) {
    return FavoritePharmacy(
      userId: userId ?? this.userId,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      isFavorite: isFavorite ?? this.isFavorite,
      visitsCount: visitsCount ?? this.visitsCount,
      lastVisited: lastVisited ?? this.lastVisited,
      favoriteMarkedAt: favoriteMarkedAt ?? this.favoriteMarkedAt,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
      pharmacyLat: pharmacyLat ?? this.pharmacyLat,
      pharmacyLng: pharmacyLng ?? this.pharmacyLng,
    );
  }

  @override
  String toString() {
    return 'FavoritePharmacy(userId: $userId, pharmacyId: $pharmacyId, '
        'isFavorite: $isFavorite, visits: $visitsCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoritePharmacy &&
        other.userId == userId &&
        other.pharmacyId == pharmacyId;
  }

  @override
  int get hashCode => Object.hash(userId, pharmacyId);
}
