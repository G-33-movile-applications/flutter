import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// Invoice/Bill model for MyMeds
/// 
/// Represents a generated PDF invoice with metadata and sync status.
/// Supports offline-first local storage and eventual sync to Firestore + Firebase Storage.
/// 
/// Collection path: usuarios/{userId}/facturas/{facturaId}
/// Firebase Storage path: invoices/{userId}/{pdfFile}
class Factura {
  final String id; // Factura ID (generated)
  final String invoiceNumber; // Human-readable invoice number
  final String localPdfPath; // Local file path: /bills/bill_{paymentId}.pdf
  final String? pdfUrl; // Firebase Storage download URL (nullable until uploaded)
  final String? storageRef; // Firebase Storage reference path (nullable until uploaded)
  final Map<String, dynamic> orderSnapshot; // Nested order data snapshot
  final String status; // 'generated', 'uploading', 'uploaded', 'failed'
  final bool syncedToCloud; // Whether uploaded to Firebase
  final int retryCount; // Number of upload retry attempts
  final DateTime createdAt; // When locally generated
  final DateTime updatedAt; // Last update timestamp
  final int? syncedAt; // Unix timestamp when synced to cloud (nullable)
  final String userId;
  final String orderId;
  final int pageCount; // Number of pages in PDF
  final int fileSize; // File size in bytes
  final int generatedAt; // Unix timestamp when PDF generated
  final Map<String, dynamic> metadata; // Additional metadata (e.g., generator version)
  final String? errorMessage; // Error message if upload failed (nullable)
  final String? userEmail; // User email at generation time (nullable)
  final String? userName; // User name at generation time (nullable)

  const Factura({
    required this.id,
    required this.invoiceNumber,
    required this.localPdfPath,
    this.pdfUrl,
    this.storageRef,
    required this.orderSnapshot,
    required this.status,
    required this.syncedToCloud,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
    required this.userId,
    required this.orderId,
    required this.pageCount,
    required this.fileSize,
    required this.generatedAt,
    required this.metadata,
    this.errorMessage,
    this.userEmail,
    this.userName,
  });

  /// Create Factura from Firestore document
  factory Factura.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Factura(
      id: documentId ?? map['id'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      localPdfPath: map['localPdfPath'] ?? '',
      pdfUrl: map['pdfUrl'],
      storageRef: map['storageRef'],
      orderSnapshot: Map<String, dynamic>.from(map['orderSnapshot'] ?? {}),
      status: map['status'] ?? 'generated',
      syncedToCloud: map['syncedToCloud'] ?? false,
      retryCount: map['retryCount'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      syncedAt: map['syncedAt'],
      userId: map['userId'] ?? '',
      orderId: map['orderId'] ?? '',
      pageCount: map['pageCount'] ?? 1,
      fileSize: map['fileSize'] ?? 0,
      generatedAt: map['generatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      errorMessage: map['errorMessage'],
      userEmail: map['userEmail'],
      userName: map['userName'],
    );
  }

  /// Convert Factura to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'localPdfPath': localPdfPath,
      'pdfUrl': pdfUrl,
      'storageRef': storageRef,
      'orderSnapshot': orderSnapshot,
      'status': status,
      'syncedToCloud': syncedToCloud,
      'retryCount': retryCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'syncedAt': syncedAt,
      'userId': userId,
      'orderId': orderId,
      'pageCount': pageCount,
      'fileSize': fileSize,
      'generatedAt': generatedAt,
      'metadata': metadata,
      'errorMessage': errorMessage,
      'userEmail': userEmail,
      'userName': userName,
    };
  }

  /// Convert Factura to JSON string
  String toJson() => json.encode(toMap());

  /// Create Factura from JSON string
  factory Factura.fromJson(String source) =>
      Factura.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Create a copy with modified fields
  Factura copyWith({
    String? id,
    String? invoiceNumber,
    String? localPdfPath,
    String? pdfUrl,
    String? storageRef,
    Map<String, dynamic>? orderSnapshot,
    String? status,
    bool? syncedToCloud,
    int? retryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncedAt,
    String? userId,
    String? orderId,
    int? pageCount,
    int? fileSize,
    int? generatedAt,
    Map<String, dynamic>? metadata,
    String? errorMessage,
    String? userEmail,
    String? userName,
  }) {
    return Factura(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      localPdfPath: localPdfPath ?? this.localPdfPath,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      storageRef: storageRef ?? this.storageRef,
      orderSnapshot: orderSnapshot ?? this.orderSnapshot,
      status: status ?? this.status,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      pageCount: pageCount ?? this.pageCount,
      fileSize: fileSize ?? this.fileSize,
      generatedAt: generatedAt ?? this.generatedAt,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
    );
  }

  @override
  String toString() {
    return 'Factura(id: $id, invoiceNumber: $invoiceNumber, status: $status, syncedToCloud: $syncedToCloud, userId: $userId, orderId: $orderId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Factura && other.id == id && other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
