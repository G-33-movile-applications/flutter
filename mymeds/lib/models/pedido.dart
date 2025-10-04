import 'package:cloud_firestore/cloud_firestore.dart';
import 'prescripcion.dart';

class Pedido {
  final String identificadorPedido;
  final DateTime fechaEntrega;
  final DateTime fechaDespacho;
  final String direccionEntrega;
  final bool entregado;
  final bool entregaEnTienda; // New field - pickup in store
  final String usuarioId; // Foreign key to Usuario
  final String puntoFisicoId; // Foreign key to PuntoFisico - new many-to-one relationship
  final String prescripcionId; // Foreign key to Prescripcion
  final Prescripcion? prescripcion; // Related prescription (for in-memory use)

  Pedido({
    required this.identificadorPedido,
    required this.fechaEntrega,
    required this.fechaDespacho,
    required this.direccionEntrega,
    required this.entregado,
    required this.entregaEnTienda,
    required this.usuarioId,
    required this.puntoFisicoId,
    required this.prescripcionId,
    this.prescripcion,
  });

  // Create Pedido from Firestore document
  factory Pedido.fromMap(Map<String, dynamic> map, {Prescripcion? prescripcion}) {
    return Pedido(
      identificadorPedido: map['identificadorPedido'] ?? '',
      fechaEntrega: (map['fechaEntrega'] as Timestamp).toDate(),
      fechaDespacho: (map['fechaDespacho'] as Timestamp).toDate(),
      direccionEntrega: map['direccionEntrega'] ?? '',
      entregado: map['entregado'] ?? false,
      entregaEnTienda: map['entregaEnTienda'] ?? false,
      usuarioId: map['usuarioId'] ?? '',
      puntoFisicoId: map['puntoFisicoId'] ?? '',
      prescripcionId: map['prescripcionId'] ?? '',
      prescripcion: prescripcion,
    );
  }

  // Convert Pedido to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'identificadorPedido': identificadorPedido,
      'fechaEntrega': Timestamp.fromDate(fechaEntrega),
      'fechaDespacho': Timestamp.fromDate(fechaDespacho),
      'direccionEntrega': direccionEntrega,
      'entregado': entregado,
      'entregaEnTienda': entregaEnTienda,
      'usuarioId': usuarioId,
      'puntoFisicoId': puntoFisicoId,
      'prescripcionId': prescripcionId,
    };
  }

  // Create a copy with some fields updated
  Pedido copyWith({
    String? identificadorPedido,
    DateTime? fechaEntrega,
    DateTime? fechaDespacho,
    String? direccionEntrega,
    bool? entregado,
    bool? entregaEnTienda,
    String? usuarioId,
    String? puntoFisicoId,
    String? prescripcionId,
    Prescripcion? prescripcion,
  }) {
    return Pedido(
      identificadorPedido: identificadorPedido ?? this.identificadorPedido,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      fechaDespacho: fechaDespacho ?? this.fechaDespacho,
      direccionEntrega: direccionEntrega ?? this.direccionEntrega,
      entregado: entregado ?? this.entregado,
      entregaEnTienda: entregaEnTienda ?? this.entregaEnTienda,
      usuarioId: usuarioId ?? this.usuarioId,
      puntoFisicoId: puntoFisicoId ?? this.puntoFisicoId,
      prescripcionId: prescripcionId ?? this.prescripcionId,
      prescripcion: prescripcion ?? this.prescripcion,
    );
  }

  @override
  String toString() {
    return 'Pedido(identificadorPedido: $identificadorPedido, entregado: $entregado)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pedido && other.identificadorPedido == identificadorPedido;
  }

  @override
  int get hashCode => identificadorPedido.hashCode;
}