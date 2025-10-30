import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/pedido.dart';
import '../models/prescripcion.dart';
import '../models/medicamento.dart';
import '../models/medicamento_global.dart';
import '../models/punto_fisico.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/prescripcion_repository.dart';
import '../repositories/medicamento_repository.dart';
import '../repositories/punto_fisico_repository.dart';
import '../repositories/medicamento_punto_fisico_repository.dart';

/// Façade class that provides a simplified interface to all repositories
/// This class acts as a single entry point for the UI layer, hiding the complexity
/// of managing multiple repositories and their relationships
class AppRepositoryFacade {
  // Repository instances - using dependency injection pattern
  final UsuarioRepository _usuarioRepository;
  final PedidoRepository _pedidoRepository;
  final PrescripcionRepository _prescripcionRepository;
  final MedicamentoRepository _medicamentoRepository;
  final PuntoFisicoRepository _puntoFisicoRepository;
  final MedicamentoPuntoFisicoRepository _medicamentoPuntoFisicoRepository;

  // Constructor with optional dependency injection
  AppRepositoryFacade({
    UsuarioRepository? usuarioRepository,
    PedidoRepository? pedidoRepository,
    PrescripcionRepository? prescripcionRepository,
    MedicamentoRepository? medicamentoRepository,
    PuntoFisicoRepository? puntoFisicoRepository,
    MedicamentoPuntoFisicoRepository? medicamentoPuntoFisicoRepository,
  })  : _usuarioRepository = usuarioRepository ?? UsuarioRepository(),
        _pedidoRepository = pedidoRepository ?? PedidoRepository(),
        _prescripcionRepository = prescripcionRepository ?? PrescripcionRepository(),
        _medicamentoRepository = medicamentoRepository ?? MedicamentoRepository(),
        _puntoFisicoRepository = puntoFisicoRepository ?? PuntoFisicoRepository(),
        _medicamentoPuntoFisicoRepository = medicamentoPuntoFisicoRepository ?? MedicamentoPuntoFisicoRepository();

  // ==================== USER OPERATIONS ====================

  /// Create a new user account
  Future<void> createUser(UserModel usuario) async {
    await _usuarioRepository.create(usuario);
  }

  /// Get user by ID
  Future<UserModel?> getUser(String uid) async {
    return await _usuarioRepository.read(uid);
  }

  /// Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    return await _usuarioRepository.findByEmail(email);
  }

  /// Update user information
  Future<void> updateUser(UserModel usuario) async {
    await _usuarioRepository.update(usuario);
  }

  /// Delete user account
  Future<void> deleteUser(String uid) async {
    // Delete all related data
    final pedidos = await _pedidoRepository.findByUsuarioId(uid);
    for (final pedido in pedidos) {
      await deletePedidoWithDependencies(pedido.identificadorPedido);
    }
    
    // Delete the user
    await _usuarioRepository.delete(uid);
  }

  // ==================== PEDIDO OPERATIONS ====================

  /// Create a complete pedido with prescription and medications
  @Deprecated('Use createPedido with existing prescripcionId instead - medications are now in subcollections')
  Future<void> createUserWithPedidoAndPrescripcion({
    required UserModel usuario,
    required Pedido pedido,
    required Prescripcion prescripcion,
    required List<Medicamento> medicamentos,
  }) async {
    throw Exception('DEPRECATED: Use createPedido with existing prescripcionId instead - medications are now in subcollections');
  }

  /// Get all pedidos for a user with complete information
  Future<List<Pedido>> getUserPedidos(String usuarioId) async {
    return await _pedidoRepository.findByUsuarioId(usuarioId);
  }

  /// Get pedido with complete information (prescription and medications)
  Future<Pedido?> getPedidoComplete(String identificadorPedido) async {
    return await _pedidoRepository.read(identificadorPedido);
  }

  /// Update pedido delivery status
  Future<void> updatePedidoStatus(String identificadorPedido, bool entregado) async {
    await _pedidoRepository.updateEntregado(identificadorPedido, entregado);
  }

  /// Delete pedido with all dependencies
  Future<void> deletePedidoWithDependencies(String identificadorPedido) async {
    await _pedidoRepository.delete(identificadorPedido);
  }

  /// Get pending pedidos (not delivered)
  Future<List<Pedido>> getPendingPedidos() async {
    return await _pedidoRepository.findByEntregado(false);
  }

  /// Get delivered pedidos
  Future<List<Pedido>> getDeliveredPedidos() async {
    return await _pedidoRepository.findByEntregado(true);
  }

  // ==================== PRESCRIPTION OPERATIONS ====================

  /// Create prescription with medications
  @Deprecated('Medications are now in subcollections - use prescription creation only')
  Future<void> createPrescripcionWithMedicamentos({
    required Prescripcion prescripcion,
    required List<Medicamento> medicamentos,
  }) async {
    throw Exception('DEPRECATED: Medications are now in subcollections - use prescription creation only');
  }

  /// Get prescription by doctor
  Future<List<Prescripcion>> getPrescripcionesByDoctor(String doctor) async {
    return await _prescripcionRepository.findByRecetadoPor(doctor);
  }

  /// Update prescription (e.g., to deactivate after order creation)
  Future<void> updatePrescripcion(Prescripcion prescripcion, {required String userId}) async {
    try {
      // Update in the user's prescriptions subcollection
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcion.id)
          .update(prescripcion.toMap());
    } catch (e) {
      throw Exception('Error updating prescription: $e');
    }
  }

  // ==================== MEDICATION OPERATIONS ====================

  /// Get medications available at physical points (pharmacies)
