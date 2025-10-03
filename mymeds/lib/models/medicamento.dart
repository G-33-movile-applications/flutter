abstract class Medicamento {
  final String id;
  final String nombre;
  final String descripcion;
  final bool esRestringido;

  Medicamento({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.esRestringido,
  });

  // Abstract method to convert to Map - each subclass will implement
  Map<String, dynamic> toMap();

  // Factory method to create appropriate subclass from Firestore data
  static Medicamento fromMap(Map<String, dynamic> map) {
    final tipo = map['tipo'] as String;
    
    switch (tipo) {
      case 'pastilla':
        return Pastilla.fromMap(map);
      case 'unguento':
        return Unguento.fromMap(map);
      case 'inyectable':
        return Inyectable.fromMap(map);
      case 'jarabe':
        return Jarabe.fromMap(map);
      default:
        throw Exception('Tipo de medicamento desconocido: $tipo');
    }
  }

  @override
  String toString() {
    return 'Medicamento(id: $id, nombre: $nombre)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Medicamento && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Pastilla specialization
class Pastilla extends Medicamento {
  final double dosisMg;
  final int cantidad;

  Pastilla({
    required super.id,
    required super.nombre,
    required super.descripcion,
    required super.esRestringido,
    required this.dosisMg,
    required this.cantidad,
  });

  factory Pastilla.fromMap(Map<String, dynamic> map) {
    return Pastilla(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      dosisMg: (map['dosisMg'] ?? 0.0).toDouble(),
      cantidad: map['cantidad'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'tipo': 'pastilla',
      'dosisMg': dosisMg,
      'cantidad': cantidad,
    };
  }
}

// Unguento specialization
class Unguento extends Medicamento {
  final String concentracion;
  final int cantidadEnvases;

  Unguento({
    required super.id,
    required super.nombre,
    required super.descripcion,
    required super.esRestringido,
    required this.concentracion,
    required this.cantidadEnvases,
  });

  factory Unguento.fromMap(Map<String, dynamic> map) {
    return Unguento(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      concentracion: map['concentracion'] ?? '',
      cantidadEnvases: map['cantidadEnvases'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'tipo': 'unguento',
      'concentracion': concentracion,
      'cantidadEnvases': cantidadEnvases,
    };
  }
}

// Inyectable specialization
class Inyectable extends Medicamento {
  final String concentracion;
  final double volumenPorUnidad;
  final int cantidadUnidades;

  Inyectable({
    required super.id,
    required super.nombre,
    required super.descripcion,
    required super.esRestringido,
    required this.concentracion,
    required this.volumenPorUnidad,
    required this.cantidadUnidades,
  });

  factory Inyectable.fromMap(Map<String, dynamic> map) {
    return Inyectable(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      concentracion: map['concentracion'] ?? '',
      volumenPorUnidad: (map['volumenPorUnidad'] ?? 0.0).toDouble(),
      cantidadUnidades: map['cantidadUnidades'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'tipo': 'inyectable',
      'concentracion': concentracion,
      'volumenPorUnidad': volumenPorUnidad,
      'cantidadUnidades': cantidadUnidades,
    };
  }
}

// Jarabe specialization
class Jarabe extends Medicamento {
  final int cantidadBotellas;
  final double mlPorBotella;

  Jarabe({
    required super.id,
    required super.nombre,
    required super.descripcion,
    required super.esRestringido,
    required this.cantidadBotellas,
    required this.mlPorBotella,
  });

  factory Jarabe.fromMap(Map<String, dynamic> map) {
    return Jarabe(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      cantidadBotellas: map['cantidadBotellas'] ?? 0,
      mlPorBotella: (map['mlPorBotella'] ?? 0.0).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'tipo': 'jarabe',
      'cantidadBotellas': cantidadBotellas,
      'mlPorBotella': mlPorBotella,
    };
  }
}