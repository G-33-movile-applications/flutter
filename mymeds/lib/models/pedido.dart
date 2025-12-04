import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import './adherence_event.dart'; // For SyncStatus enum

class Pedido {
  final String id;
  final String prescripcionId;
  final String puntoFisicoId;
  final String tipoEntrega; // "domicilio" or "recogida"
  final String direccionEntrega;
  final String estado; // "pendiente", "en_proceso", "entregado", "cancelado"
  final DateTime fechaPedido;
  final DateTime? fechaEntrega;
  // Note: medicamentos are now stored as a subcollection, not embedded
  
  // Cached pharmacy data for offline display (non-persistent, cached only)
  final String? cachedPharmacyName;
  final String? cachedPharmacyAddress;
  
  // Analytics fields for Type 2 Business Question:
  // "What proportion of orders is created offline, and how long do they take to synchronize?"
  final bool createdOffline;          // true if created when device was offline
  final DateTime createdAt;            // local creation time
  final DateTime? firstSyncedAt;       // time when order was first successfully synced to Firestore
  final String? syncSource;            // 'offline-queue' or 'online-direct'
  final SyncStatus syncStatus;         // sync state: synced, pending, or failed

  Pedido({
    required this.id,
    required this.prescripcionId,
    required this.puntoFisicoId,
    required this.tipoEntrega,
    required this.direccionEntrega,
    required this.estado,
    required this.fechaPedido,
    this.fechaEntrega,
    this.cachedPharmacyName,
    this.cachedPharmacyAddress,
    this.createdOffline = false,
    DateTime? createdAt,
    this.firstSyncedAt,
    this.syncSource,
    this.syncStatus = SyncStatus.synced,
  }) : createdAt = createdAt ?? fechaPedido;

  // Getters for backward compatibility
  String get identificadorPedido => id;
  DateTime get fechaDespacho => fechaPedido; // Map fechaPedido to old fechaDespacho
  bool get entregado => estado == 'entregado';
  bool get entregaEnTienda => tipoEntrega == 'recogida';
  
  @Deprecated('Use id instead')
  String get usuarioId => ''; // This information is now in the document path

  // Create Pedido from Firestore document
  factory Pedido.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final fechaPedido = map['fechaPedido'] != null 
        ? (map['fechaPedido'] as Timestamp).toDate()
        : (map['fechaDespacho'] != null 
            ? (map['fechaDespacho'] as Timestamp).toDate() // backward compatibility
            : DateTime.now());
    
    return Pedido(
      id: documentId ?? map['id'] ?? '',
      prescripcionId: map['prescripcionId'] ?? '',
      puntoFisicoId: map['puntoFisicoId'] ?? '',
      tipoEntrega: map['tipoEntrega'] ?? 
                   (map['entregaEnTienda'] == true ? 'recogida' : 'domicilio'), // backward compatibility
      direccionEntrega: map['direccionEntrega'] ?? '',
      estado: map['estado'] ?? 
              (map['entregado'] == true ? 'entregado' : 'pendiente'), // backward compatibility
      fechaPedido: fechaPedido,
      fechaEntrega: map['fechaEntrega'] != null 
          ? (map['fechaEntrega'] as Timestamp).toDate()
          : null,
      // Load cached pharmacy data if available (for offline display)
      cachedPharmacyName: map['cachedPharmacyName'] as String?,
      cachedPharmacyAddress: map['cachedPharmacyAddress'] as String?,
      // Analytics fields with backward compatibility (default to false/null for old orders)
      createdOffline: map['createdOffline'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : fechaPedido, // fallback to fechaPedido for old orders
      firstSyncedAt: map['firstSyncedAt'] != null
          ? (map['firstSyncedAt'] as Timestamp).toDate()
          : null,
      syncSource: map['syncSource'] as String?,
      syncStatus: map['syncStatus'] != null
          ? SyncStatus.values.firstWhere(
              (e) => e.toString().split('.').last == map['syncStatus'],
              orElse: () => SyncStatus.synced,
            )
          : SyncStatus.synced, // default to synced for old orders
    );
  }

