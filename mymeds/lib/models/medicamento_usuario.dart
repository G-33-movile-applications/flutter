import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// User's personal medication tracking
/// Collection path: usuarios/{userId}/medicamentosUsuario/{medicamentoId}
class MedicamentoUsuario {
  final String id; // medicamentoId from global catalog
  final String medicamentoRef; // "/medicamentosGlobales/{medicamentoId}"
  final String nombre; // denormalized for quick access
  final double dosisMg;
  final int frecuenciaHoras;
  final bool activo;
  final String prescripcionId;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const MedicamentoUsuario({
    required this.id,
    required this.medicamentoRef,
    required this.nombre,
    required this.dosisMg,
    required this.frecuenciaHoras,
    required this.activo,
    required this.prescripcionId,
    required this.fechaInicio,
    required this.fechaFin,
  });

  // Create MedicamentoUsuario from Firestore document
  factory MedicamentoUsuario.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return MedicamentoUsuario(
      id: documentId ?? map['id'] ?? '',
      medicamentoRef: map['medicamentoRef'] ?? '',
      nombre: map['nombre'] ?? '',
      dosisMg: (map['dosisMg'] ?? 0.0).toDouble(),
      frecuenciaHoras: map['frecuenciaHoras'] ?? 0,
      activo: map['activo'] ?? true,
      prescripcionId: map['prescripcionId'] ?? '',
      fechaInicio: map['fechaInicio'] != null 
          ? (map['fechaInicio'] as Timestamp).toDate() 
          : DateTime.now(),
      fechaFin: map['fechaFin'] != null 
          ? (map['fechaFin'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convert MedicamentoUsuario to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'medicamentoRef': medicamentoRef,
      'nombre': nombre,
      'dosisMg': dosisMg,
      'frecuenciaHoras': frecuenciaHoras,
      'activo': activo,
      'prescripcionId': prescripcionId,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
    };
  }

  // Create from JSON string
  factory MedicamentoUsuario.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MedicamentoUsuario.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  MedicamentoUsuario copyWith({
    String? id,
    String? medicamentoRef,
    String? nombre,
    double? dosisMg,
    int? frecuenciaHoras,
    bool? activo,
    String? prescripcionId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) {
    return MedicamentoUsuario(
      id: id ?? this.id,
      medicamentoRef: medicamentoRef ?? this.medicamentoRef,
      nombre: nombre ?? this.nombre,
      dosisMg: dosisMg ?? this.dosisMg,
      frecuenciaHoras: frecuenciaHoras ?? this.frecuenciaHoras,
      activo: activo ?? this.activo,
      prescripcionId: prescripcionId ?? this.prescripcionId,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
    );
  }

  @override
  String toString() {
    return 'MedicamentoUsuario(id: $id, nombre: $nombre, activo: $activo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicamentoUsuario && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}