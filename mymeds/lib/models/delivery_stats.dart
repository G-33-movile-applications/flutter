class DeliveryStats {
  final int totalOrders;
  final int deliveryCount;
  final int pickupCount;
  final Map<String, int> deliveryByMonth;
  final Map<String, int> pickupByMonth;

  DeliveryStats({
    required this.totalOrders,
    required this.deliveryCount,
    required this.pickupCount,
    required this.deliveryByMonth,
    required this.pickupByMonth,
  });

  double get deliveryPercentage => 
    totalOrders > 0 ? (deliveryCount / totalOrders) * 100 : 0;

  double get pickupPercentage => 
    totalOrders > 0 ? (pickupCount / totalOrders) * 100 : 0;

  factory DeliveryStats.fromMap(Map<String, dynamic> data) {
    return DeliveryStats(
      totalOrders: data['totalOrders'] ?? 0,
      deliveryCount: data['deliveryCount'] ?? 0,
      pickupCount: data['pickupCount'] ?? 0,
      deliveryByMonth: Map<String, int>.from(data['deliveryByMonth'] ?? {}),
      pickupByMonth: Map<String, int>.from(data['pickupByMonth'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOrders': totalOrders,
      'deliveryCount': deliveryCount,
      'pickupCount': pickupCount,
      'deliveryByMonth': deliveryByMonth,
      'pickupByMonth': pickupByMonth,
    };
  }
}