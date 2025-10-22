import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/prescripcion.dart';
import '../repositories/prescripcion_repository.dart';

class PrescripcionService {
  final PrescripcionRepository _prescripcionRepository = PrescripcionRepository();
  final Uuid _uuid = Uuid();

  /// Verifica si el usuario tiene prescripciones activas
  Future<bool> tieneRecetasActivas() async {
    try {
      final prescripciones = await _prescripcionRepository.readAll();
      return prescripciones.any((p) => p.activa);
    } catch (e) {
      return false;
    }
  }

  /// Procesa un JSON y guarda la prescripción en Firestore
  Future<void> procesarYGuardarJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Note: Medicamentos are now stored in subcollections, not processed here

      // Crear la prescripción a partir del JSON
      final prescripcion = Prescripcion(
        id: data['id'] ?? _uuid.v4(), // Si no trae id, generar uno
        fechaCreacion: DateTime.tryParse(data['fechaEmision'] ?? data['fechaCreacion'] ?? '') ?? DateTime.now(),
        medico: data['recetadoPor'] ?? data['medico'] ?? 'Desconocido',
        diagnostico: data['diagnostico'] ?? 'Sin diagnóstico especificado',
        activa: data['activa'] ?? true,
        // Note: medicamentos are now stored in subcollections, not embedded
      );

      // Guardar en Firestore
      await _prescripcionRepository.create(prescripcion);
      
      } catch (e) {
      
      rethrow;
    }
  }
}
