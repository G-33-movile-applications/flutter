import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pedido.dart';
import 'prescripcion_repository.dart';

class PedidoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'pedidos';
  final PrescripcionRepository _prescripcionRepository = PrescripcionRepository();

  bool _isValidPedidoData(Map<String, dynamic> data) {
    try {
      // Check for required timestamps
      final fechaDespacho = data['fechaDespacho'];
      final fechaEntrega = data['fechaEntrega'];
      
      if (fechaDespacho == null || fechaEntrega == null) {
        
        return false;
      }
      
      if (fechaDespacho is! Timestamp || fechaEntrega is! Timestamp) {
        
        return false;
      }

      // Check for other required fields
      final entregaEnTienda = data['entregaEnTienda'];
      if (entregaEnTienda == null) {
        
        return false;
      }

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Create a new pedido
  Future<void> create(Pedido pedido) async {
    try {
      await _firestore.collection(_collection).doc(pedido.identificadorPedido).set(pedido.toMap());
    } catch (e) {
      throw Exception('Error creating pedido: $e');
    }
  }

  // Read a pedido by ID with its prescription
  Future<Pedido?> read(String identificadorPedido) async {
    try {
      final doc = await _firestore.collection(_collection).doc(identificadorPedido).get();
      if (doc.exists && doc.data() != null) {
        final pedidoData = doc.data()!;
        
        // Note: Prescriptions are now managed separately, no longer embedded
        return Pedido.fromMap(pedidoData, documentId: identificadorPedido);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading pedido: $e');
    }
  }

  // Read all pedidos for a specific user
  Future<List<Pedido>> readAll({String? userId}) async {
    try {
      Query query = _firestore.collection(_collection);
      
      if (userId != null) {
        query = query.where('usuarioId', isEqualTo: userId);
      }
      
      final querySnapshot = await query.get();
      List<Pedido> pedidos = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          final pedidoData = doc.data() as Map<String, dynamic>;
          
          // Skip invalid data
          if (!_isValidPedidoData(pedidoData)) {
            
            continue;
          }

          final identificadorPedido = pedidoData['identificadorPedido'] as String? ?? doc.id;
          
          // Note: Prescriptions are now managed separately
          pedidos.add(Pedido.fromMap(pedidoData, documentId: identificadorPedido));
        } catch (e) {
          
          // Continue processing other pedidos
          continue;
        }
      }
      
      return pedidos;
    } catch (e) {
      throw Exception('Error reading all pedidos: $e');
    }
  }

  // Update a pedido
  Future<void> update(Pedido pedido) async {
    try {
      await _firestore.collection(_collection).doc(pedido.identificadorPedido).update(pedido.toMap());
    } catch (e) {
      throw Exception('Error updating pedido: $e');
    }
  }

  // Delete a pedido
  Future<void> delete(String identificadorPedido) async {
    try {
      // Delete related prescription first
      await _prescripcionRepository.deleteByPedidoId(identificadorPedido);
      
      // Delete the pedido
      await _firestore.collection(_collection).doc(identificadorPedido).delete();
    } catch (e) {
      throw Exception('Error deleting pedido: $e');
    }
  }

  // Find pedidos by user ID
  Future<List<Pedido>> findByUsuarioId(String usuarioId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('usuarioId', isEqualTo: usuarioId)
          .get();
      
      List<Pedido> pedidos = [];
      
      for (var doc in querySnapshot.docs) {
        final pedidoData = doc.data();
        final identificadorPedido = pedidoData['identificadorPedido'] as String? ?? doc.id;
        
        // Note: Prescriptions are now managed separately
        pedidos.add(Pedido.fromMap(pedidoData, documentId: identificadorPedido));
      }
      
      return pedidos;
    } catch (e) {
      throw Exception('Error finding pedidos by user ID: $e');
    }
  }

  // Find pedidos by delivery status
  Future<List<Pedido>> findByEntregado(bool entregado) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('entregado', isEqualTo: entregado)
          .get();
      
      List<Pedido> pedidos = [];
      
      for (var doc in querySnapshot.docs) {
        final pedidoData = doc.data();
        final identificadorPedido = pedidoData['identificadorPedido'] as String? ?? doc.id;
        
        // Note: Prescriptions are now managed separately
        pedidos.add(Pedido.fromMap(pedidoData, documentId: identificadorPedido));
      }
      
      return pedidos;
    } catch (e) {
      throw Exception('Error finding pedidos by delivery status: $e');
    }
  }

  // Update delivery status
  Future<void> updateEntregado(String identificadorPedido, bool entregado) async {
    try {
      await _firestore.collection(_collection).doc(identificadorPedido).update({
        'entregado': entregado,
      });
    } catch (e) {
      throw Exception('Error updating delivery status: $e');
    }
  }

  // Check if pedido exists
  Future<bool> exists(String identificadorPedido) async {
    try {
      final doc = await _firestore.collection(_collection).doc(identificadorPedido).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if pedido exists: $e');
    }
  }

  // Stream of pedido changes
  Stream<Pedido?> streamPedido(String identificadorPedido) {
    return _firestore
        .collection(_collection)
        .doc(identificadorPedido)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final pedidoData = doc.data()!;
            // Note: Prescriptions are now managed separately
            return Pedido.fromMap(pedidoData, documentId: identificadorPedido);
          }
          return null;
        });
  }

  // Stream of pedidos by user
  Stream<List<Pedido>> streamPedidosByUsuario(String usuarioId) {
    return _firestore
        .collection(_collection)
        .where('usuarioId', isEqualTo: usuarioId)
        .snapshots()
        .map((querySnapshot) {
          List<Pedido> pedidos = [];
          
          for (var doc in querySnapshot.docs) {
            final pedidoData = doc.data();
            final identificadorPedido = pedidoData['identificadorPedido'] as String? ?? doc.id;
            
            // Note: Prescriptions are now managed separately
            pedidos.add(Pedido.fromMap(pedidoData, documentId: identificadorPedido));
          }
          
          return pedidos;
        });
  }

  // Alias method for UserSession compatibility
  Future<List<Pedido>> getPedidosByUser(String usuarioId) async {
    return await findByUsuarioId(usuarioId);
  }
}