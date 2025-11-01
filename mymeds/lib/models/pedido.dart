import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

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

  Pedido({
    required this.id,
    required this.prescripcionId,
    required this.puntoFisicoId,
    required this.tipoEntrega,
    required this.direccionEntrega,
    required this.estado,
    required this.fechaPedido,
    this.fechaEntrega,
  });

  // Getters for backward compatibility
  String get identificadorPedido => id;
  DateTime get fechaDespacho => fechaPedido; // Map fechaPedido to old fechaDespacho
  bool get entregado => estado == 'entregado';
  bool get entregaEnTienda => tipoEntrega == 'recogida';
  
  @Deprecated('Use id instead')
  String get usuarioId => ''; // This information is now in the document path

  // Create Pedido from Firestore document
  factory Pedido.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Pedido(
      id: documentId ?? map['id'] ?? '',
      prescripcionId: map['prescripcionId'] ?? '',
      puntoFisicoId: map['puntoFisicoId'] ?? '',
      tipoEntrega: map['tipoEntrega'] ?? 
                   (map['entregaEnTienda'] == true ? 'recogida' : 'domicilio'), // backward compatibility
      direccionEntrega: map['direccionEntrega'] ?? '',
      estado: map['estado'] ?? 
              (map['entregado'] == true ? 'entregado' : 'pendiente'), // backward compatibility
      fechaPedido: map['fechaPedido'] != null 
          ? (map['fechaPedido'] as Timestamp).toDate()
          : (map['fechaDespacho'] != null 
              ? (map['fechaDespacho'] as Timestamp).toDate() // backward compatibility
              : DateTime.now()),
      fechaEntrega: map['fechaEntrega'] != null 
          ? (map['fechaEntrega'] as Timestamp).toDate()
          : null,
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
    };
  }

  // Create from JSON-serializable map
  factory Pedido.fromJsonMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] as String,
      prescripcionId: map['prescripcionId'] as String,
      puntoFisicoId: map['puntoFisicoId'] as String,
      tipoEntrega: map['tipoEntrega'] as String,
      direccionEntrega: map['direccionEntrega'] as String,
      estado: map['estado'] as String,
      fechaPedido: DateTime.parse(map['fechaPedido'] as String),
      fechaEntrega: map['fechaEntrega'] != null 
          ? DateTime.parse(map['fechaEntrega'] as String)
          : null,
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