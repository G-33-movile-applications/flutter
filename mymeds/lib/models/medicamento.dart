import 'punto_fisico.dart';

abstract class Medicamento {
  final String id;
  final String nombre;
  final String descripcion;
  final bool esRestringido;
  final String prescripcionId; // Foreign key to Prescripcion
  final List<PuntoFisico> puntosDisponibles; // Many-to-many relationship

  Medicamento({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.esRestringido,
    required this.prescripcionId,
    this.puntosDisponibles = const [],
  });

  // Abstract method to convert to Map - each subclass will implement
  Map<String, dynamic> toMap();

  // Factory method to create appropriate subclass from Firestore data
  static Medicamento fromMap(Map<String, dynamic> map, {List<PuntoFisico>? puntosDisponibles}) {
    final tipo = map['tipo'] as String;
    
    switch (tipo) {
      case 'pastilla':
        return Pastilla.fromMap(map, puntosDisponibles: puntosDisponibles);
      case 'unguento':
        return Unguento.fromMap(map, puntosDisponibles: puntosDisponibles);
      case 'inyectable':
        return Inyectable.fromMap(map, puntosDisponibles: puntosDisponibles);
      case 'jarabe':
        return Jarabe.fromMap(map, puntosDisponibles: puntosDisponibles);
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
    required super.prescripcionId,
    required this.dosisMg,
    required this.cantidad,
    super.puntosDisponibles = const [],
  });

  factory Pastilla.fromMap(Map<String, dynamic> map, {List<PuntoFisico>? puntosDisponibles}) {
    return Pastilla(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      prescripcionId: map['prescripcionId'] ?? '',
      dosisMg: (map['dosisMg'] ?? 0.0).toDouble(),
      cantidad: map['cantidad'] ?? 0,
      puntosDisponibles: puntosDisponibles ?? [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'prescripcionId': prescripcionId,
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
    required super.prescripcionId,
    required this.concentracion,
    required this.cantidadEnvases,
    super.puntosDisponibles = const [],
  });

  factory Unguento.fromMap(Map<String, dynamic> map, {List<PuntoFisico>? puntosDisponibles}) {
    return Unguento(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      prescripcionId: map['prescripcionId'] ?? '',
      concentracion: map['concentracion'] ?? '',
      cantidadEnvases: map['cantidadEnvases'] ?? 0,
      puntosDisponibles: puntosDisponibles ?? [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'prescripcionId': prescripcionId,
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
    required super.prescripcionId,
    required this.concentracion,
    required this.volumenPorUnidad,
    required this.cantidadUnidades,
    super.puntosDisponibles = const [],
  });

  factory Inyectable.fromMap(Map<String, dynamic> map, {List<PuntoFisico>? puntosDisponibles}) {
    return Inyectable(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      prescripcionId: map['prescripcionId'] ?? '',
      concentracion: map['concentracion'] ?? '',
      volumenPorUnidad: (map['volumenPorUnidad'] ?? 0.0).toDouble(),
      cantidadUnidades: map['cantidadUnidades'] ?? 0,
      puntosDisponibles: puntosDisponibles ?? [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'prescripcionId': prescripcionId,
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
    required super.prescripcionId,
    required this.cantidadBotellas,
    required this.mlPorBotella,
    super.puntosDisponibles = const [],
  });

  factory Jarabe.fromMap(Map<String, dynamic> map, {List<PuntoFisico>? puntosDisponibles}) {
    return Jarabe(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      esRestringido: map['esRestringido'] ?? false,
      prescripcionId: map['prescripcionId'] ?? '',
      cantidadBotellas: map['cantidadBotellas'] ?? 0,
      mlPorBotella: (map['mlPorBotella'] ?? 0.0).toDouble(),
      puntosDisponibles: puntosDisponibles ?? [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'esRestringido': esRestringido,
      'prescripcionId': prescripcionId,
      'tipo': 'jarabe',
      'cantidadBotellas': cantidadBotellas,
      'mlPorBotella': mlPorBotella,
    };
  }
}