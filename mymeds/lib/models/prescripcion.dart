import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class Prescripcion {
  final String id;
  final DateTime fechaCreacion;
  final String diagnostico;
  final String medico;
  final bool activa;
  // Note: medicamentos are now stored as a subcollection, not embedded

  Prescripcion({
    required this.id,
    required this.fechaCreacion,
    required this.diagnostico,
    required this.medico,
    required this.activa,
  });

  // Getters for backward compatibility  
  DateTime get fechaEmision => fechaCreacion;
  String get recetadoPor => medico;
  
  @Deprecated('Medicamentos are now in subcollection')
  List<dynamic> get medicamentos => const []; // Empty list for backward compatibility
  
  @Deprecated('Use document path instead')
  String get userId => ''; // This information is now in the document path
  
  @Deprecated('Use document path instead')  
  String get pedidoId => ''; // This information is now in the document path

  // Create Prescripcion from Firestore document
  factory Prescripcion.fromMap(Map<String, dynamic> map, {String? documentId}) {
    // Use documentId first (from Firestore document), then map['id'], then generate a fallback
    String finalId = documentId?.isNotEmpty == true 
        ? documentId! 
        : (map['id']?.toString().isNotEmpty == true 
            ? map['id'].toString() 
            : 'prescripcion_${DateTime.now().millisecondsSinceEpoch}');
    
    return Prescripcion(
      id: finalId,
      fechaCreacion: map['fechaCreacion'] != null 
          ? (map['fechaCreacion'] as Timestamp).toDate()
          : (map['fechaEmision'] != null 
              ? (map['fechaEmision'] as Timestamp).toDate() // backward compatibility
              : DateTime.now()),
      diagnostico: map['diagnostico'] ?? '',
      medico: map['medico'] ?? map['recetadoPor'] ?? '', // Support both new and old field names
      activa: map['activa'] ?? true,
    );
  }

  // Convert Prescripcion to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Include ID in the document data for consistency
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'diagnostico': diagnostico,
      'medico': medico,
      'activa': activa,
    };
  }

  // Create from JSON string
  factory Prescripcion.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return Prescripcion.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  Prescripcion copyWith({
    String? id,
    DateTime? fechaCreacion,
    String? diagnostico,
    String? medico,
    bool? activa,
  }) {
    return Prescripcion(
      id: id ?? this.id,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      diagnostico: diagnostico ?? this.diagnostico,
      medico: medico ?? this.medico,
      activa: activa ?? this.activa,
    );
  }

  @override
  String toString() {
    return 'Prescripcion(id: $id, medico: $medico, activa: $activa)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Prescripcion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}