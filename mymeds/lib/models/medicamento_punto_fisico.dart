import 'package:cloud_firestore/cloud_firestore.dart';

class MedicamentoPuntoFisico {
  final String id;
  final String medicamentoId; // Foreign key to Medicamento
  final String puntoFisicoId; // Foreign key to PuntoFisico
  final int cantidad; // Stock quantity available at this location
  final DateTime fechaActualizacion; // Last updated timestamp

  MedicamentoPuntoFisico({
    required this.id,
    required this.medicamentoId,
    required this.puntoFisicoId,
    required this.cantidad,
    required this.fechaActualizacion,
  });

  // Create MedicamentoPuntoFisico from Firestore document
  factory MedicamentoPuntoFisico.fromMap(Map<String, dynamic> map) {
    return MedicamentoPuntoFisico(
      id: map['id'] ?? '',
      medicamentoId: map['medicamentoId'] ?? '',
      puntoFisicoId: map['puntoFisicoId'] ?? '',
      cantidad: map['cantidad'] ?? 0,
      fechaActualizacion: map['fechaActualizacion'] != null 
          ? (map['fechaActualizacion'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convert MedicamentoPuntoFisico to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicamentoId': medicamentoId,
      'puntoFisicoId': puntoFisicoId,
      'cantidad': cantidad,
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
    };
  }

  // Create a copy with some fields updated
  MedicamentoPuntoFisico copyWith({
    String? id,
    String? medicamentoId,
    String? puntoFisicoId,
    int? cantidad,
    DateTime? fechaActualizacion,
  }) {
    return MedicamentoPuntoFisico(
      id: id ?? this.id,
      medicamentoId: medicamentoId ?? this.medicamentoId,
      puntoFisicoId: puntoFisicoId ?? this.puntoFisicoId,
      cantidad: cantidad ?? this.cantidad,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  String toString() {
    return 'MedicamentoPuntoFisico(id: $id, medicamentoId: $medicamentoId, puntoFisicoId: $puntoFisicoId, cantidad: $cantidad)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicamentoPuntoFisico && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}