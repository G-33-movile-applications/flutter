class UserStats {
  final int totalOrders;
  final int deliveryCount;
  final int pickupCount;
  final Map<String, int> pharmacyOrderCounts; // pharmacy ID -> order count
  final String? mostFrequentPharmacyId;
  final String? mostFrequentPharmacyName;
  final String preferredDeliveryMode; // "domicilio" or "recogida"
  
  // Business Question Type 2 fields
  final int totalMedicinesRequested; // Total count of medicines across all prescriptions
  final DateTime? lastClaimDate; // Most recent delivery date

  UserStats({
    required this.totalOrders,
    required this.deliveryCount,
    required this.pickupCount,
    required this.pharmacyOrderCounts,
    this.mostFrequentPharmacyId,
    this.mostFrequentPharmacyName,
    required this.preferredDeliveryMode,
    this.totalMedicinesRequested = 0,
    this.lastClaimDate,
  });

  double get deliveryPercentage => 
    totalOrders > 0 ? (deliveryCount / totalOrders) * 100 : 0;

  double get pickupPercentage => 
    totalOrders > 0 ? (pickupCount / totalOrders) * 100 : 0;

  factory UserStats.empty() {
    return UserStats(
      totalOrders: 0,
      deliveryCount: 0,
      pickupCount: 0,
      pharmacyOrderCounts: {},
      preferredDeliveryMode: 'domicilio',
      totalMedicinesRequested: 0,
      lastClaimDate: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOrders': totalOrders,
      'deliveryCount': deliveryCount,
      'pickupCount': pickupCount,
      'pharmacyOrderCounts': pharmacyOrderCounts,
      'mostFrequentPharmacyId': mostFrequentPharmacyId,
      'mostFrequentPharmacyName': mostFrequentPharmacyName,
      'preferredDeliveryMode': preferredDeliveryMode,
      'totalMedicinesRequested': totalMedicinesRequested,
      'lastClaimDate': lastClaimDate?.toIso8601String(),
    };
  }
  
  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalOrders: map['totalOrders'] ?? 0,
      deliveryCount: map['deliveryCount'] ?? 0,
      pickupCount: map['pickupCount'] ?? 0,
      pharmacyOrderCounts: Map<String, int>.from(map['pharmacyOrderCounts'] ?? {}),
      mostFrequentPharmacyId: map['mostFrequentPharmacyId'],
      mostFrequentPharmacyName: map['mostFrequentPharmacyName'],
      preferredDeliveryMode: map['preferredDeliveryMode'] ?? 'domicilio',
      totalMedicinesRequested: map['totalMedicinesRequested'] ?? 0,
      lastClaimDate: map['lastClaimDate'] != null 
          ? DateTime.parse(map['lastClaimDate'])
          : null,
    );
  }
}
