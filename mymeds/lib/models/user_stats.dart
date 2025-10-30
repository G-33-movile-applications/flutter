class UserStats {
  final int totalOrders;
  final int deliveryCount;
  final int pickupCount;
  final Map<String, int> pharmacyOrderCounts; // pharmacy ID -> order count
  final String? mostFrequentPharmacyId;
  final String? mostFrequentPharmacyName;
  final String preferredDeliveryMode; // "domicilio" or "recogida"

  UserStats({
    required this.totalOrders,
    required this.deliveryCount,
    required this.pickupCount,
    required this.pharmacyOrderCounts,
    this.mostFrequentPharmacyId,
    this.mostFrequentPharmacyName,
    required this.preferredDeliveryMode,
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
    };
  }
}
