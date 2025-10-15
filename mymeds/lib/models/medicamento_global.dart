import 'dart:convert';

/// Global medication catalog model
/// This represents medications in the global catalog (medicamentosGlobales collection)
class MedicamentoGlobal {
  final String id;
  final String nombre;
  final String principioActivo;
  final String presentacion;
  final String laboratorio;
  final String descripcion;
  final List<String> contraindicaciones;
  final String? imagenUrl;

  const MedicamentoGlobal({
    required this.id,
    required this.nombre,
    required this.principioActivo,
    required this.presentacion,
    required this.laboratorio,
    required this.descripcion,
    this.contraindicaciones = const [],
    this.imagenUrl,
  });

  // Create MedicamentoGlobal from Firestore document
  factory MedicamentoGlobal.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return MedicamentoGlobal(
      id: documentId ?? map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      principioActivo: map['principioActivo'] ?? '',
      presentacion: map['presentacion'] ?? '',
      laboratorio: map['laboratorio'] ?? '',
      descripcion: map['descripcion'] ?? '',
      contraindicaciones: List<String>.from(map['contraindicaciones'] ?? []),
      imagenUrl: map['imagenUrl'],
    );
  }

  // Convert MedicamentoGlobal to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'principioActivo': principioActivo,
      'presentacion': presentacion,
      'laboratorio': laboratorio,
      'descripcion': descripcion,
      'contraindicaciones': contraindicaciones,
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
    };
  }

  // Create from JSON string
  factory MedicamentoGlobal.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MedicamentoGlobal.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  MedicamentoGlobal copyWith({
    String? id,
    String? nombre,
    String? principioActivo,
    String? presentacion,
    String? laboratorio,
    String? descripcion,
    List<String>? contraindicaciones,
    String? imagenUrl,
  }) {
    return MedicamentoGlobal(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      principioActivo: principioActivo ?? this.principioActivo,
      presentacion: presentacion ?? this.presentacion,
      laboratorio: laboratorio ?? this.laboratorio,
      descripcion: descripcion ?? this.descripcion,
      contraindicaciones: contraindicaciones ?? this.contraindicaciones,
      imagenUrl: imagenUrl ?? this.imagenUrl,
    );
  }

  @override
  String toString() {
    return 'MedicamentoGlobal(id: $id, nombre: $nombre, laboratorio: $laboratorio)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicamentoGlobal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}