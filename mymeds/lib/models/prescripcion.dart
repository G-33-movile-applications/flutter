import 'package:cloud_firestore/cloud_firestore.dart';
import 'medicamento.dart';

class Prescripcion {
  final String id;
  final DateTime fechaEmision;
  final String recetadoPor;
  final String pedidoId; // Foreign key to Pedido
  final List<Medicamento> medicamentos; // Related medications

  Prescripcion({
    required this.id,
    required this.fechaEmision,
    required this.recetadoPor,
    required this.pedidoId,
    this.medicamentos = const [],
  });

  // Create Prescripcion from Firestore document
  factory Prescripcion.fromMap(Map<String, dynamic> map, {List<Medicamento>? medicamentos}) {
    return Prescripcion(
      id: map['id'] ?? '',
      fechaEmision: (map['fechaEmision'] as Timestamp).toDate(),
      recetadoPor: map['recetadoPor'] ?? '',
      pedidoId: map['pedidoId'] ?? '',
      medicamentos: medicamentos ?? [],
    );
  }

  // Convert Prescripcion to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fechaEmision': Timestamp.fromDate(fechaEmision),
      'recetadoPor': recetadoPor,
      'pedidoId': pedidoId,
    };
  }

  // Create a copy with some fields updated
  Prescripcion copyWith({
    String? id,
    DateTime? fechaEmision,
    String? recetadoPor,
    String? pedidoId,
    List<Medicamento>? medicamentos,
  }) {
    return Prescripcion(
      id: id ?? this.id,
      fechaEmision: fechaEmision ?? this.fechaEmision,
      recetadoPor: recetadoPor ?? this.recetadoPor,
      pedidoId: pedidoId ?? this.pedidoId,
      medicamentos: medicamentos ?? this.medicamentos,
    );
  }

  @override
  String toString() {
    return 'Prescripcion(id: $id, recetadoPor: $recetadoPor)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Prescripcion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}