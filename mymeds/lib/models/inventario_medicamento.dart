import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// Medication inventory at a physical point (pharmacy)
/// Collection path: puntosFisicos/{puntoFisicoId}/inventario/{medicamentoId}
class InventarioMedicamento {
  final String id; // medicamentoId from global catalog
  final String medicamentoRef; // "/medicamentosGlobales/{medicamentoId}"
  final String nombre; // denormalized for quick access
  final int stock;
  final int precioUnidad; // in cents
  final String? lote;
  final DateTime? fechaVencimiento;
  final String? proveedor;
  final DateTime fechaIngreso;

  const InventarioMedicamento({
    required this.id,
    required this.medicamentoRef,
    required this.nombre,
    required this.stock,
    required this.precioUnidad,
    this.lote,
    this.fechaVencimiento,
    this.proveedor,
    required this.fechaIngreso,
  });

  // Create InventarioMedicamento from Firestore document
  factory InventarioMedicamento.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return InventarioMedicamento(
      id: documentId ?? map['id'] ?? '',
      medicamentoRef: map['medicamentoRef'] ?? '',
      nombre: map['nombre'] ?? '',
      stock: map['stock'] ?? 0,
      precioUnidad: map['precioUnidad'] ?? 0,
      lote: map['lote'],
      fechaVencimiento: map['fechaVencimiento'] != null 
          ? (map['fechaVencimiento'] as Timestamp).toDate() 
          : null,
      proveedor: map['proveedor'],
      fechaIngreso: map['fechaIngreso'] != null 
          ? (map['fechaIngreso'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convert InventarioMedicamento to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'medicamentoRef': medicamentoRef,
      'nombre': nombre,
      'stock': stock,
      'precioUnidad': precioUnidad,
      if (lote != null) 'lote': lote,
      if (fechaVencimiento != null) 'fechaVencimiento': Timestamp.fromDate(fechaVencimiento!),
      if (proveedor != null) 'proveedor': proveedor,
      'fechaIngreso': Timestamp.fromDate(fechaIngreso),
    };
  }

  // Create from JSON string
  factory InventarioMedicamento.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return InventarioMedicamento.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  InventarioMedicamento copyWith({
    String? id,
    String? medicamentoRef,
    String? nombre,
    int? stock,
    int? precioUnidad,
    String? lote,
    DateTime? fechaVencimiento,
    String? proveedor,
    DateTime? fechaIngreso,
  }) {
    return InventarioMedicamento(
      id: id ?? this.id,
      medicamentoRef: medicamentoRef ?? this.medicamentoRef,
      nombre: nombre ?? this.nombre,
      stock: stock ?? this.stock,
      precioUnidad: precioUnidad ?? this.precioUnidad,
      lote: lote ?? this.lote,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      proveedor: proveedor ?? this.proveedor,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
    );
  }

  @override
  String toString() {
    return 'InventarioMedicamento(id: $id, nombre: $nombre, stock: $stock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventarioMedicamento && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}