import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicamento_prescripcion.dart';

/// Repository for managing medications within prescriptions
/// Collection path: usuarios/{userId}/prescripciones/{prescripcionId}/medicamentos/{medicamentoId}
class MedicamentoPrescripcionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all medications for a specific prescription
  /// 
  /// Path: usuarios/{userId}/prescripciones/{prescripcionId}/medicamentos
  Future<List<MedicamentoPrescripcion>> getMedicamentosByPrescripcion({
    required String userId,
    required String prescripcionId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .collection('medicamentos')
          .get();

      return querySnapshot.docs
          .map((doc) => MedicamentoPrescripcion.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error loading medications for prescription: $e');
    }
  }

  /// Stream medications for a specific prescription
  /// 
  /// Useful for real-time updates in the UI
  Stream<List<MedicamentoPrescripcion>> streamMedicamentosByPrescripcion({
    required String userId,
    required String prescripcionId,
  }) {
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .collection('prescripciones')
        .doc(prescripcionId)
        .collection('medicamentos')
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => MedicamentoPrescripcion.fromMap(doc.data(), documentId: doc.id))
            .toList());
  }

  /// Add a medication to a prescription
  /// 
  /// Creates a new document in the medications subcollection
  Future<void> addMedicamento({
    required String userId,
    required String prescripcionId,
    required MedicamentoPrescripcion medicamento,
  }) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .collection('medicamentos')
          .doc(medicamento.id)
          .set(medicamento.toMap());
    } catch (e) {
      throw Exception('Error adding medication to prescription: $e');
    }
  }

  /// Add multiple medications to a prescription
  /// 
  /// Batch operation for efficiency
  Future<void> addMultipleMedicamentos({
    required String userId,
    required String prescripcionId,
    required List<MedicamentoPrescripcion> medicamentos,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (final medicamento in medicamentos) {
        final docRef = _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('prescripciones')
            .doc(prescripcionId)
            .collection('medicamentos')
            .doc(medicamento.id);
        
        batch.set(docRef, medicamento.toMap());
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Error adding medications to prescription: $e');
    }
  }

  /// Update a medication in a prescription
  Future<void> updateMedicamento({
    required String userId,
    required String prescripcionId,
    required MedicamentoPrescripcion medicamento,
  }) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .collection('medicamentos')
          .doc(medicamento.id)
          .update(medicamento.toMap());
    } catch (e) {
      throw Exception('Error updating medication in prescription: $e');
    }
  }

  /// Delete a medication from a prescription
  Future<void> deleteMedicamento({
    required String userId,
    required String prescripcionId,
    required String medicamentoId,
  }) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .collection('medicamentos')
          .doc(medicamentoId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting medication from prescription: $e');
    }
  }

  /// Get a specific medication from a prescription
  Future<MedicamentoPrescripcion?> getMedicamento({
    required String userId,
    required String prescripcionId,
    required String medicamentoId,
  }) async {
    try {
      final doc = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .collection('medicamentos')
          .doc(medicamentoId)
          .get();

      if (doc.exists && doc.data() != null) {
        return MedicamentoPrescripcion.fromMap(doc.data()!, documentId: doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting medication: $e');
    }
  }

  /// Check if a medication exists in a prescription
  Future<bool> exists({
    required String userId,
    required String prescripcionId,
    required String medicamentoId,
  }) async {
    try {
      final doc = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .collection('medicamentos')
          .doc(medicamentoId)
          .get();

      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if medication exists: $e');
    }
  }
}
