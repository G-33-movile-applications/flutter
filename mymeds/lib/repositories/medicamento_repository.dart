import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicamento.dart';

class MedicamentoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'medicamentos';


  // Create a new medicamento - no longer requires foreign keys as they're managed via relationships
  Future<void> create(Medicamento medicamento) async {
    try {
      await _firestore.collection(_collection).doc(medicamento.id).set(medicamento.toMap());
    } catch (e) {
      throw Exception('Error creating medicamento: $e');
    }
  }

  // Read a medicamento by ID
  Future<Medicamento?> read(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return Medicamento.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading medicamento: $e');
    }
  }

  // Read all medicamentos
  Future<List<Medicamento>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .map((doc) => Medicamento.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error reading all medicamentos: $e');
    }
  }

  // Update a medicamento
  Future<void> update(Medicamento medicamento) async {
    try {
      await _firestore.collection(_collection).doc(medicamento.id).update(medicamento.toMap());
    } catch (e) {
      throw Exception('Error updating medicamento: $e');
    }
  }

  // Delete a medicamento
  Future<void> delete(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting medicamento: $e');
    }
  }

  // NOTE: Prescripcion-Medicamento relationship is now managed via List<Medicamento> in Prescripcion
  // Use PrescripcionRepository.getMedicamentosDePrescripcion() instead
  
  // NOTE: Medicamento-PuntoFisico relationship is now many-to-many via MedicamentoPuntoFisico
  // Use MedicamentoPuntoFisicoRepository for these relationships

  // Find medicamentos by restriction status
  Future<List<Medicamento>> findByEsRestringido(bool esRestringido) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('esRestringido', isEqualTo: esRestringido)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Medicamento.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding medicamentos by restriction status: $e');
    }
  }

  // UML generalization: Find by tipo (Pastilla, Unguento, Inyectable, Jarabe)
  Future<List<Medicamento>> findByTipo(String tipo) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('tipo', isEqualTo: tipo)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Medicamento.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding medicamentos by tipo: $e');
    }
  }

  // Helper method for getting distinct puntos by user (via prescripciones → medicamentos → MedicamentoPuntoFisico)
  // NOTE: This now requires using MedicamentoPuntoFisicoRepository
  @Deprecated('Use MedicamentoPuntoFisicoRepository and PrescripcionRepository to get this information')
  Future<List<String>> findDistinctPuntosByUserId(String userId) async {
    throw Exception('DEPRECATED: Use MedicamentoPuntoFisicoRepository.getPuntosFisicosForMedicamento() and PrescripcionRepository.findByUserId() to get this information');
  }

  // NOTE: Medicamentos are no longer deleted by prescripcionId
  // They are managed via the List<Medicamento> in Prescripcion
  @Deprecated('Medicamentos are now managed via List<Medicamento> in Prescripcion')
  Future<void> deleteByPrescripcionId(String prescripcionId) async {
    throw Exception('DEPRECATED: Medicamentos are now managed via List<Medicamento> in Prescripcion');
  }

  // Check if medicamento exists
  Future<bool> exists(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if medicamento exists: $e');
    }
  }

  // Stream of medicamento changes
  Stream<Medicamento?> streamMedicamento(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null 
            ? Medicamento.fromMap(doc.data()!) 
            : null);
  }

  // TODO: Migration helper - old many-to-many methods marked for removal
  @Deprecated('Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly')
  Future<void> addMedicamentoToPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    throw Exception('DEPRECATED: Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly');
  }

  @Deprecated('Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly')
  Future<void> removeMedicamentoFromPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    throw Exception('DEPRECATED: Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly');
  }

  @Deprecated('Use MedicamentoPuntoFisicoRepository for many-to-many relationships')
  Future<List<Medicamento>> findByPuntoFisico(String puntoFisicoId) async {
    throw Exception('DEPRECATED: Use MedicamentoPuntoFisicoRepository.findByPuntoFisicoId() and then fetch individual medicamentos');
  }
}