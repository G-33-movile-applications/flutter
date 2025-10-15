import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class PuntoFisico {
  final String id;
  final String nombre;
  final String direccion;
  final String? telefono;
  final GeoPoint ubicacion; // lat, lng as GeoPoint
  final String? horario;
  // Note: inventario is now stored as a subcollection, not embedded

  PuntoFisico({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.telefono,
    required this.ubicacion,
    this.horario,
  });

  // Getters for backward compatibility
  double get latitud => ubicacion.latitude;
  double get longitud => ubicacion.longitude;
  
  @Deprecated('Field removed from new model')
  String get cadena => '';
  
  @Deprecated('Use horario field instead')  
  List<String> get horarioAtencion => horario != null ? [horario!] : [];
  
  @Deprecated('Use horario field instead')
  List<String> get diasAtencion => [];

  // Create PuntoFisico from Firestore document
  factory PuntoFisico.fromMap(Map<String, dynamic> map, {String? documentId}) {
    // Handle different ways location can be stored
    GeoPoint ubicacion;
    if (map['ubicacion'] is GeoPoint) {
      ubicacion = map['ubicacion'] as GeoPoint;
    } else if (map['ubicacion'] is Map) {
      final ubicacionMap = map['ubicacion'] as Map<String, dynamic>;
      ubicacion = GeoPoint(
        (ubicacionMap['lat'] ?? ubicacionMap['latitude'] ?? 0.0).toDouble(),
        (ubicacionMap['lng'] ?? ubicacionMap['longitude'] ?? 0.0).toDouble(),
      );
    } else {
      // Backward compatibility with separate latitud/longitud fields
      ubicacion = GeoPoint(
        (map['latitud'] ?? 0.0).toDouble(),
        (map['longitud'] ?? 0.0).toDouble(),
      );
    }

    return PuntoFisico(
      id: documentId ?? map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      direccion: map['direccion'] ?? '',
      telefono: map['telefono'],
      ubicacion: ubicacion,
      horario: map['horario'] ?? 
               (map['horarioAtencion'] != null && map['diasAtencion'] != null
                   ? '${(map['diasAtencion'] as List).join(', ')}: ${(map['horarioAtencion'] as List).join(', ')}'
                   : null), // backward compatibility
    );
  }

  // Convert PuntoFisico to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      'ubicacion': ubicacion,
      if (horario != null) 'horario': horario,
    };
  }

  // Create from JSON string
  factory PuntoFisico.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PuntoFisico.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  PuntoFisico copyWith({
    String? id,
    String? nombre,
    String? direccion,
    String? telefono,
    GeoPoint? ubicacion,
    String? horario,
  }) {
    return PuntoFisico(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      ubicacion: ubicacion ?? this.ubicacion,
      horario: horario ?? this.horario,
    );
  }

  @override
  String toString() {
    return 'PuntoFisico(id: $id, nombre: $nombre, direccion: $direccion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuntoFisico && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}