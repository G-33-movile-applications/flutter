import 'package:flutter/material.dart';
import '../facade/app_repository_facade.dart';
import '../models/user_model.dart';
import '../models/pedido.dart';
import '../models/prescripcion.dart';
import '../models/medicamento.dart';
import '../models/punto_fisico.dart';

/// Example class demonstrating how to use the AppRepositoryFacade
/// This shows the Repository and Façade patterns in action
class RepositoryFacadeExample {
  final AppRepositoryFacade _facade = AppRepositoryFacade();

  /// Example: Create a complete user with order and prescription
  Future<void> createCompleteUserOrder() async {
    try {
      // Create user
      final user = UserModel(
        uid: 'user123',
        fullName: 'Juan Pérez',
        email: 'juan.perez@email.com',
        phoneNumber: '+57 300 123 4567',
        address: 'Calle 123 #45-67',
        city: 'Bogotá',
        department: 'Cundinamarca',
        zipCode: '110111',
        createdAt: DateTime.now(),
      );

      // Create pedido
      final pedido = Pedido(
        identificadorPedido: 'PED001',
        fechaEntrega: DateTime.now().add(const Duration(days: 2)),
        fechaDespacho: DateTime.now().add(const Duration(days: 1)),
        direccionEntrega: 'Calle 123 #45-67, Bogotá',
        entregado: false,
        usuarioId: 'user123',
      );

      // Create prescription
      final prescripcion = Prescripcion(
        id: 'PRESC001',
        fechaEmision: DateTime.now(),
        recetadoPor: 'Dr. María García',
        pedidoId: 'PED001',
      );

      // Create medications
      final medicamentos = [
        Pastilla(
          id: 'MED001',
          nombre: 'Ibuprofeno',
          descripcion: 'Antiinflamatorio',
          esRestringido: false,
          prescripcionId: 'PRESC001',
          dosisMg: 400.0,
          cantidad: 20,
        ),
        Jarabe(
          id: 'MED002',
          nombre: 'Amoxicilina',
          descripcion: 'Antibiótico',
          esRestringido: true,
          prescripcionId: 'PRESC001',
          cantidadBotellas: 1,
          mlPorBotella: 250.0,
        ),
      ];

      // Use façade to create everything in a single operation
      await _facade.createUserWithPedidoAndPrescripcion(
        usuario: user,
        pedido: pedido,
        prescripcion: prescripcion,
        medicamentos: medicamentos,
      );

      debugPrint('✅ Complete user order created successfully');
    } catch (e) {
      debugPrint('❌ Error creating user order: $e');
    }
  }

  /// Example: Find medications available at nearby pharmacies
  Future<void> findNearbyMedicationsExample() async {
    try {
      // Get nearby pharmacies (example coordinates for Bogotá)
      final nearbyPharmacies = await _facade.getNearbyPharmacies(
        latitude: 4.7110,
        longitude: -74.0721,
        radiusKm: 5.0,
      );

      debugPrint('📍 Found ${nearbyPharmacies.length} nearby pharmacies');

      // Get medications available at these pharmacies
      final medicamentosDisponibles = await _facade
          .getMedicamentosDisponiblesEnPuntosFisicos();

      debugPrint('💊 Found ${medicamentosDisponibles.length} available medications');

      // Filter only non-restricted medications
      final nonRestrictedMeds = await _facade
          .getMedicamentosDisponiblesEnPuntosFisicos(esRestringido: false);

      debugPrint('🔓 Found ${nonRestrictedMeds.length} non-restricted medications');
    } catch (e) {
      debugPrint('❌ Error finding nearby medications: $e');
    }
  }

  /// Example: Update pedido status and get user statistics
  Future<void> updatePedidoAndGetStatsExample() async {
    try {
      const String pedidoId = 'PED001';
      const String userId = 'user123';

      // Update pedido status to delivered
      await _facade.updatePedidoStatus(pedidoId, true);
      debugPrint('📦 Pedido $pedidoId marked as delivered');

      // Get user statistics
      final userStats = await _facade.getUserStatistics(userId);
      
      debugPrint('📊 User Statistics:');
      debugPrint('   - Total pedidos: ${userStats['totalPedidos']}');
      debugPrint('   - Delivered: ${userStats['deliveredPedidos']}');
      debugPrint('   - Pending: ${userStats['pendingPedidos']}');
    } catch (e) {
      debugPrint('❌ Error updating pedido status: $e');
    }
  }

