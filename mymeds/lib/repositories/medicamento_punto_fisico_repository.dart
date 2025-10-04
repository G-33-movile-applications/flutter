import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicamento_punto_fisico.dart';

class MedicamentoPuntoFisicoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'medicamento_punto_fisico';

  // Create a new medicamento-punto fisico relationship
  Future<void> create(MedicamentoPuntoFisico medicamentoPuntoFisico) async {
    try {
      await _firestore.collection(_collection).doc(medicamentoPuntoFisico.id).set(medicamentoPuntoFisico.toMap());
    } catch (e) {
      throw Exception('Error creating medicamento-punto fisico relationship: $e');
    }
  }

  // Read a medicamento-punto fisico relationship by ID
  Future<MedicamentoPuntoFisico?> read(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return MedicamentoPuntoFisico.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading medicamento-punto fisico relationship: $e');
    }
  }

  // Read all medicamento-punto fisico relationships
  Future<List<MedicamentoPuntoFisico>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .map((doc) => MedicamentoPuntoFisico.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error reading all medicamento-punto fisico relationships: $e');
    }
  }

  // Update a medicamento-punto fisico relationship
  Future<void> update(MedicamentoPuntoFisico medicamentoPuntoFisico) async {
    try {
      await _firestore.collection(_collection).doc(medicamentoPuntoFisico.id).update(medicamentoPuntoFisico.toMap());
    } catch (e) {
      throw Exception('Error updating medicamento-punto fisico relationship: $e');
    }
  }

  // Delete a medicamento-punto fisico relationship
  Future<void> delete(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting medicamento-punto fisico relationship: $e');
    }
  }

  // Find relationships by medicamento ID
  Future<List<MedicamentoPuntoFisico>> findByMedicamentoId(String medicamentoId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('medicamentoId', isEqualTo: medicamentoId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => MedicamentoPuntoFisico.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding relationships by medicamento ID: $e');
    }
  }

  // Find relationships by punto fisico ID
  Future<List<MedicamentoPuntoFisico>> findByPuntoFisicoId(String puntoFisicoId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('puntoFisicoId', isEqualTo: puntoFisicoId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => MedicamentoPuntoFisico.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding relationships by punto fisico ID: $e');
    }
  }

  // Find specific relationship by medicamento and punto fisico IDs
  Future<MedicamentoPuntoFisico?> findByMedicamentoAndPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('medicamentoId', isEqualTo: medicamentoId)
          .where('puntoFisicoId', isEqualTo: puntoFisicoId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return MedicamentoPuntoFisico.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Error finding relationship by medicamento and punto fisico: $e');
    }
  }

  // Update stock quantity
  Future<void> updateCantidad(String medicamentoId, String puntoFisicoId, int cantidad) async {
    try {
      final relationship = await findByMedicamentoAndPuntoFisico(medicamentoId, puntoFisicoId);
      if (relationship != null) {
        await update(relationship.copyWith(
          cantidad: cantidad,
          fechaActualizacion: DateTime.now(),
        ));
      } else {
        throw Exception('Relationship not found');
      }
    } catch (e) {
      throw Exception('Error updating stock quantity: $e');
    }
  }

  // Add or update stock for a medicamento at a punto fisico
  Future<void> addOrUpdateStock(String medicamentoId, String puntoFisicoId, int cantidad) async {
    try {
      final existing = await findByMedicamentoAndPuntoFisico(medicamentoId, puntoFisicoId);
      if (existing != null) {
        // Update existing relationship
        await update(existing.copyWith(
          cantidad: cantidad,
          fechaActualizacion: DateTime.now(),
        ));
      } else {
        // Create new relationship
        final newRelationship = MedicamentoPuntoFisico(
          id: '${medicamentoId}_$puntoFisicoId', // Simple ID format
          medicamentoId: medicamentoId,
          puntoFisicoId: puntoFisicoId,
          cantidad: cantidad,
          fechaActualizacion: DateTime.now(),
        );
        await create(newRelationship);
      }
    } catch (e) {
      throw Exception('Error adding or updating stock: $e');
    }
  }

  // Remove all relationships for a medicamento
  Future<void> deleteByMedicamentoId(String medicamentoId) async {
    try {
      final relationships = await findByMedicamentoId(medicamentoId);
      for (var relationship in relationships) {
        await delete(relationship.id);
      }
    } catch (e) {
      throw Exception('Error deleting relationships by medicamento ID: $e');
    }
  }

  // Remove all relationships for a punto fisico
  Future<void> deleteByPuntoFisicoId(String puntoFisicoId) async {
    try {
      final relationships = await findByPuntoFisicoId(puntoFisicoId);
      for (var relationship in relationships) {
        await delete(relationship.id);
      }
    } catch (e) {
      throw Exception('Error deleting relationships by punto fisico ID: $e');
    }
  }

  // Check if relationship exists
  Future<bool> exists(String medicamentoId, String puntoFisicoId) async {
    try {
      final relationship = await findByMedicamentoAndPuntoFisico(medicamentoId, puntoFisicoId);
      return relationship != null;
    } catch (e) {
      throw Exception('Error checking if relationship exists: $e');
    }
  }

  // Stream of relationships for a medicamento
  Stream<List<MedicamentoPuntoFisico>> streamByMedicamentoId(String medicamentoId) {
    return _firestore
        .collection(_collection)
        .where('medicamentoId', isEqualTo: medicamentoId)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => MedicamentoPuntoFisico.fromMap(doc.data()))
            .toList());
  }

  // Stream of relationships for a punto fisico
  Stream<List<MedicamentoPuntoFisico>> streamByPuntoFisicoId(String puntoFisicoId) {
    return _firestore
        .collection(_collection)
        .where('puntoFisicoId', isEqualTo: puntoFisicoId)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => MedicamentoPuntoFisico.fromMap(doc.data()))
            .toList());
  }

  // Get puntos fisicos where a medicamento is available
  Future<List<String>> getPuntosFisicosForMedicamento(String medicamentoId) async {
    try {
      final relationships = await findByMedicamentoId(medicamentoId);
      return relationships
          .where((rel) => rel.cantidad > 0) // Only where stock is available
          .map((rel) => rel.puntoFisicoId)
          .toList();
    } catch (e) {
      throw Exception('Error getting puntos fisicos for medicamento: $e');
    }
  }

  // Get medicamentos available at a punto fisico
  Future<List<String>> getMedicamentosAtPuntoFisico(String puntoFisicoId) async {
    try {
      final relationships = await findByPuntoFisicoId(puntoFisicoId);
      return relationships
          .where((rel) => rel.cantidad > 0) // Only where stock is available
          .map((rel) => rel.medicamentoId)
          .toList();
    } catch (e) {
      throw Exception('Error getting medicamentos at punto fisico: $e');
    }
  }
  Future<List<MedicamentoPuntoFisico>> getMedicamentosAtPuntoFisicoMed(String puntoFisicoId) async {
  try {
    final relationships = await findByPuntoFisicoId(puntoFisicoId);

    // Only return those that have stock available
    return relationships.where((rel) => rel.cantidad > 0).toList();
  } catch (e) {
    throw Exception('Error getting medicamentos at punto físico: $e');
  }
}
}