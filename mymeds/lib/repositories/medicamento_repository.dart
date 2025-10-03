import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicamento.dart';
import '../models/punto_fisico.dart';
import 'punto_fisico_repository.dart';

class MedicamentoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'medicamentos';
  final String _medicamentoPuntoCollection = 'medicamento_puntos';
  final PuntoFisicoRepository _puntoFisicoRepository = PuntoFisicoRepository();

  // Create a new medicamento
  Future<void> create(Medicamento medicamento) async {
    try {
      await _firestore.collection(_collection).doc(medicamento.id).set(medicamento.toMap());
    } catch (e) {
      throw Exception('Error creating medicamento: $e');
    }
  }

  // Read a medicamento by ID with its available points
  Future<Medicamento?> read(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        final medicamentoData = doc.data()!;
        
        // Fetch related puntos fisicos
        final puntosDisponibles = await _getPuntosDisponiblesForMedicamento(id);
        
        return Medicamento.fromMap(medicamentoData, puntosDisponibles: puntosDisponibles);
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
      List<Medicamento> medicamentos = [];
      
      for (var doc in querySnapshot.docs) {
        final medicamentoData = doc.data();
        final id = medicamentoData['id'] as String;
        
        // Fetch related puntos fisicos for each medicamento
        final puntosDisponibles = await _getPuntosDisponiblesForMedicamento(id);
        
        medicamentos.add(Medicamento.fromMap(medicamentoData, puntosDisponibles: puntosDisponibles));
      }
      
      return medicamentos;
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
      // Delete related medicamento-punto relationships
      await _deleteMedicamentoPuntoRelationships(id);
      
      // Delete the medicamento
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting medicamento: $e');
    }
  }

  // Find medicamentos by prescription ID
  Future<List<Medicamento>> findByPrescripcionId(String prescripcionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('prescripcionId', isEqualTo: prescripcionId)
          .get();
      
      List<Medicamento> medicamentos = [];
      
      for (var doc in querySnapshot.docs) {
        final medicamentoData = doc.data();
        final id = medicamentoData['id'] as String;
        
        // Fetch related puntos fisicos for each medicamento
        final puntosDisponibles = await _getPuntosDisponiblesForMedicamento(id);
        
        medicamentos.add(Medicamento.fromMap(medicamentoData, puntosDisponibles: puntosDisponibles));
      }
      
      return medicamentos;
    } catch (e) {
      throw Exception('Error finding medicamentos by prescription ID: $e');
    }
  }

  // Find medicamentos by restriction status
  Future<List<Medicamento>> findByEsRestringido(bool esRestringido) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('esRestringido', isEqualTo: esRestringido)
          .get();
      
      List<Medicamento> medicamentos = [];
      
      for (var doc in querySnapshot.docs) {
        final medicamentoData = doc.data();
        final id = medicamentoData['id'] as String;
        
        // Fetch related puntos fisicos for each medicamento
        final puntosDisponibles = await _getPuntosDisponiblesForMedicamento(id);
        
        medicamentos.add(Medicamento.fromMap(medicamentoData, puntosDisponibles: puntosDisponibles));
      }
      
      return medicamentos;
    } catch (e) {
      throw Exception('Error finding medicamentos by restriction status: $e');
    }
  }

  // Find medicamentos by type
  Future<List<Medicamento>> findByTipo(String tipo) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('tipo', isEqualTo: tipo)
          .get();
      
      List<Medicamento> medicamentos = [];
      
      for (var doc in querySnapshot.docs) {
        final medicamentoData = doc.data();
        final id = medicamentoData['id'] as String;
        
        // Fetch related puntos fisicos for each medicamento
        final puntosDisponibles = await _getPuntosDisponiblesForMedicamento(id);
        
        medicamentos.add(Medicamento.fromMap(medicamentoData, puntosDisponibles: puntosDisponibles));
      }
      
      return medicamentos;
    } catch (e) {
      throw Exception('Error finding medicamentos by type: $e');
    }
  }

  // Find medicamentos available at a specific punto fisico
  Future<List<Medicamento>> findByPuntoFisico(String puntoFisicoId) async {
    try {
      final relationshipSnapshot = await _firestore
          .collection(_medicamentoPuntoCollection)
          .where('puntoFisicoId', isEqualTo: puntoFisicoId)
          .get();
      
      List<Medicamento> medicamentos = [];
      
      for (var relationDoc in relationshipSnapshot.docs) {
        final medicamentoId = relationDoc.data()['medicamentoId'] as String;
        final medicamento = await read(medicamentoId);
        if (medicamento != null) {
          medicamentos.add(medicamento);
        }
      }
      
      return medicamentos;
    } catch (e) {
      throw Exception('Error finding medicamentos by punto fisico: $e');
    }
  }

  // Add medicamento to punto fisico (many-to-many relationship)
  Future<void> addMedicamentoToPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    try {
      final relationshipId = '${medicamentoId}_$puntoFisicoId';
      await _firestore.collection(_medicamentoPuntoCollection).doc(relationshipId).set({
        'medicamentoId': medicamentoId,
        'puntoFisicoId': puntoFisicoId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error adding medicamento to punto fisico: $e');
    }
  }

  // Remove medicamento from punto fisico
  Future<void> removeMedicamentoFromPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    try {
      final relationshipId = '${medicamentoId}_$puntoFisicoId';
      await _firestore.collection(_medicamentoPuntoCollection).doc(relationshipId).delete();
    } catch (e) {
      throw Exception('Error removing medicamento from punto fisico: $e');
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
        await delete(doc.id);
      }
    } catch (e) {
      throw Exception('Error deleting medicamentos by prescription ID: $e');
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

  // Private helper methods
  Future<List<PuntoFisico>> _getPuntosDisponiblesForMedicamento(String medicamentoId) async {
    try {
      final relationshipSnapshot = await _firestore
          .collection(_medicamentoPuntoCollection)
          .where('medicamentoId', isEqualTo: medicamentoId)
          .get();
      
      List<PuntoFisico> puntos = [];
      
      for (var relationDoc in relationshipSnapshot.docs) {
        final puntoFisicoId = relationDoc.data()['puntoFisicoId'] as String;
        final punto = await _puntoFisicoRepository.read(puntoFisicoId);
        if (punto != null) {
          puntos.add(punto);
        }
      }
      
      return puntos;
    } catch (e) {
      throw Exception('Error getting puntos disponibles for medicamento: $e');
    }
  }

  Future<void> _deleteMedicamentoPuntoRelationships(String medicamentoId) async {
    try {
      final relationshipSnapshot = await _firestore
          .collection(_medicamentoPuntoCollection)
          .where('medicamentoId', isEqualTo: medicamentoId)
          .get();
      
      for (var doc in relationshipSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error deleting medicamento-punto relationships: $e');
    }
  }

  // Stream of medicamento changes
  Stream<Medicamento?> streamMedicamento(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .asyncMap((doc) async {
          if (doc.exists && doc.data() != null) {
            final medicamentoData = doc.data()!;
            final puntosDisponibles = await _getPuntosDisponiblesForMedicamento(id);
            return Medicamento.fromMap(medicamentoData, puntosDisponibles: puntosDisponibles);
          }
          return null;
        });
  }
}