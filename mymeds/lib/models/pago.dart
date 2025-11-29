import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// Payment model for MyMeds payment processing
/// 
/// Represents a payment transaction for a prescription order.
/// Supports offline-first storage and eventual sync to Firestore.
/// 
/// Collection path: usuarios/{userId}/pagos/{pagoId}
class Pago {
  final String id; // Payment ID (generated)
  final String userId;
  final String prescriptionId;
  final String pharmacyId;
  final String orderId; // Generated order ID
  final double total;
  final String method; // 'credit', 'debit', 'cash_on_delivery', 'mock'
  final Map<String, double> prices; // medicationId -> price mapping
  final double deliveryFee;
  final DateTime transactionDate;
  final String status; // 'pending', 'processing', 'completed', 'failed'

  const Pago({
    required this.id,
    required this.userId,
    required this.prescriptionId,
    required this.pharmacyId,
    required this.orderId,
    required this.total,
    required this.method,
    required this.prices,
    required this.deliveryFee,
    required this.transactionDate,
    required this.status,
  });

  /// Create Pago from Firestore document
  factory Pago.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Pago(
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      prescriptionId: map['prescriptionId'] ?? '',
      pharmacyId: map['pharmacyId'] ?? '',
      orderId: map['orderId'] ?? '',
      total: (map['total'] ?? 0).toDouble(),
      method: map['method'] ?? 'mock',
      prices: Map<String, double>.from(
        (map['prices'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ) ?? {},
      ),
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      transactionDate: _parseTransactionDate(map['transactionDate']),
      status: map['status'] ?? 'pending',
    );
  }

  /// Helper to parse transactionDate from various formats
  static DateTime _parseTransactionDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  /// Convert Pago to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'prescriptionId': prescriptionId,
      'pharmacyId': pharmacyId,
      'orderId': orderId,
      'total': total,
      'method': method,
      'prices': prices,
      'deliveryFee': deliveryFee,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'status': status,
    };
  }

  /// Convert Pago to JSON string
  String toJson() => json.encode(toMap());

  /// Create Pago from JSON string
  factory Pago.fromJson(String source) =>
      Pago.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Create a copy with modified fields
  Pago copyWith({
    String? id,
    String? userId,
    String? prescriptionId,
    String? pharmacyId,
    String? orderId,
    double? total,
    String? method,
    Map<String, double>? prices,
    double? deliveryFee,
    DateTime? transactionDate,
    String? status,
  }) {
    return Pago(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      orderId: orderId ?? this.orderId,
      total: total ?? this.total,
      method: method ?? this.method,
      prices: prices ?? this.prices,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'Pago(id: $id, userId: $userId, orderId: $orderId, total: $total, method: $method, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Pago && other.id == id && other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
