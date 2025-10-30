import 'prescripcion.dart';
import 'medicamento_prescripcion.dart';

/// Helper class that combines a Prescripcion with its medications
/// loaded from the Firestore subcollection.
/// 
/// This makes it easier to display prescription data in the UI
/// without having to manually load medications every time.
class PrescripcionWithMedications {
  final Prescripcion prescripcion;
  final List<MedicamentoPrescripcion> medicamentos;

  const PrescripcionWithMedications({
    required this.prescripcion,
    required this.medicamentos,
  });

  /// Quick access to prescription fields
  String get id => prescripcion.id;
  DateTime get fechaCreacion => prescripcion.fechaCreacion;
  String get diagnostico => prescripcion.diagnostico;
  String get medico => prescripcion.medico;
  bool get activa => prescripcion.activa;
  
  /// Check if prescription has medications
  bool get hasMedications => medicamentos.isNotEmpty;
  
  /// Get count of medications
  int get medicationCount => medicamentos.length;
  
  /// Get active medications only
  List<MedicamentoPrescripcion> get activeMedications => 
      medicamentos.where((m) => m.activo).toList();
  
  /// Create a copy with updated fields
  PrescripcionWithMedications copyWith({
    Prescripcion? prescripcion,
    List<MedicamentoPrescripcion>? medicamentos,
  }) {
    return PrescripcionWithMedications(
      prescripcion: prescripcion ?? this.prescripcion,
      medicamentos: medicamentos ?? this.medicamentos,
    );
  }

  @override
  String toString() {
    return 'PrescripcionWithMedications(id: $id, medico: $medico, medications: ${medicamentos.length})';
  }
}
