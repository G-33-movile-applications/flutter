import '../models/user_model.dart';
import '../models/pedido.dart';
import '../models/prescripcion.dart';
import '../models/medicamento.dart';
import '../models/punto_fisico.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/prescripcion_repository.dart';
import '../repositories/medicamento_repository.dart';
import '../repositories/punto_fisico_repository.dart';

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

  // Constructor with optional dependency injection
  AppRepositoryFacade({
    UsuarioRepository? usuarioRepository,
    PedidoRepository? pedidoRepository,
    PrescripcionRepository? prescripcionRepository,
    MedicamentoRepository? medicamentoRepository,
    PuntoFisicoRepository? puntoFisicoRepository,
  })  : _usuarioRepository = usuarioRepository ?? UsuarioRepository(),
        _pedidoRepository = pedidoRepository ?? PedidoRepository(),
        _prescripcionRepository = prescripcionRepository ?? PrescripcionRepository(),
        _medicamentoRepository = medicamentoRepository ?? MedicamentoRepository(),
        _puntoFisicoRepository = puntoFisicoRepository ?? PuntoFisicoRepository();

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
  Future<void> createUserWithPedidoAndPrescripcion({
    required UserModel usuario,
    required Pedido pedido,
    required Prescripcion prescripcion,
    required List<Medicamento> medicamentos,
  }) async {
    try {
      // 1. Create user if doesn't exist
      final existingUser = await _usuarioRepository.read(usuario.uid);
      if (existingUser == null) {
        await _usuarioRepository.create(usuario);
      }

      // 2. Create pedido
      await _pedidoRepository.create(pedido);

      // 3. Create prescription
      await _prescripcionRepository.create(prescripcion);

      // 4. Create medications
      for (final medicamento in medicamentos) {
        await _medicamentoRepository.create(medicamento);
      }
    } catch (e) {
      throw Exception('Error creating user with pedido and prescription: $e');
    }
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
  Future<void> createPrescripcionWithMedicamentos({
    required Prescripcion prescripcion,
    required List<Medicamento> medicamentos,
  }) async {
    try {
      // Create prescription
      await _prescripcionRepository.create(prescripcion);

      // Create medications
      for (final medicamento in medicamentos) {
        await _medicamentoRepository.create(medicamento);
      }
    } catch (e) {
      throw Exception('Error creating prescription with medications: $e');
    }
  }

  /// Get prescription by doctor
  Future<List<Prescripcion>> getPrescripcionesByDoctor(String doctor) async {
    return await _prescripcionRepository.findByRecetadoPor(doctor);
  }

  // ==================== MEDICATION OPERATIONS ====================

  /// Get medications available at physical points (pharmacies)
  Future<List<Medicamento>> getMedicamentosDisponiblesEnPuntosFisicos({
    String? puntoFisicoId,
    bool? esRestringido,
    String? tipo,
  }) async {
    List<Medicamento> medicamentos = [];

    if (puntoFisicoId != null) {
      // Get medications available at specific pharmacy
      medicamentos = await _medicamentoRepository.findByPuntoFisico(puntoFisicoId);
    } else {
      // Get all medications with their available points
      medicamentos = await _medicamentoRepository.readAll();
    }

    // Apply filters
    if (esRestringido != null) {
      medicamentos = medicamentos.where((m) => m.esRestringido == esRestringido).toList();
    }

    if (tipo != null) {
      medicamentos = medicamentos.where((m) => m.toMap()['tipo'] == tipo).toList();
    }

    return medicamentos;
  }

  /// Add medication to pharmacy (establish availability)
  Future<void> addMedicamentoToPuntoPisico(String medicamentoId, String puntoFisicoId) async {
    await _medicamentoRepository.addMedicamentoToPuntoFisico(medicamentoId, puntoFisicoId);
  }

  /// Remove medication from pharmacy
  Future<void> removeMedicamentoFromPuntoFisico(String medicamentoId, String puntoFisicoId) async {
    await _medicamentoRepository.removeMedicamentoFromPuntoFisico(medicamentoId, puntoFisicoId);
  }

  /// Get restricted medications
  Future<List<Medicamento>> getRestrictedMedicamentos() async {
    return await _medicamentoRepository.findByEsRestringido(true);
  }

  /// Get medications by type
  Future<List<Medicamento>> getMedicamentosByTipo(String tipo) async {
    return await _medicamentoRepository.findByTipo(tipo);
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
    final medications = await _medicamentoRepository.findByPuntoFisico(puntoFisicoId);

    return {
      'pharmacy': pharmacy,
      'medications': medications,
      'totalMedications': medications.length,
      'restrictedMedications': medications.where((m) => m.esRestringido).length,
    };
  }

  /// Get medication availability across pharmacies
  Future<Map<String, dynamic>> getMedicamentoAvailability(String medicamentoId) async {
    final medicamento = await _medicamentoRepository.read(medicamentoId);
    
    if (medicamento == null) {
      throw Exception('Medication not found');
    }

    return {
      'medicamento': medicamento,
      'availableAt': medicamento.puntosDisponibles,
      'totalPharmacies': medicamento.puntosDisponibles.length,
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
      results.add({
        'medicamento': medicamento,
        'availableAt': medicamento.puntosDisponibles,
        'isRestricted': medicamento.esRestringido,
        'type': medicamento.toMap()['tipo'],
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
}