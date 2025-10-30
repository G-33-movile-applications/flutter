import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prescripcion.dart';
import '../models/prescripcion_with_medications.dart';
import 'medicamento_prescripcion_repository.dart';

class PrescripcionRepository {
  final MedicamentoPrescripcionRepository _medicamentoRepo = MedicamentoPrescripcionRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'prescripciones';

  // Create a new prescripcion
  Future<void> create(Prescripcion prescripcion) async {
    try {
      await _firestore.collection(_collection).doc(prescripcion.id).set(prescripcion.toMap());
    } catch (e) {
      throw Exception('Error creating prescripcion: $e');
    }
  }

  // Read a prescripcion by ID with its medications
  Future<Prescripcion?> read(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        final prescripcionData = doc.data()!;
        
        // Medicamentos are now embedded in the prescripcion document
        return Prescripcion.fromMap(prescripcionData);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading prescripcion: $e');
    }
  }

  // Read all prescripciones
  Future<List<Prescripcion>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      return querySnapshot.docs
          .map((doc) => Prescripcion.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error reading all prescripciones: $e');
    }
  }

  // Update a prescripcion
  Future<void> update(Prescripcion prescripcion) async {
    try {
      await _firestore.collection(_collection).doc(prescripcion.id).update(prescripcion.toMap());
    } catch (e) {
      throw Exception('Error updating prescripcion: $e');
    }
  }

  // Delete a prescripcion
  Future<void> delete(String id) async {
    try {
      // NOTE: Medicamentos are now managed via List<Medicamento> in Prescripcion
      // No need to delete them separately as they're part of the document
      
      // Delete the prescripcion
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting prescripcion: $e');
    }
  }

  // Find prescripcion by pedido ID
  Future<Prescripcion?> findByPedidoId(String pedidoId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('pedidoId', isEqualTo: pedidoId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final prescripcionData = querySnapshot.docs.first.data();
        return Prescripcion.fromMap(prescripcionData);
      }
      return null;
    } catch (e) {
      throw Exception('Error finding prescripcion by pedido ID: $e');
    }
  }

  // Find prescripciones by doctor
  Future<List<Prescripcion>> findByRecetadoPor(String doctor) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('recetadoPor', isEqualTo: doctor)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Prescripcion.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error finding prescripciones by doctor: $e');
    }
  }

  // Delete prescripcion by pedido ID
  Future<void> deleteByPedidoId(String pedidoId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('pedidoId', isEqualTo: pedidoId)
          .get();
      
      for (var doc in querySnapshot.docs) {
        await delete(doc.id);
      }
    } catch (e) {
      throw Exception('Error deleting prescripcion by pedido ID: $e');
    }
  }

  // Check if prescripcion exists
  Future<bool> exists(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if prescripcion exists: $e');
    }
  }

  // Stream of prescripcion changes
  Stream<Prescripcion?> streamPrescripcion(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final prescripcionData = doc.data()!;
            return Prescripcion.fromMap(prescripcionData);
          }
          return null;
        });
  }

  // UML relationship method: Usuario (1) —— (0..*) Prescripcion
  // Updated to work with subcollection approach: usuarios/{userId}/prescripciones
  Future<List<Prescripcion>> findByUserId(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final querySnapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .get();
      
      return querySnapshot.docs
          .where((doc) => doc.id.isNotEmpty) // Filter out documents with empty IDs
          .map((doc) => Prescripcion.fromMap(doc.data(), documentId: doc.id))
          .where((prescripcion) => prescripcion.id.isNotEmpty) // Filter out prescriptions with empty IDs
          .toList();
    } catch (e) {
      throw Exception('Error finding prescripciones by user ID: $e');
    }
  }

  // Get only active prescriptions for a user
  Future<List<Prescripcion>> findActiveByUserId(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final querySnapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .where('activa', isEqualTo: true)
          .get();
      
      return querySnapshot.docs
          .where((doc) => doc.id.isNotEmpty) // Filter out documents with empty IDs
          .map((doc) => Prescripcion.fromMap(doc.data(), documentId: doc.id))
          .where((prescripcion) => prescripcion.id.isNotEmpty) // Filter out prescriptions with empty IDs
          .toList();
    } catch (e) {
      throw Exception('Error finding active prescripciones by user ID: $e');
    }
  }

  // Stream version of findByUserId for reactive UIs
  // Updated to work with subcollection approach: usuarios/{userId}/prescripciones
  Stream<List<Prescripcion>> streamByUserId(String userId) {
    if (userId.isEmpty) {
      return Stream.error(ArgumentError('User ID cannot be empty'));
    }
    
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .collection('prescripciones')
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .where((doc) => doc.id.isNotEmpty) // Filter out documents with empty IDs
            .map((doc) => Prescripcion.fromMap(doc.data(), documentId: doc.id))
            .where((prescripcion) => prescripcion.id.isNotEmpty) // Filter out prescriptions with empty IDs
            .toList());
  }

  // Stream only active prescriptions for a user (for real-time updates)
  Stream<List<Prescripcion>> streamActiveByUserId(String userId) {
    if (userId.isEmpty) {
      return Stream.error(ArgumentError('User ID cannot be empty'));
    }
    
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .collection('prescripciones')
        .where('activa', isEqualTo: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .where((doc) => doc.id.isNotEmpty) // Filter out documents with empty IDs
            .map((doc) => Prescripcion.fromMap(doc.data(), documentId: doc.id))
            .where((prescripcion) => prescripcion.id.isNotEmpty) // Filter out prescriptions with empty IDs
            .toList());
  }

  // Update medicamentos in a prescripcion
  @Deprecated('Medicamentos are now stored in subcollections')
  Future<void> updateMedicamentos(String prescripcionId, List<dynamic> medicamentos) async {
    // Medicamentos are now in subcollections, this method is deprecated
    throw UnimplementedError('Medicamentos are now stored in subcollections. Use subcollection-based operations.');
  }

  // Get medicamentos for a prescripcion
  @Deprecated('Medicamentos are now stored in subcollections')
  Future<List<dynamic>> getMedicamentosDePrescripcion(String prescripcionId) async {
    // Medicamentos are now in subcollections, return empty list for backward compatibility
    return <dynamic>[];
  }

  // Alias method for UserSession compatibility
  Future<List<Prescripcion>> getPrescripcionesByUser(String userId) async {
    return await findByUserId(userId);
  }

  // ==================== NEW: Load prescriptions with medications ====================

  /// Load a single prescription with its medications from the subcollection
  /// 
  /// Path: usuarios/{userId}/prescripciones/{prescripcionId}
  /// Medications path: usuarios/{userId}/prescripciones/{prescripcionId}/medicamentos
  Future<PrescripcionWithMedications?> getPrescripcionWithMedications({
    required String userId,
    required String prescripcionId,
  }) async {
    try {
      // Load the prescription from subcollection
      final doc = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcionId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final prescripcion = Prescripcion.fromMap(doc.data()!, documentId: doc.id);

      // Load medications from subcollection
      final medicamentos = await _medicamentoRepo.getMedicamentosByPrescripcion(
        userId: userId,
        prescripcionId: prescripcionId,
      );

      return PrescripcionWithMedications(
        prescripcion: prescripcion,
        medicamentos: medicamentos,
      );
    } catch (e) {
      throw Exception('Error loading prescription with medications: $e');
    }
  }

  /// Load all prescriptions for a user with their medications
  /// 
  /// This loads prescriptions from usuarios/{userId}/prescripciones
  /// and medications from the subcollections
  Future<List<PrescripcionWithMedications>> getPrescripcionesWithMedicationsByUser(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }

      // Load all prescriptions for user
      final prescripciones = await findByUserId(userId);

      // Load medications for each prescription
      final List<PrescripcionWithMedications> result = [];
      
      for (final prescripcion in prescripciones) {
        final medicamentos = await _medicamentoRepo.getMedicamentosByPrescripcion(
          userId: userId,
          prescripcionId: prescripcion.id,
        );

        result.add(PrescripcionWithMedications(
          prescripcion: prescripcion,
          medicamentos: medicamentos,
        ));
      }

      return result;
    } catch (e) {
      throw Exception('Error loading prescriptions with medications for user: $e');
    }
  }

  /// Stream prescriptions with medications for real-time updates
  /// 
  /// Note: This streams prescription updates, but medications are fetched on each update
  /// For frequently changing medications, consider a more sophisticated streaming approach
  Stream<List<PrescripcionWithMedications>> streamPrescripcionesWithMedicationsByUser(String userId) async* {
    if (userId.isEmpty) {
      yield* Stream.error(ArgumentError('User ID cannot be empty'));
      return;
    }

    await for (final prescripciones in streamByUserId(userId)) {
      final List<PrescripcionWithMedications> result = [];
      
      for (final prescripcion in prescripciones) {
        try {
          final medicamentos = await _medicamentoRepo.getMedicamentosByPrescripcion(
            userId: userId,
            prescripcionId: prescripcion.id,
          );

          result.add(PrescripcionWithMedications(
            prescripcion: prescripcion,
            medicamentos: medicamentos,
          ));
        } catch (e) {
          // Log error but continue with other prescriptions
          print('Error loading medications for prescription ${prescripcion.id}: $e');
          // Add prescription with empty medications list
          result.add(PrescripcionWithMedications(
            prescripcion: prescripcion,
            medicamentos: [],
          ));
        }
      }
      
      yield result;
    }
  }

  /// Create prescription with medications (saves to subcollections)
  /// 
  /// This is the recommended way to create a prescription with medications
  Future<void> createWithMedicamentos({
    required String userId,
    required Prescripcion prescripcion,
    required List<dynamic> medicamentos, // Can be MedicamentoPrescripcion or Map
  }) async {
    try {
      // 1. Create the prescription document
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcion.id)
          .set(prescripcion.toMap());

      // 2. Add medications to subcollection
      if (medicamentos.isNotEmpty) {
        final batch = _firestore.batch();
        
        for (final medicamento in medicamentos) {
          // Convert to Map if it's a MedicamentoPrescripcion object
          final medicamentoMap = medicamento is Map<String, dynamic> 
              ? medicamento 
              : (medicamento as dynamic).toMap();
          
          final medicamentoId = medicamentoMap['id'] ?? medicamentoMap['medicamentoRef']?.split('/').last ?? 
              'med_${DateTime.now().millisecondsSinceEpoch}_${medicamentos.indexOf(medicamento)}';
          
          final docRef = _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('prescripciones')
              .doc(prescripcion.id)
              .collection('medicamentos')
              .doc(medicamentoId);
          
          batch.set(docRef, medicamentoMap);
        }
        
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Error creating prescription with medications: $e');
    }
  }
}