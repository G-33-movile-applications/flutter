import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/medicamento_global.dart';
import '../models/punto_fisico.dart';
import '../models/prescripcion.dart';
import '../models/medicamento_prescripcion.dart';
import '../models/pedido.dart';
import '../models/medicamento_pedido.dart';
import '../models/inventario_medicamento.dart';
import '../models/medicamento_usuario.dart';
import '../models/user_preferencias.dart';

class FirebaseSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seeds all collections with sample data
  Future<void> seedAll() async {
    print('🌱 Starting Firebase seeding...');
    
    try {
      // 1. Seed global medication catalog
      await _seedMedicamentosGlobales();
      
      // 2. Seed physical points (pharmacies)
      await _seedPuntosFisicos();
      
      // 3. Seed pharmacy inventories
      await _seedInventarios();
      
      // 4. Seed users
      await _seedUsuarios();
      
      // 5. Seed user prescriptions and medications
      await _seedPrescripciones();
      
      // 6. Seed user orders
      await _seedPedidos();
      
      // 7. Seed user personal medications
      await _seedMedicamentosUsuario();
      
      print('✅ Firebase seeding completed successfully!');
    } catch (e) {
      print('❌ Seeding failed: $e');
      rethrow;
    }
  }

  /// 1. Seed global medication catalog
  Future<void> _seedMedicamentosGlobales() async {
    print('📊 Seeding medicamentosGlobales...');
    
    final medicamentos = [
      MedicamentoGlobal(
        id: 'med_001',
        nombre: 'Losartán 50mg',
        principioActivo: 'Losartán',
        presentacion: 'Tableta',
        laboratorio: 'Laboratorios XYZ',
        descripcion: 'Antihipertensivo que actúa bloqueando los receptores de angiotensina II',
        contraindicaciones: ['Embarazo', 'Hipersensibilidad al losartán'],
        imagenUrl: 'https://example.com/losartan.png',
      ),
      MedicamentoGlobal(
        id: 'med_002',
        nombre: 'Ibuprofeno 600mg',
        principioActivo: 'Ibuprofeno',
        presentacion: 'Tableta',
        laboratorio: 'Farmacéutica ABC',
        descripcion: 'Antiinflamatorio no esteroideo (AINE) para dolor y fiebre',
        contraindicaciones: ['Úlcera péptica activa', 'Insuficiencia renal severa'],
        imagenUrl: 'https://example.com/ibuprofeno.png',
      ),
      MedicamentoGlobal(
        id: 'med_003',
        nombre: 'Amoxicilina 500mg',
        principioActivo: 'Amoxicilina',
        presentacion: 'Cápsula',
        laboratorio: 'Antibióticos SA',
        descripcion: 'Antibiótico betalactámico de amplio espectro',
        contraindicaciones: ['Alergia a penicilinas', 'Mononucleosis infecciosa'],
        imagenUrl: 'https://example.com/amoxicilina.png',
      ),
    ];

    for (final medicamento in medicamentos) {
      await _firestore
          .collection('medicamentosGlobales')
          .doc(medicamento.id)
          .set(medicamento.toMap());
    }
    
    print('   ✅ Created ${medicamentos.length} global medications');
  }

  /// 2. Seed physical points (pharmacies)
  Future<void> _seedPuntosFisicos() async {
    print('🏪 Seeding puntosFisicos...');
    
    final puntosFisicos = [
      PuntoFisico(
        id: 'farm_001',
        nombre: 'Farmacia Central',
        direccion: 'Cra 7 #12-34, Bogotá',
        telefono: '6011234567',
        ubicacion: const GeoPoint(4.6123, -74.0721),
        horario: 'Lunes a Sábado 8am - 8pm',
      ),
      PuntoFisico(
        id: 'farm_002',
        nombre: 'Drogas La Rebaja',
        direccion: 'Calle 72 #10-15, Bogotá',
        telefono: '6019876543',
        ubicacion: const GeoPoint(4.6510, -74.0587),
        horario: '24 horas',
      ),
      PuntoFisico(
        id: 'farm_003',
        nombre: 'Cruz Verde',
        direccion: 'Av. Boyacá #145-30, Bogotá',
        telefono: '6015555555',
        ubicacion: const GeoPoint(4.6890, -74.1050),
        horario: 'Lunes a Domingo 7am - 10pm',
      ),
    ];

    for (final punto in puntosFisicos) {
      await _firestore
          .collection('puntosFisicos')
          .doc(punto.id)
          .set(punto.toMap());
    }
    
    print('   ✅ Created ${puntosFisicos.length} pharmacies');
  }

  /// 3. Seed pharmacy inventories
  Future<void> _seedInventarios() async {
    print('📦 Seeding inventarios...');
    
    final inventarios = [
      // Farmacia Central inventory
      InventarioMedicamento(
        id: 'med_001',
        medicamentoRef: '/medicamentosGlobales/med_001',
        nombre: 'Losartán 50mg',
        stock: 150,
        precioUnidad: 1200, // $12.00 in cents
        lote: 'L123A',
        fechaVencimiento: DateTime(2026, 3, 1),
        proveedor: 'Laboratorios XYZ',
        fechaIngreso: DateTime(2025, 9, 30),
      ),
      InventarioMedicamento(
        id: 'med_002',
        medicamentoRef: '/medicamentosGlobales/med_002',
        nombre: 'Ibuprofeno 600mg',
        stock: 200,
        precioUnidad: 800, // $8.00 in cents
        lote: 'L456B',
        fechaVencimiento: DateTime(2026, 6, 15),
        proveedor: 'Farmacéutica ABC',
        fechaIngreso: DateTime(2025, 10, 1),
      ),
      // Add more inventory items for other pharmacies...
    ];

    // Seed inventory for each pharmacy
    final pharmacyIds = ['farm_001', 'farm_002', 'farm_003'];
    
    for (final farmId in pharmacyIds) {
      for (final inventario in inventarios) {
        await _firestore
            .collection('puntosFisicos')
            .doc(farmId)
            .collection('inventario')
            .doc(inventario.id)
            .set(inventario.toMap());
      }
    }
    
    print('   ✅ Created inventory for ${pharmacyIds.length} pharmacies');
  }

  /// 4. Seed users
  Future<void> _seedUsuarios() async {
    print('👥 Seeding usuarios...');
    
    final usuarios = [
      UserModel(
        uid: 'user_001',
        nombre: 'Pablo Martínez',
        email: 'pablomartinez@gmail.com',
        telefono: '3101234567',
        direccion: 'Cra 10 #45-12, Bogotá',
        preferencias: const UserPreferencias(
          modoEntregaPreferido: 'domicilio',
          notificaciones: true,
        ),
        createdAt: DateTime(2025, 1, 15),
      ),
      UserModel(
        uid: 'user_002',
        nombre: 'María García',
        email: 'maria.garcia@example.com',
        telefono: '3209876543',
        direccion: 'Calle 85 #20-30, Bogotá',
        preferencias: const UserPreferencias(
          modoEntregaPreferido: 'recogida',
          notificaciones: false,
        ),
        createdAt: DateTime(2025, 2, 20),
      ),
    ];

    for (final usuario in usuarios) {
      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .set(usuario.toMap());
    }
    
    print('   ✅ Created ${usuarios.length} users');
  }

  /// 5. Seed user prescriptions and medications
  Future<void> _seedPrescripciones() async {
    print('📋 Seeding prescripciones...');
    
    final prescripciones = [
      {
        'userId': 'user_001',
        'prescripcion': Prescripcion(
          id: 'pres_001',
          fechaCreacion: DateTime(2025, 10, 14),
          diagnostico: 'Hipertensión',
          medico: 'Dra. Ana Gómez',
          activa: true,
        ),
        'medicamentos': [
          MedicamentoPrescripcion(
            id: 'med_001',
            medicamentoRef: '/medicamentosGlobales/med_001',
            nombre: 'Losartán 50mg',
            dosisMg: 50,
            frecuenciaHoras: 12,
            duracionDias: 30,
            fechaInicio: DateTime(2025, 10, 14),
            fechaFin: DateTime(2025, 11, 13),
            observaciones: 'Tomar después del desayuno',
            activo: true,
            userId: 'user_001',
            prescripcionId: 'pres_001',
          ),
        ],
      },
      // Add more prescriptions...
    ];

    for (final prescData in prescripciones) {
      final userId = prescData['userId'] as String;
      final prescripcion = prescData['prescripcion'] as Prescripcion;
      final medicamentos = prescData['medicamentos'] as List<MedicamentoPrescripcion>;
      
      // Create prescription
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .doc(prescripcion.id)
          .set(prescripcion.toMap());
      
      // Create prescription medications
      for (final medicamento in medicamentos) {
        await _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('prescripciones')
            .doc(prescripcion.id)
            .collection('medicamentos')
            .doc(medicamento.id)
            .set(medicamento.toMap());
      }
    }
    
    print('   ✅ Created ${prescripciones.length} prescriptions with medications');
  }

  /// 6. Seed user orders
  Future<void> _seedPedidos() async {
    print('🛒 Seeding pedidos...');
    
    final pedidos = [
      {
        'userId': 'user_001',
        'pedido': Pedido(
          id: 'ped_001',
          prescripcionId: 'pres_001',
          puntoFisicoId: 'farm_001',
          tipoEntrega: 'domicilio',
          direccionEntrega: 'Cra 10 #45-12, Bogotá',
          estado: 'en_proceso',
          fechaPedido: DateTime(2025, 10, 15),
          fechaEntrega: DateTime(2025, 10, 16),
        ),
        'medicamentos': [
          MedicamentoPedido(
            id: 'med_001',
            medicamentoRef: '/medicamentosGlobales/med_001',
            nombre: 'Losartán 50mg',
            cantidad: 10,
            precioUnitario: 1200,
            total: 12000,
            userId: 'user_001',
            pedidoId: 'ped_001',
          ),
        ],
      },
    ];

    for (final pedidoData in pedidos) {
      final userId = pedidoData['userId'] as String;
      final pedido = pedidoData['pedido'] as Pedido;
      final medicamentos = pedidoData['medicamentos'] as List<MedicamentoPedido>;
      
      // Create order
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('pedidos')
          .doc(pedido.id)
          .set(pedido.toMap());
      
      // Create order medications
      for (final medicamento in medicamentos) {
        await _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('pedidos')
            .doc(pedido.id)
            .collection('medicamentos')
            .doc(medicamento.id)
            .set(medicamento.toMap());
      }
    }
    
    print('   ✅ Created ${pedidos.length} orders with medications');
  }

  /// 7. Seed user personal medications
  Future<void> _seedMedicamentosUsuario() async {
    print('💊 Seeding medicamentosUsuario...');
    
    final medicamentosUsuario = [
      {
        'userId': 'user_001',
        'medicamento': MedicamentoUsuario(
          id: 'med_001',
          medicamentoRef: '/medicamentosGlobales/med_001',
          nombre: 'Losartán 50mg',
          dosisMg: 50,
          frecuenciaHoras: 12,
          activo: true,
          prescripcionId: 'pres_001',
          fechaInicio: DateTime(2025, 10, 14),
          fechaFin: DateTime(2025, 11, 13),
        ),
      },
    ];

    for (final medData in medicamentosUsuario) {
      final userId = medData['userId'] as String;
      final medicamento = medData['medicamento'] as MedicamentoUsuario;
      
      await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('medicamentosUsuario')
          .doc(medicamento.id)
          .set(medicamento.toMap());
    }
    
    print('   ✅ Created user medications for ${medicamentosUsuario.length} entries');
  }
}