Future<List<Map<String, dynamic>>> getMedicamentosDisponiblesEnPuntosFisicos({
  String? puntoFisicoId,
  bool? esRestringido,
  String? tipo,
}) async {
  List<Map<String, dynamic>> medicamentosConDetalles = [];

  if (puntoFisicoId != null) {
    print('🔍 [Facade] Fetching inventory for punto fisico: $puntoFisicoId');
    
    // 🔹 Fetch inventory from subcollection approach (as seeded)
    try {
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('puntosFisicos')
          .doc(puntoFisicoId)
          .collection('inventario')
          .get();

      print('🔍 [Facade] Found ${inventorySnapshot.docs.length} items in inventory subcollection');

      for (final doc in inventorySnapshot.docs) {
        final inventoryData = doc.data();
        
        print('🔍 [Facade] Processing inventory item:');
        print('   - doc.id (medicamentoId): ${doc.id}');
        print('   - inventoryData: $inventoryData');
        
        // Only include items with stock
        final stock = inventoryData['stock'] ?? 0;
        if (stock <= 0) {
          print('   ⏩ Skipping - no stock (stock: $stock)');
          continue;
        }

        // The document ID in the inventory subcollection IS the medication ID from the global collection
        // Try to fetch full details from global medicamentos collection
        String medDescripcion = 'Medicamento disponible en farmacia';
        String medTipo = 'medicamento';
        
        try {
          print('   🔍 Fetching medication details from global collection with id: ${doc.id}');
          final medicamento = await _medicamentoRepository.read(doc.id);
          
          if (medicamento != null) {
            print('   ✅ Found medication in global collection:');
            print('      - nombre: ${medicamento.nombre}');
            print('      - descripcion: ${medicamento.descripcion}');
            print('      - presentacion: ${medicamento.presentacion}');
            
            medDescripcion = medicamento.descripcion.isNotEmpty 
                ? medicamento.descripcion 
                : 'Sin descripción disponible';
            medTipo = medicamento.presentacion.isNotEmpty
                ? medicamento.presentacion
                : 'medicamento';
          } else {
            print('   ❌ Medication NOT found in global collection with id: ${doc.id}');
          }
        } catch (e) {
          print('   ❌ Error fetching medication details for ${doc.id}: $e');
        }

        // Apply filters if provided (after fetching full data)
        if (esRestringido != null) {
          // MedicamentoGlobal doesn't have esRestringido field, skip this filter
          print('   ⏩ Skipping - esRestringido filter applied');
          continue;
        }
        if (tipo != null && medTipo.toLowerCase() != tipo.toLowerCase()) {
          // Filter by type/presentacion if specified
          print('   ⏩ Skipping - tipo filter mismatch (expected: $tipo, got: $medTipo)');
          continue;
        }

        final medicamentoMap = {
          'id': doc.id,
          'nombre': inventoryData['nombre'] ?? 'Sin nombre',
          'descripcion': medDescripcion,
          'tipo': medTipo,
          'cantidad': stock,
          'precio': (inventoryData['precioUnidad'] ?? 0) / 100.0, // Convert cents to currency
        };
        
        print('   ✅ Adding medication to list:');
        print('      - id: ${medicamentoMap['id']}');
        print('      - nombre: ${medicamentoMap['nombre']}');
        print('      - descripcion: ${medicamentoMap['descripcion']}');
        print('      - tipo: ${medicamentoMap['tipo']}');
        
        medicamentosConDetalles.add(medicamentoMap);
      }
      
      print('🔍 [Facade] Total medications with details: ${medicamentosConDetalles.length}');
    } catch (e) {
      print('❌ [Facade] Error fetching inventory for punto fisico $puntoFisicoId: $e');
    }
  } else {
    // 🔹 Fetch from all pharmacies - this is more complex with subcollections
    // For now, return empty list when no specific punto fisico is provided
    print('Fetching from all pharmacies not implemented with subcollection approach');
  }

  return medicamentosConDetalles;
}

  /// Add medication to pharmacy (establish availability) - DEPRECATED in UML
  @Deprecated('Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly')
  Future<void> addMedicamentoToPuntoPisico(String medicamentoId, String puntoFisicoId) async {
    throw Exception('DEPRECATED: Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly');
  }

  /// Remove medication from pharmacy - DEPRECATED in UML
  @Deprecated('Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly')
  Future<void> removeMedicamentoFromPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    throw Exception('DEPRECATED: Use new UML (0..*:1) relationship - update medicamento.puntoFisicoId directly');
  }

  /// Get restricted medications
  @Deprecated('MedicamentoGlobal model does not have esRestringido field')
  Future<List<Medicamento>> getRestrictedMedicamentos() async {
    throw Exception('DEPRECATED: MedicamentoGlobal model does not have esRestringido field');
  }

  /// Get medications by type (deprecated - use getMedicamentosByPresentacion)
  @Deprecated('Use getMedicamentosByPresentacion instead - MedicamentoGlobal uses presentacion field')
  Future<List<Medicamento>> getMedicamentosByTipo(String tipo) async {
    throw Exception('DEPRECATED: Use getMedicamentosByPresentacion instead');
  }

  /// Get medications by presentacion
  Future<List<MedicamentoGlobal>> getMedicamentosByPresentacion(String presentacion) async {
    return await _medicamentoRepository.findByPresentacion(presentacion);
  }

  /// Get medication by ID from the global medicamentos collection
  Future<MedicamentoGlobal?> getMedicamentoById(String id) async {
    return await _medicamentoRepository.read(id);
  }

  // ==================== PHARMACY OPERATIONS ====================

  /// Get nearby pharmacies
  Future<List<PuntoFisico>> getNearbyPharmacies({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    return await _puntoFisicoRepository.findNearby(latitude, longitude, radiusKm);
  }

  /// Search pharmacies by name or address
  Future<List<PuntoFisico>> searchPharmacies(String query) async {
    return await _puntoFisicoRepository.search(query);
  }

  /// Get pharmacies by chain
  Future<List<PuntoFisico>> getPharmaciesByChain(String cadena) async {
    return await _puntoFisicoRepository.findByCadena(cadena);
  }

  /// Get all pharmacies
  Future<List<PuntoFisico>> getAllPharmacies() async {
    return await _puntoFisicoRepository.readAll();
  }

  /// Create new pharmacy
  Future<void> createPharmacy(PuntoFisico puntoFisico) async {
    await _puntoFisicoRepository.create(puntoFisico);
  }

  // ==================== COMPLEX BUSINESS OPERATIONS ====================

  /// Get complete pharmacy information with available medications
  Future<Map<String, dynamic>> getPharmacyWithMedicamentos(String puntoFisicoId) async {
    final pharmacy = await _puntoFisicoRepository.read(puntoFisicoId);
    
    // Get medicamentos available at this pharmacy via many-to-many relationship
    final medicamentoIds = await _medicamentoPuntoFisicoRepository.getMedicamentosAtPuntoFisico(puntoFisicoId);
    List<MedicamentoGlobal> medications = [];
    for (String medId in medicamentoIds) {
      final med = await _medicamentoRepository.read(medId);
      if (med != null) {
        medications.add(med);
      }
    }
    
    return {
      'pharmacy': pharmacy,
      'medications': medications,
      'totalMedications': medications.length,
    };
  }

  /// Get medication availability (now supports multiple pharmacies per UML)
  Future<Map<String, dynamic>> getMedicamentoAvailability(String medicamentoId) async {
    final medicamento = await _medicamentoRepository.read(medicamentoId);
    
    if (medicamento == null) {
      throw Exception('Medication not found');
    }

    // Get all punto fisicos where this medicamento is available
    final puntoFisicoIds = await _medicamentoPuntoFisicoRepository.getPuntosFisicosForMedicamento(medicamentoId);
    List<Map<String, dynamic>> availability = [];
    
    for (String puntoId in puntoFisicoIds) {
      final puntoFisico = await _puntoFisicoRepository.read(puntoId);
      final relationship = await _medicamentoPuntoFisicoRepository.findByMedicamentoAndPuntoFisico(medicamentoId, puntoId);
      
      if (puntoFisico != null && relationship != null) {
        availability.add({
          'puntoFisico': puntoFisico,
          'cantidad': relationship.cantidad,
          'fechaActualizacion': relationship.fechaActualizacion,
        });
      }
    }
    
    return {
      'medicamento': medicamento,
      'availability': availability,
    };
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics(String usuarioId) async {
    final user = await _usuarioRepository.read(usuarioId);
    final pedidos = await _pedidoRepository.findByUsuarioId(usuarioId);
    
    final deliveredPedidos = pedidos.where((p) => p.entregado).length;
    final pendingPedidos = pedidos.where((p) => !p.entregado).length;

    return {
      'user': user,
      'totalPedidos': pedidos.length,
      'deliveredPedidos': deliveredPedidos,
      'pendingPedidos': pendingPedidos,
      'pedidos': pedidos,
    };
  }

  /// Search medications by name across all pharmacies
  Future<List<Map<String, dynamic>>> searchMedicamentosWithAvailability(String query) async {
    final allMedicamentos = await _medicamentoRepository.readAll();
    
    final filteredMedicamentos = allMedicamentos
        .where((m) => m.nombre.toLowerCase().contains(query.toLowerCase()))
        .toList();

    List<Map<String, dynamic>> results = [];
    
    for (final medicamento in filteredMedicamentos) {
      // Get all puntos fisicos where this medicamento is available
      final puntoFisicoIds = await _medicamentoPuntoFisicoRepository.getPuntosFisicosForMedicamento(medicamento.id);
      
      List<Map<String, dynamic>> availability = [];
      for (String puntoId in puntoFisicoIds) {
        final puntoFisico = await _puntoFisicoRepository.read(puntoId);
        final relationship = await _medicamentoPuntoFisicoRepository.findByMedicamentoAndPuntoFisico(medicamento.id, puntoId);
        
        if (puntoFisico != null && relationship != null) {
          availability.add({
            'puntoFisico': puntoFisico,
            'cantidad': relationship.cantidad,
          });
        }
      }
      
      results.add({
        'medicamento': medicamento,
        'availability': availability,
        'presentacion': medicamento.presentacion,
        'laboratorio': medicamento.laboratorio,
      });
    }

    return results;
  }

  // ==================== STREAM OPERATIONS ====================

  /// Stream user pedidos in real-time
  Stream<List<Pedido>> streamUserPedidos(String usuarioId) {
    return _pedidoRepository.streamPedidosByUsuario(usuarioId);
  }

  /// Stream user information in real-time
  Stream<UserModel?> streamUser(String uid) {
    return _usuarioRepository.streamUser(uid);
  }

  /// Stream all pharmacies in real-time
  Stream<List<PuntoFisico>> streamAllPharmacies() {
    return _puntoFisicoRepository.streamAllPuntosFisicos();
  }

  /// Stream specific pedido in real-time
  Stream<Pedido?> streamPedido(String identificadorPedido) {
    return _pedidoRepository.streamPedido(identificadorPedido);
  }

  // ==================== UTILITY METHODS ====================

  /// Check if user exists
  Future<bool> userExists(String uid) async {
    return await _usuarioRepository.exists(uid);
  }

  /// Check if pedido exists
  Future<bool> pedidoExists(String identificadorPedido) async {
    return await _pedidoRepository.exists(identificadorPedido);
  }

  /// Check if pharmacy exists
  Future<bool> pharmacyExists(String id) async {
    return await _puntoFisicoRepository.exists(id);
  }

  /// Check if medication exists
  Future<bool> medicamentoExists(String id) async {
    return await _medicamentoRepository.exists(id);
  }

  // ==================== UML RELATIONSHIP METHODS ====================

  /// UML: Usuario (1) —— (0..*) Prescripcion
  Future<List<Prescripcion>> getUserPrescripciones(String userId) async {
    return await _prescripcionRepository.findByUserId(userId);
  }

  /// Get only active prescriptions for a user
  Future<List<Prescripcion>> getActiveUserPrescripciones(String userId) async {
    return await _prescripcionRepository.findActiveByUserId(userId);
  }

  /// Stream version of getUserPrescripciones
  Stream<List<Prescripcion>> streamUserPrescripciones(String userId) {
    return _prescripcionRepository.streamByUserId(userId);
  }

  /// Stream only active prescriptions for a user (for real-time updates)
  Stream<List<Prescripcion>> streamActiveUserPrescripciones(String userId) {
    return _prescripcionRepository.streamActiveByUserId(userId);
  }

  /// UML: Pedido (1) —— (1) Prescripcion
  Future<Prescripcion?> getPrescripcionDePedido(String pedidoId) async {
    return await _prescripcionRepository.findByPedidoId(pedidoId);
  }

  /// UML: Prescripcion (1) —— (1..*) Medicamento  
  /// NOTE: Medicamentos are now in subcollections, this method returns empty list for backward compatibility
  @Deprecated('Medicamentos are now stored in subcollections. Use new subcollection-based queries.')
  Future<List<Medicamento>> getMedicamentosDePrescripcion(String prescripcionId) async {
    // Medicamentos are now in subcollections, return empty list for backward compatibility
    return <Medicamento>[];
  }

  /// Stream version of getMedicamentosDePrescripcion
  /// NOTE: Medicamentos are now in subcollections, this method returns empty stream for backward compatibility
  @Deprecated('Medicamentos are now stored in subcollections. Use new subcollection-based queries.')
  Stream<List<Medicamento>> streamMedicamentosDePrescripcion(String prescripcionId) {
    // Medicamentos are now in subcollections, return empty stream for backward compatibility
    return Stream.value(<Medicamento>[]);
  }

  /// UML: Medicamento (0..*) —— (*) PuntoFisico (now many-to-many)
  Future<List<MedicamentoGlobal>> getPuntoInventory(String puntoId) async {
    // Get medicamento IDs available at this punto fisico
    final medicamentoIds = await _medicamentoPuntoFisicoRepository.getMedicamentosAtPuntoFisico(puntoId);
    List<MedicamentoGlobal> medicamentos = [];
    
    for (String medId in medicamentoIds) {
      final med = await _medicamentoRepository.read(medId);
      if (med != null) {
        medicamentos.add(med);
      }
    }
    
    return medicamentos;
  }

  /// Get medicamentos by type (UML generalization)
  @Deprecated('Use getMedicamentosByPresentacion instead - MedicamentoGlobal uses presentacion field')
  Future<List<Medicamento>> getMedicamentosByTipoUML(String tipo) async {
    throw Exception('DEPRECATED: Use getMedicamentosByPresentacion instead - MedicamentoGlobal uses presentacion field');
  }

  /// Helper: Get distinct puntos fisicos for a user (via prescripciones → medicamentos → MedicamentoPuntoFisico)
  Future<List<String>> getDistinctPuntosByUser(String userId) async {
    // Get user's prescripciones
    final prescripciones = await _prescripcionRepository.findByUserId(userId);
    
    Set<String> distinctPuntos = <String>{};
    
    for (var prescripcion in prescripciones) {
      for (var medicamento in prescripcion.medicamentos) {
        // Get puntos fisicos where this medicamento is available
        final puntoIds = await _medicamentoPuntoFisicoRepository.getPuntosFisicosForMedicamento(medicamento.id);
        distinctPuntos.addAll(puntoIds);
      }
    }
    
    return distinctPuntos.toList();
  }

  // ==================== MANY-TO-MANY RELATIONSHIP OPERATIONS ====================
  
  /// Add or update stock for a medicamento at a specific punto fisico
  Future<void> addMedicamentoToPuntoFisico(String medicamentoId, String puntoFisicoId, int cantidad) async {
    await _medicamentoPuntoFisicoRepository.addOrUpdateStock(medicamentoId, puntoFisicoId, cantidad);
  }
  
  /// Remove medicamento from a punto fisico
  Future<void> removeMedicamentoFromPharmacy(String medicamentoId, String puntoFisicoId) async {
    await _medicamentoPuntoFisicoRepository.delete('${medicamentoId}_$puntoFisicoId');
  }
  
  /// Update stock quantity for a medicamento at a punto fisico
  Future<void> updateMedicamentoStock(String medicamentoId, String puntoFisicoId, int cantidad) async {
    await _medicamentoPuntoFisicoRepository.updateCantidad(medicamentoId, puntoFisicoId, cantidad);
  }
  
  /// Get stock information for a medicamento at a specific punto fisico
  Future<int?> getMedicamentoStock(String medicamentoId, String puntoFisicoId) async {
    final relationship = await _medicamentoPuntoFisicoRepository.findByMedicamentoAndPuntoFisico(medicamentoId, puntoFisicoId);
    return relationship?.cantidad;
  }
  
  /// Create a pedido with existing prescription (DOES NOT create new prescriptions)
  /// Updated to work with subcollection approach: usuarios/{userId}/pedidos
  Future<void> createPedido(Pedido pedido, {required String userId}) async {
    print('🔍 [AppRepositoryFacade] Starting pedido creation - ID: ${pedido.id}, User: $userId');
    
    // Validate required fields
    if (pedido.prescripcionId.isEmpty) {
      throw Exception('prescripcionId cannot be empty - must link to existing prescription');
    }
    if (userId.isEmpty) {
      throw Exception('userId is required');
    }
    if (pedido.puntoFisicoId.isEmpty) {
      throw Exception('puntoFisicoId is required');
    }
    
    // Additional validation for the new required fields
    if (pedido.direccionEntrega.isEmpty) {
      throw Exception('direccionEntrega cannot be empty');
    }
    
    print('🔍 [AppRepositoryFacade] Validating pedido data - estado: ${pedido.estado}, tipoEntrega: ${pedido.tipoEntrega}');

    // Verify the prescription exists in the user's subcollection
    try {
      print('🔍 [AppRepositoryFacade] Verifying prescription exists: usuarios/$userId/prescripciones/${pedido.prescripcionId}');
      final prescriptionDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(pedido.prescripcionId)
          .get();
          
      if (!prescriptionDoc.exists) {
        throw Exception('Prescription with id ${pedido.prescripcionId} does not exist for user $userId');
      }
      print('✅ [AppRepositoryFacade] Prescription verified successfully');
    } catch (e) {
      print('❌ [AppRepositoryFacade] Error verifying prescription: $e');
      throw Exception('Error verifying prescription: $e');
    }

    // Create the pedido in the user's subcollection
    try {
      print('🔍 [AppRepositoryFacade] Saving pedido to Firestore: usuarios/$userId/pedidos/${pedido.id}');
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('pedidos')
          .doc(pedido.id)
          .set(pedido.toMap());
      print('✅ [AppRepositoryFacade] Pedido successfully saved to Firestore with estado: ${pedido.estado}');
    } catch (e) {
      print('❌ [AppRepositoryFacade] Error creating pedido in Firestore: $e');
      throw Exception('Error creating pedido: $e');
    }
  }

  /// Create a complete pedido (order) with prescription, medicamentos, and punto fisico assignment
  /// @deprecated Use createPedido instead to avoid prescription duplication
  @Deprecated('Use createPedido with existing prescripcionId to avoid creating duplicate prescriptions')
  Future<void> createCompletePedido({
    required Pedido pedido,
    required Prescripcion prescripcion,
    required String puntoFisicoId,
  }) async {
    // Ensure pedido has the punto fisico assigned
    final updatedPedido = pedido.copyWith(puntoFisicoId: puntoFisicoId);
    
    // Create the pedido first
    await _pedidoRepository.create(updatedPedido);
    
    // Create a new prescription specifically for this pedido with a unique ID
    final newPrescripcionId = '${updatedPedido.identificadorPedido}_prescription';
    final newPrescripcion = prescripcion.copyWith(
      id: newPrescripcionId,
    );
    
    // Create the prescription with embedded medicamentos
    await _prescripcionRepository.create(newPrescripcion);
    
    // Ensure all medicamentos are available at the assigned punto fisico
    for (var medicamento in prescripcion.medicamentos) {
      final stockExists = await _medicamentoPuntoFisicoRepository.exists(medicamento.id, puntoFisicoId);
      if (!stockExists) {
        // Add medicamento to punto fisico with default stock
        await _medicamentoPuntoFisicoRepository.addOrUpdateStock(medicamento.id, puntoFisicoId, 10);
      }
    }
  }

  // TODO: If migrating from old many-to-many medicamento-punto relationship,
  // use the following query to find orphaned join table records:
  // SELECT * FROM medicamento_puntos mp 
  // LEFT JOIN medicamentos m ON mp.medicamento_id = m.id 
  // WHERE m.punto_fisico_id != mp.punto_fisico_id;
}