import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// Medication in a prescription with specific dosage and timing
/// Collection path: usuarios/{userId}/prescripciones/{prescripcionId}/medicamentos/{medicamentoId}
class MedicamentoPrescripcion {
  final String id; // medicamentoId from global catalog
  final String medicamentoRef; // "/medicamentosGlobales/{medicamentoId}"
  final String nombre; // denormalized for quick access
  final double dosisMg;
  final int frecuenciaHoras;
  final int duracionDias;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? observaciones;
  final bool activo;
  // Denormalized fields for collectionGroup queries
  final String userId;
  final String prescripcionId;

  const MedicamentoPrescripcion({
    required this.id,
    required this.medicamentoRef,
    required this.nombre,
    required this.dosisMg,
    required this.frecuenciaHoras,
    required this.duracionDias,
    required this.fechaInicio,
    required this.fechaFin,
    this.observaciones,
    required this.activo,
    required this.userId,
    required this.prescripcionId,
  });

  // Create MedicamentoPrescripcion from Firestore document
  factory MedicamentoPrescripcion.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return MedicamentoPrescripcion(
      id: documentId ?? map['id'] ?? '',
      medicamentoRef: map['medicamentoRef'] ?? '',
      nombre: map['nombre'] ?? '',
      dosisMg: (map['dosisMg'] ?? 0.0).toDouble(),
      frecuenciaHoras: map['frecuenciaHoras'] ?? 0,
      duracionDias: map['duracionDias'] ?? 0,
      fechaInicio: map['fechaInicio'] != null 
          ? (map['fechaInicio'] as Timestamp).toDate() 
          : DateTime.now(),
      fechaFin: map['fechaFin'] != null 
          ? (map['fechaFin'] as Timestamp).toDate() 
          : DateTime.now(),
      observaciones: map['observaciones'],
      activo: map['activo'] ?? true,
      userId: map['userId'] ?? '',
      prescripcionId: map['prescripcionId'] ?? '',
    );
  }

  // Convert MedicamentoPrescripcion to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'medicamentoRef': medicamentoRef,
      'nombre': nombre,
      'dosisMg': dosisMg,
      'frecuenciaHoras': frecuenciaHoras,
      'duracionDias': duracionDias,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
      if (observaciones != null) 'observaciones': observaciones,
      'activo': activo,
      'userId': userId,
      'prescripcionId': prescripcionId,
    };
  }

  // Create from JSON string
  factory MedicamentoPrescripcion.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MedicamentoPrescripcion.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  MedicamentoPrescripcion copyWith({
    String? id,
    String? medicamentoRef,
    String? nombre,
    double? dosisMg,
    int? frecuenciaHoras,
    int? duracionDias,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? observaciones,
    bool? activo,
    String? userId,
    String? prescripcionId,
  }) {
    return MedicamentoPrescripcion(
      id: id ?? this.id,
      medicamentoRef: medicamentoRef ?? this.medicamentoRef,
      nombre: nombre ?? this.nombre,
      dosisMg: dosisMg ?? this.dosisMg,
      frecuenciaHoras: frecuenciaHoras ?? this.frecuenciaHoras,
      duracionDias: duracionDias ?? this.duracionDias,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      observaciones: observaciones ?? this.observaciones,
      activo: activo ?? this.activo,
      userId: userId ?? this.userId,
      prescripcionId: prescripcionId ?? this.prescripcionId,
    );
  }

  @override
  String toString() {
    return 'MedicamentoPrescripcion(id: $id, nombre: $nombre, activo: $activo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicamentoPrescripcion && other.id == id && other.prescripcionId == prescripcionId;
  }

  @override
  int get hashCode => Object.hash(id, prescripcionId);
}