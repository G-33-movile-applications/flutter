import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicamento_global.dart';

class MedicamentoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'medicamentosGlobales';


  // Create a new medicamento - no longer requires foreign keys as they're managed via relationships
  Future<void> create(MedicamentoGlobal medicamento) async {
    try {
      await _firestore.collection(_collection).doc(medicamento.id).set(medicamento.toMap());
    } catch (e) {
      throw Exception('Error creating medicamento: $e');
    }
  }

  // Read a medicamento by ID
  Future<MedicamentoGlobal?> read(String id) async {
    try {
      print('🔍 [MedicamentoRepository] Reading medication from collection: $_collection with id: $id');
      final doc = await _firestore.collection(_collection).doc(id).get();
      
      print('🔍 [MedicamentoRepository] Document exists: ${doc.exists}');
      
      if (doc.exists && doc.data() != null) {
        print('✅ [MedicamentoRepository] Document data found: ${doc.data()}');
        final medication = MedicamentoGlobal.fromMap(doc.data()!, documentId: doc.id);
        print('✅ [MedicamentoRepository] Parsed medication: ${medication.nombre}');
        return medication;
      }
      
      print('❌ [MedicamentoRepository] Document not found or has no data');
      return null;
    } catch (e) {
      print('❌ [MedicamentoRepository] Error reading medicamento: $e');
      throw Exception('Error reading medicamento: $e');
    }
  }

  // Read all medicamentos
  Future<List<MedicamentoGlobal>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .map((doc) => MedicamentoGlobal.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error reading all medicamentos: $e');
    }
  }

  // Update a medicamento
  Future<void> update(MedicamentoGlobal medicamento) async {
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

  // Find medicamentos by restriction status (Note: MedicamentoGlobal doesn't have esRestringido field)
  @Deprecated('MedicamentoGlobal model does not have esRestringido field')
  Future<List<MedicamentoGlobal>> findByEsRestringido(bool esRestringido) async {
    throw Exception('DEPRECATED: MedicamentoGlobal model does not have esRestringido field');
  }

  // UML generalization: Find by tipo (Note: MedicamentoGlobal uses presentacion instead of tipo)
  @Deprecated('Use findByPresentacion instead - MedicamentoGlobal uses presentacion field')
  Future<List<MedicamentoGlobal>> findByTipo(String tipo) async {
    throw Exception('DEPRECATED: Use findByPresentacion instead - MedicamentoGlobal uses presentacion field');
  }

  // Find medicamentos by presentacion
  Future<List<MedicamentoGlobal>> findByPresentacion(String presentacion) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('presentacion', isEqualTo: presentacion)
          .get();
      
      return querySnapshot.docs
          .map((doc) => MedicamentoGlobal.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error finding medicamentos by presentacion: $e');
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
  Stream<MedicamentoGlobal?> streamMedicamento(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null 
            ? MedicamentoGlobal.fromMap(doc.data()!, documentId: doc.id) 
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
  Future<List<MedicamentoGlobal>> findByPuntoFisico(String puntoFisicoId) async {
    throw Exception('DEPRECATED: Use MedicamentoPuntoFisicoRepository.findByPuntoFisicoId() and then fetch individual medicamentos');
  }
}