  // Convert Pedido to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'prescripcionId': prescripcionId,
      'puntoFisicoId': puntoFisicoId,
      'tipoEntrega': tipoEntrega,
      'direccionEntrega': direccionEntrega,
      'estado': estado,
      'fechaPedido': Timestamp.fromDate(fechaPedido),
      if (fechaEntrega != null) 'fechaEntrega': Timestamp.fromDate(fechaEntrega!),
      // Analytics fields for backend/BigQuery analytics
      'createdOffline': createdOffline,
      'createdAt': Timestamp.fromDate(createdAt),
      if (firstSyncedAt != null) 'firstSyncedAt': Timestamp.fromDate(firstSyncedAt!),
      if (syncSource != null) 'syncSource': syncSource,
      'syncStatus': syncStatus.toString().split('.').last,
    };
  }

  // Convert Pedido to JSON-serializable Map (for offline queue)
  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'prescripcionId': prescripcionId,
      'puntoFisicoId': puntoFisicoId,
      'tipoEntrega': tipoEntrega,
      'direccionEntrega': direccionEntrega,
      'estado': estado,
      'fechaPedido': fechaPedido.toIso8601String(),
      if (fechaEntrega != null) 'fechaEntrega': fechaEntrega!.toIso8601String(),
      // Include cached pharmacy data for offline display
      if (cachedPharmacyName != null) 'cachedPharmacyName': cachedPharmacyName,
      if (cachedPharmacyAddress != null) 'cachedPharmacyAddress': cachedPharmacyAddress,
      // Analytics fields
      'createdOffline': createdOffline,
      'createdAt': createdAt.toIso8601String(),
      if (firstSyncedAt != null) 'firstSyncedAt': firstSyncedAt!.toIso8601String(),
      if (syncSource != null) 'syncSource': syncSource,
      'syncStatus': syncStatus.toString().split('.').last,
    };
  }

  // Create from JSON-serializable map
  factory Pedido.fromJsonMap(Map<String, dynamic> map) {
    final fechaPedido = DateTime.parse(map['fechaPedido'] as String);
    
    return Pedido(
      id: map['id'] as String,
      prescripcionId: map['prescripcionId'] as String,
      puntoFisicoId: map['puntoFisicoId'] as String,
      tipoEntrega: map['tipoEntrega'] as String,
      direccionEntrega: map['direccionEntrega'] as String,
      estado: map['estado'] as String,
      fechaPedido: fechaPedido,
      fechaEntrega: map['fechaEntrega'] != null 
          ? DateTime.parse(map['fechaEntrega'] as String)
          : null,
      // Load cached pharmacy data
      cachedPharmacyName: map['cachedPharmacyName'] as String?,
      cachedPharmacyAddress: map['cachedPharmacyAddress'] as String?,
      // Analytics fields with backward compatibility
      createdOffline: map['createdOffline'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : fechaPedido,
      firstSyncedAt: map['firstSyncedAt'] != null
          ? DateTime.parse(map['firstSyncedAt'] as String)
          : null,
      syncSource: map['syncSource'] as String?,
      syncStatus: map['syncStatus'] != null
          ? SyncStatus.values.firstWhere(
              (e) => e.toString().split('.').last == map['syncStatus'],
              orElse: () => SyncStatus.synced,
            )
          : SyncStatus.synced,
    );
  }

  // Create from JSON string
  factory Pedido.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return Pedido.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  Pedido copyWith({
    String? id,
    String? prescripcionId,
    String? puntoFisicoId,
    String? tipoEntrega,
    String? direccionEntrega,
    String? estado,
    DateTime? fechaPedido,
    DateTime? fechaEntrega,
    String? cachedPharmacyName,
    String? cachedPharmacyAddress,
    bool? createdOffline,
    DateTime? createdAt,
    DateTime? firstSyncedAt,
    String? syncSource,
    SyncStatus? syncStatus,
  }) {
    return Pedido(
      id: id ?? this.id,
      prescripcionId: prescripcionId ?? this.prescripcionId,
      puntoFisicoId: puntoFisicoId ?? this.puntoFisicoId,
      tipoEntrega: tipoEntrega ?? this.tipoEntrega,
      direccionEntrega: direccionEntrega ?? this.direccionEntrega,
      estado: estado ?? this.estado,
      fechaPedido: fechaPedido ?? this.fechaPedido,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      cachedPharmacyName: cachedPharmacyName ?? this.cachedPharmacyName,
      cachedPharmacyAddress: cachedPharmacyAddress ?? this.cachedPharmacyAddress,
      createdOffline: createdOffline ?? this.createdOffline,
      createdAt: createdAt ?? this.createdAt,
      firstSyncedAt: firstSyncedAt ?? this.firstSyncedAt,
      syncSource: syncSource ?? this.syncSource,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  String toString() {
    return 'Pedido(id: $id, estado: $estado, tipoEntrega: $tipoEntrega)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pedido && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}