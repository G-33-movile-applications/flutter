import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/prescripcion.dart';
import '../repositories/prescripcion_repository.dart';
import '../models/medicamento.dart';

class PrescripcionService {
  final PrescripcionRepository _prescripcionRepository = PrescripcionRepository();
  final Uuid _uuid = Uuid();

  /// Procesa un JSON y guarda la prescripción en Firestore
  Future<void> procesarYGuardarJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Crear lista de medicamentos si viene en el JSON
      final List<Medicamento> medicamentos = (data['medicamentos'] as List<dynamic>?)
              ?.map((med) => Medicamento.fromMap(med))
              .toList() ??
          [];

      // Crear la prescripción a partir del JSON
      final prescripcion = Prescripcion(
        id: data['id'] ?? _uuid.v4(), // Si no trae id, generar uno
        fechaEmision: DateTime.tryParse(data['fechaEmision'] ?? '') ?? DateTime.now(),
        recetadoPor: data['recetadoPor'] ?? 'Desconocido',
        userId: data['userId'] ?? '',
        pedidoId: data['pedidoId'] ?? '',
        medicamentos: medicamentos,
      );

      // Guardar en Firestore
      await _prescripcionRepository.create(prescripcion);
      print("✅ Prescripción guardada con ID: ${prescripcion.id}");
    } catch (e) {
      print("❌ Error procesando JSON: $e");
      rethrow;
    }
  }
}
