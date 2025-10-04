import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/punto_fisico.dart';
import '../models/medicamento.dart';

class PuntoFisicoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'puntos_fisicos';

  // Create a new punto fisico
  Future<void> create(PuntoFisico puntoFisico) async {
    try {
      await _firestore.collection(_collection).doc(puntoFisico.id).set(puntoFisico.toMap());
    } catch (e) {
      throw Exception('Error creating punto fisico: $e');
    }
  }

  // Read a punto fisico by ID
  Future<PuntoFisico?> read(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return PuntoFisico.fromMap(doc.data()!, documentId: doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading punto fisico: $e');
    }
  }

  // Read all puntos fisicos
  Future<List<PuntoFisico>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .map((doc) => PuntoFisico.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error reading all puntos fisicos: $e');
    }
  }

  // Update a punto fisico
  Future<void> update(PuntoFisico puntoFisico) async {
    try {
      await _firestore.collection(_collection).doc(puntoFisico.id).update(puntoFisico.toMap());
    } catch (e) {
      throw Exception('Error updating punto fisico: $e');
    }
  }

  // Delete a punto fisico
  Future<void> delete(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting punto fisico: $e');
    }
  }

  // Find puntos fisicos by cadena (pharmacy chain)
  Future<List<PuntoFisico>> findByCadena(String cadena) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('cadena', isEqualTo: cadena)
          .get();
      
      return querySnapshot.docs
          .map((doc) => PuntoFisico.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error finding puntos fisicos by cadena: $e');
    }
  }

  // Find puntos fisicos within a geographical radius
  Future<List<PuntoFisico>> findNearby(double centerLat, double centerLng, double radiusKm) async {
    try {
      // Note: This is a simplified version. For production, consider using GeoFirestore
      // or implementing proper geospatial queries
      final querySnapshot = await _firestore.collection(_collection).get();
      
      List<PuntoFisico> nearbyPuntos = [];
      
      for (var doc in querySnapshot.docs) {
        final punto = PuntoFisico.fromMap(doc.data(), documentId: doc.id);
        final distance = _calculateDistance(centerLat, centerLng, punto.latitud, punto.longitud);
        
        if (distance <= radiusKm) {
          nearbyPuntos.add(punto);
        }
      }
      
      // Sort by distance
      nearbyPuntos.sort((a, b) {
        final distanceA = _calculateDistance(centerLat, centerLng, a.latitud, a.longitud);
        final distanceB = _calculateDistance(centerLat, centerLng, b.latitud, b.longitud);
        return distanceA.compareTo(distanceB);
      });
      
      return nearbyPuntos;
    } catch (e) {
      throw Exception('Error finding nearby puntos fisicos: $e');
    }
  }

  // Search puntos fisicos by name or address
  Future<List<PuntoFisico>> search(String query) async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      return querySnapshot.docs
          .map((doc) => PuntoFisico.fromMap(doc.data(), documentId: doc.id))
          .where((punto) => 
              punto.nombre.toLowerCase().contains(query.toLowerCase()) ||
              punto.direccion.toLowerCase().contains(query.toLowerCase()) ||
              punto.cadena.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Error searching puntos fisicos: $e');
    }
  }

  // Check if punto fisico exists
  Future<bool> exists(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if punto fisico exists: $e');
    }
  }

  // Stream of punto fisico changes
  Stream<PuntoFisico?> streamPuntoFisico(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null 
            ? PuntoFisico.fromMap(doc.data()!, documentId: doc.id) 
            : null);
  }

  // Stream of all puntos fisicos
  Stream<List<PuntoFisico>> streamAllPuntosFisicos() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => PuntoFisico.fromMap(doc.data(), documentId: doc.id))
            .toList());
  }

  // Private helper method to calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Haversine formula implementation
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  // UML relationship method: Get inventory for punto fisico via many-to-many relationship
  // NOTE: This now requires using MedicamentoPuntoFisicoRepository to get the relationships
  // and then fetching individual medicamentos
  @Deprecated('Use MedicamentoPuntoFisicoRepository.findByPuntoFisicoId() and then fetch individual medicamentos')
  Future<List<Medicamento>> findMedicamentos(String puntoId) async {
    throw Exception('DEPRECATED: Use MedicamentoPuntoFisicoRepository.findByPuntoFisicoId() and then fetch individual medicamentos');
  }
}