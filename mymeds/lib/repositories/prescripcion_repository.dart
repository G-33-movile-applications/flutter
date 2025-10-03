import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prescripcion.dart';
import 'medicamento_repository.dart';

class PrescripcionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'prescripciones';
  final MedicamentoRepository _medicamentoRepository = MedicamentoRepository();

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
        
        // Fetch related medications
        final medicamentos = await _medicamentoRepository.findByPrescripcionId(id);
        
        return Prescripcion.fromMap(prescripcionData, medicamentos: medicamentos);
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
      List<Prescripcion> prescripciones = [];
      
      for (var doc in querySnapshot.docs) {
        final prescripcionData = doc.data();
        final id = prescripcionData['id'] as String;
        
        // Fetch related medications for each prescripcion
        final medicamentos = await _medicamentoRepository.findByPrescripcionId(id);
        
        prescripciones.add(Prescripcion.fromMap(prescripcionData, medicamentos: medicamentos));
      }
      
      return prescripciones;
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
      // Delete related medications first
      await _medicamentoRepository.deleteByPrescripcionId(id);
      
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
        final id = prescripcionData['id'] as String;
        
        // Fetch related medications
        final medicamentos = await _medicamentoRepository.findByPrescripcionId(id);
        
        return Prescripcion.fromMap(prescripcionData, medicamentos: medicamentos);
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
      
      List<Prescripcion> prescripciones = [];
      
      for (var doc in querySnapshot.docs) {
        final prescripcionData = doc.data();
        final id = prescripcionData['id'] as String;
        
        // Fetch related medications for each prescripcion
        final medicamentos = await _medicamentoRepository.findByPrescripcionId(id);
        
        prescripciones.add(Prescripcion.fromMap(prescripcionData, medicamentos: medicamentos));
      }
      
      return prescripciones;
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
        .asyncMap((doc) async {
          if (doc.exists && doc.data() != null) {
            final prescripcionData = doc.data()!;
            final medicamentos = await _medicamentoRepository.findByPrescripcionId(id);
            return Prescripcion.fromMap(prescripcionData, medicamentos: medicamentos);
          }
          return null;
        });
  }

  // UML relationship method: Usuario (1) —— (0..*) Prescripcion
  Future<List<Prescripcion>> findByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();
      
      List<Prescripcion> prescripciones = [];
      
      for (var doc in querySnapshot.docs) {
        final medicamentos = await _medicamentoRepository.findByPrescripcionId(doc.id);
        prescripciones.add(Prescripcion.fromMap(doc.data(), medicamentos: medicamentos));
      }
      
      return prescripciones;
    } catch (e) {
      throw Exception('Error finding prescripciones by user ID: $e');
    }
  }

  // Stream version of findByUserId for reactive UIs
  Stream<List<Prescripcion>> streamByUserId(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((querySnapshot) async {
          List<Prescripcion> prescripciones = [];
          
          for (var doc in querySnapshot.docs) {
            final medicamentos = await _medicamentoRepository.findByPrescripcionId(doc.id);
            prescripciones.add(Prescripcion.fromMap(doc.data(), medicamentos: medicamentos));
          }
          
          return prescripciones;
        });
  }

  // Alias method for UserSession compatibility
  Future<List<Prescripcion>> getPrescripcionesByUser(String userId) async {
    return await findByUserId(userId);
  }
}