import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicamento.dart';

class MedicamentoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'medicamentos';


  // Create a new medicamento - requires prescripcionId and puntoFisicoId per UML
  Future<void> create(Medicamento medicamento) async {
    try {
      // Validation: both FKs must be provided per UML
      if (medicamento.prescripcionId.isEmpty) {
        throw Exception('prescripcionId is required - UML constraint');
      }
      if (medicamento.puntoFisicoId.isEmpty) {
        throw Exception('puntoFisicoId is required - UML constraint');
      }
      
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

  // UML relationship: Prescripcion (1) —— (1..*) Medicamento
  Future<List<Medicamento>> findByPrescripcionId(String prescripcionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('prescripcionId', isEqualTo: prescripcionId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Medicamento.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding medicamentos by prescripcion ID: $e');
    }
  }

  // Stream version for reactive UIs
  Stream<List<Medicamento>> streamByPrescripcionId(String prescripcionId) {
    return _firestore
        .collection(_collection)
        .where('prescripcionId', isEqualTo: prescripcionId)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Medicamento.fromMap(doc.data()))
            .toList());
  }

  // UML relationship: Medicamento (0..*) —— (1) PuntoFisico  
  Future<List<Medicamento>> findByPuntoFisicoId(String puntoFisicoId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('puntoFisicoId', isEqualTo: puntoFisicoId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Medicamento.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding medicamentos by punto fisico ID: $e');
    }
  }

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

  // Helper method for getting distinct puntos by user (via prescripciones → medicamentos)
  Future<List<String>> findDistinctPuntosByUserId(String userId) async {
    try {
      // First get user's prescripciones, then their medicamentos, then distinct puntos
      final prescripcionesSnapshot = await _firestore
          .collection('prescripciones')
          .where('userId', isEqualTo: userId)
          .get();
      
      Set<String> distinctPuntos = <String>{};
      
      for (var prescripcionDoc in prescripcionesSnapshot.docs) {
        final medicamentosSnapshot = await _firestore
            .collection(_collection)
            .where('prescripcionId', isEqualTo: prescripcionDoc.id)
            .get();
        
        for (var medicamentoDoc in medicamentosSnapshot.docs) {
          final puntoFisicoId = medicamentoDoc.data()['puntoFisicoId'] as String?;
          if (puntoFisicoId != null && puntoFisicoId.isNotEmpty) {
            distinctPuntos.add(puntoFisicoId);
          }
        }
      }
      
      return distinctPuntos.toList();
    } catch (e) {
      throw Exception('Error finding distinct puntos by user ID: $e');
    }
  }

  // Delete medicamentos by prescription ID
  Future<void> deleteByPrescripcionId(String prescripcionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('prescripcionId', isEqualTo: prescripcionId)
          .get();
      
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error deleting medicamentos by prescripcion ID: $e');
    }
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

  @Deprecated('Use findByPuntoFisicoId instead')
  Future<List<Medicamento>> findByPuntoFisico(String puntoFisicoId) async {
    // Redirect to new method
    return await findByPuntoFisicoId(puntoFisicoId);
  }
}