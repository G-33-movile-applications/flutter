class PuntoFisico {
  final String id;
  final double latitud;
  final double longitud;
  final String direccion;
  final String cadena;
  final String nombre;

  PuntoFisico({
    required this.id,
    required this.latitud,
    required this.longitud,
    required this.direccion,
    required this.cadena,
    required this.nombre,
  });

  // Create PuntoFisico from Firestore document
  factory PuntoFisico.fromMap(Map<String, dynamic> map) {
    return PuntoFisico(
      id: map['id'] ?? '',
      latitud: (map['latitud'] ?? 0.0).toDouble(),
      longitud: (map['longitud'] ?? 0.0).toDouble(),
      direccion: map['direccion'] ?? '',
      cadena: map['cadena'] ?? '',
      nombre: map['nombre'] ?? '',
    );
  }

  // Convert PuntoFisico to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitud': latitud,
      'longitud': longitud,
      'direccion': direccion,
      'cadena': cadena,
      'nombre': nombre,
    };
  }

  // Create a copy with some fields updated
  PuntoFisico copyWith({
    String? id,
    double? latitud,
    double? longitud,
    String? direccion,
    String? cadena,
    String? nombre,
  }) {
    return PuntoFisico(
      id: id ?? this.id,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      direccion: direccion ?? this.direccion,
      cadena: cadena ?? this.cadena,
      nombre: nombre ?? this.nombre,
    );
  }

  @override
  String toString() {
    return 'PuntoFisico(id: $id, nombre: $nombre, cadena: $cadena)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuntoFisico && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}