  /// Example: Search medications with availability information
  Future<void> searchMedicationsExample() async {
    try {
      const String searchQuery = 'ibuprofeno';

      final results = await _facade.searchMedicamentosWithAvailability(searchQuery);

      debugPrint('🔍 Search results for "$searchQuery":');
      
      for (final result in results) {
        final medicamento = result['medicamento'] as Medicamento;
        final availableAt = result['availableAt'] as List<PuntoFisico>;
        final isRestricted = result['isRestricted'] as bool;
        final type = result['type'] as String;

        debugPrint('   - ${medicamento.nombre}');
        debugPrint('     Type: $type');
        debugPrint('     Restricted: ${isRestricted ? 'Yes' : 'No'}');
        debugPrint('     Available at ${availableAt.length} pharmacies');
      }
    } catch (e) {
      debugPrint('❌ Error searching medications: $e');
    }
  }

  /// Example: Get complete pharmacy information
  Future<void> getPharmacyInfoExample() async {
    try {
      // First, create a sample pharmacy
      final pharmacy = PuntoFisico(
        id: 'PHARM001',
        latitud: 4.7110,
        longitud: -74.0721,
        direccion: 'Avenida El Dorado #123-45',
        cadena: 'FarmaPlus',
        nombre: 'FarmaPlus El Dorado',
      );

      await _facade.createPharmacy(pharmacy);

      // Get complete pharmacy information
      final pharmacyInfo = await _facade.getPharmacyWithMedicamentos('PHARM001');

      final pharmacyData = pharmacyInfo['pharmacy'] as PuntoFisico?;
      final totalMeds = pharmacyInfo['totalMedications'] as int;
      final restrictedMeds = pharmacyInfo['restrictedMedications'] as int;

      debugPrint('🏥 Pharmacy Information:');
      debugPrint('   - Name: ${pharmacyData?.nombre}');
      debugPrint('   - Chain: ${pharmacyData?.cadena}');
      debugPrint('   - Address: ${pharmacyData?.direccion}');
      debugPrint('   - Total medications: $totalMeds');
      debugPrint('   - Restricted medications: $restrictedMeds');
    } catch (e) {
      debugPrint('❌ Error getting pharmacy info: $e');
    }
  }

  /// Example: Use real-time streams
  void setupRealTimeListenersExample() {
    const String userId = 'user123';
    const String pedidoId = 'PED001';

    // Listen to user changes
    _facade.streamUser(userId).listen(
      (user) {
        if (user != null) {
          debugPrint('👤 User updated: ${user.fullName}');
        }
      },
      onError: (error) {
        debugPrint('❌ Error in user stream: $error');
      },
    );

    // Listen to user's pedidos
    _facade.streamUserPedidos(userId).listen(
      (pedidos) {
        debugPrint('📦 User has ${pedidos.length} pedidos');
        final pending = pedidos.where((p) => !p.entregado).length;
        debugPrint('   - ${pedidos.length - pending} delivered, $pending pending');
      },
      onError: (error) {
        debugPrint('❌ Error in pedidos stream: $error');
      },
    );

    // Listen to specific pedido
    _facade.streamPedido(pedidoId).listen(
      (pedido) {
        if (pedido != null) {
          debugPrint('📋 Pedido ${pedido.identificadorPedido} status: ${pedido.entregado ? 'Delivered' : 'Pending'}');
        }
      },
      onError: (error) {
        debugPrint('❌ Error in pedido stream: $error');
      },
    );

    // Listen to all pharmacies
    _facade.streamAllPharmacies().listen(
      (pharmacies) {
        debugPrint('🏥 Total pharmacies: ${pharmacies.length}');
      },
      onError: (error) {
        debugPrint('❌ Error in pharmacies stream: $error');
      },
    );
  }

  /// Run all examples
  Future<void> runAllExamples() async {
    debugPrint('🚀 Starting Repository Façade Examples...\n');

    await createCompleteUserOrder();
    await Future.delayed(const Duration(seconds: 1));

    await findNearbyMedicationsExample();
    await Future.delayed(const Duration(seconds: 1));

    await updatePedidoAndGetStatsExample();
    await Future.delayed(const Duration(seconds: 1));

    await searchMedicationsExample();
    await Future.delayed(const Duration(seconds: 1));

    await getPharmacyInfoExample();
    await Future.delayed(const Duration(seconds: 1));

    setupRealTimeListenersExample();

    debugPrint('\n✅ All examples completed!');
  }
}