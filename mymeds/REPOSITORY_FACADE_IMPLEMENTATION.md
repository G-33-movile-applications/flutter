# Repository and Façade Design Patterns Implementation

## 📋 Overview

This document describes the complete implementation of the **Repository** and **Façade** design patterns for the MyMeds Flutter application. The implementation provides a clean, maintainable, and scalable architecture for data access and business operations.

## 🏗️ Architecture Overview

```
UI Layer (Screens/Widgets)
         ↓
Façade Layer (AppRepositoryFacade)
         ↓
Repository Layer (Individual Repositories)
         ↓
Data Layer (Firebase Firestore)
```

### Design Patterns Implemented

1. **Repository Pattern**: Encapsulates data access logic and provides a uniform interface for data operations
2. **Façade Pattern**: Provides a simplified interface to complex subsystems (multiple repositories)
3. **Dependency Injection**: Allows for flexible testing and decoupling

## 📁 File Structure

```
lib/
├── models/
│   ├── user_model.dart          # User entity (already existed)
│   ├── pedido.dart              # Order entity
│   ├── prescripcion.dart        # Prescription entity
│   ├── medicamento.dart         # Medication entity (with specializations)
│   └── punto_fisico.dart        # Physical point (pharmacy) entity
├── repositories/
│   ├── usuario_repository.dart      # User data access
│   ├── pedido_repository.dart       # Order data access
│   ├── prescripcion_repository.dart # Prescription data access
│   ├── medicamento_repository.dart  # Medication data access
│   └── punto_fisico_repository.dart # Pharmacy data access
├── facade/
│   └── app_repository_facade.dart   # Unified interface
└── examples/
    └── repository_facade_example.dart # Usage examples
```

## 🎯 Entity Models

### Core Entities and Relationships

1. **Usuario** (User)
   - Properties: uid, fullName, email, phoneNumber, address, city, department, zipCode, createdAt
   - Relationships: Has many Pedidos

2. **Pedido** (Order)
   - Properties: identificadorPedido, fechaEntrega, fechaDespacho, direccionEntrega, entregado, usuarioId
   - Relationships: Belongs to Usuario, Has one Prescripcion

3. **Prescripcion** (Prescription)
   - Properties: id, fechaEmision, recetadoPor, pedidoId
   - Relationships: Belongs to Pedido, Contains many Medicamentos

4. **Medicamento** (Medication) - Abstract base class with specializations:
   - Properties: id, nombre, descripcion, esRestringido, prescripcionId
   - Specializations:
     - **Pastilla**: dosisMg, cantidad
     - **Unguento**: concentracion, cantidadEnvases
     - **Inyectable**: concentracion, volumenPorUnidad, cantidadUnidades
     - **Jarabe**: cantidadBotellas, mlPorBotella
   - Relationships: Belongs to Prescripcion, Available at many PuntosFisicos

5. **PuntoFisico** (Physical Point/Pharmacy)
   - Properties: id, latitud, longitud, direccion, cadena, nombre
   - Relationships: Has many Medicamentos available

## 🔧 Repository Classes

Each repository implements standard CRUD operations and relationship-specific methods:

### Common Repository Methods
- `create(entity)`: Create new entity
- `read(id)`: Read entity by ID
- `readAll()`: Read all entities
- `update(entity)`: Update existing entity
- `delete(id)`: Delete entity
- `exists(id)`: Check if entity exists
- `stream*()`: Real-time data streams

### Relationship-Specific Methods
- **UsuarioRepository**: `findByEmail()`, `streamUser()`
- **PedidoRepository**: `findByUsuarioId()`, `findByEntregado()`, `updateEntregado()`
- **PrescripcionRepository**: `findByPedidoId()`, `findByRecetadoPor()`
- **MedicamentoRepository**: `findByPrescripcionId()`, `findByTipo()`, `findByPuntoFisico()`
- **PuntoFisicoRepository**: `findNearby()`, `findByCadena()`, `search()`

## 🎭 Façade Implementation

The `AppRepositoryFacade` provides simplified methods for complex operations:

### Key Façade Methods

#### User Operations
- `createUser()`, `getUser()`, `getUserByEmail()`, `updateUser()`, `deleteUser()`

#### Order Operations
- `createUserWithPedidoAndPrescripcion()`: Creates complete order with all dependencies
- `getUserPedidos()`, `updatePedidoStatus()`, `getPendingPedidos()`

#### Medication Operations
- `getMedicamentosDisponiblesEnPuntosFisicos()`: Get medications with pharmacy availability
- `addMedicamentoToPuntoPisico()`, `getRestrictedMedicamentos()`

#### Pharmacy Operations
- `getNearbyPharmacies()`: Find pharmacies within radius
- `searchPharmacies()`, `getPharmaciesByChain()`

#### Complex Business Operations
- `getPharmacyWithMedicamentos()`: Complete pharmacy information
- `getMedicamentoAvailability()`: Medication availability across pharmacies
- `getUserStatistics()`: User order statistics
- `searchMedicamentosWithAvailability()`: Search with availability info

#### Real-time Operations
- `streamUserPedidos()`, `streamUser()`, `streamAllPharmacies()`

## 🚀 Usage Examples

### Basic Usage

```dart
// Initialize façade
final facade = AppRepositoryFacade();

// Create complete order
await facade.createUserWithPedidoAndPrescripcion(
  usuario: user,
  pedido: pedido,
  prescripcion: prescripcion,
  medicamentos: medicamentos,
);

// Find nearby pharmacies
final nearbyPharmacies = await facade.getNearbyPharmacies(
  latitude: 4.7110,
  longitude: -74.0721,
  radiusKm: 5.0,
);

// Get available medications
final medications = await facade.getMedicamentosDisponiblesEnPuntosFisicos();
```

### Real-time Streams

```dart
// Listen to user orders
facade.streamUserPedidos(userId).listen((pedidos) {
  print('User has ${pedidos.length} orders');
});

// Listen to user changes
facade.streamUser(userId).listen((user) {
  if (user != null) {
    print('User updated: ${user.fullName}');
  }
});
```

### Complex Operations

```dart
// Get user statistics
final stats = await facade.getUserStatistics(userId);
print('Total orders: ${stats['totalPedidos']}');
print('Delivered: ${stats['deliveredPedidos']}');
print('Pending: ${stats['pendingPedidos']}');

// Search medications with availability
final results = await facade.searchMedicamentosWithAvailability('ibuprofeno');
for (final result in results) {
  final medicamento = result['medicamento'] as Medicamento;
  final availableAt = result['availableAt'] as List<PuntoFisico>;
  print('${medicamento.nombre} - Available at ${availableAt.length} pharmacies');
}
```

## 🔒 Firestore Collections Structure

The implementation uses the following Firestore collections:

```
usuarios/                    # User documents
  {uid}/                    # Document ID = Firebase Auth UID
    uid: string
    fullName: string
    email: string
    phoneNumber: string
    address: string
    city: string
    department: string
    zipCode: string
    createdAt: timestamp

pedidos/                     # Order documents
  {identificadorPedido}/    # Document ID = Order ID
    identificadorPedido: string
    fechaEntrega: timestamp
    fechaDespacho: timestamp
    direccionEntrega: string
    entregado: boolean
    usuarioId: string       # Reference to user

prescripciones/             # Prescription documents
  {id}/                     # Document ID = Prescription ID
    id: string
    fechaEmision: timestamp
    recetadoPor: string
    pedidoId: string       # Reference to order

medicamentos/               # Medication documents
  {id}/                     # Document ID = Medication ID
    id: string
    nombre: string
    descripcion: string
    esRestringido: boolean
    prescripcionId: string  # Reference to prescription
    tipo: string           # 'pastilla', 'unguento', 'inyectable', 'jarabe'
    # Specific fields based on type
    dosisMg: number        # For pastilla
    cantidad: number       # For pastilla
    concentracion: string  # For unguento, inyectable
    # ... other type-specific fields

puntos_fisicos/            # Pharmacy documents
  {id}/                    # Document ID = Pharmacy ID
    id: string
    latitud: number
    longitud: number
    direccion: string
    cadena: string
    nombre: string

medicamento_puntos/        # Many-to-many relationship
  {medicamentoId_puntoFisicoId}/  # Composite key
    medicamentoId: string
    puntoFisicoId: string
    createdAt: timestamp
```

## ✅ Benefits of This Implementation

### Repository Pattern Benefits
1. **Separation of Concerns**: Data access logic is separated from business logic
2. **Testability**: Easy to mock repositories for unit testing
3. **Consistency**: Uniform interface for all data operations
4. **Flexibility**: Easy to switch data sources (e.g., from Firestore to another database)

### Façade Pattern Benefits
1. **Simplified Interface**: Complex operations are exposed as simple methods
2. **Reduced Coupling**: UI layer doesn't need to know about multiple repositories
3. **Business Logic Centralization**: Complex business operations are centralized
4. **Easier Maintenance**: Changes to repository interactions are contained in the façade

### Combined Benefits
1. **Clean Architecture**: Clear separation between layers
2. **Scalability**: Easy to add new entities and operations
3. **Maintainability**: Well-organized, easy to understand code
4. **Reusability**: Repositories can be reused across different parts of the application

## 🧪 Testing Strategy

### Repository Testing
```dart
// Mock Firestore for repository tests
test('UsuarioRepository creates user successfully', () async {
  final mockFirestore = MockFirebaseFirestore();
  final repository = UsuarioRepository(firestore: mockFirestore);
  
  await repository.create(testUser);
  
  verify(mockFirestore.collection('usuarios').doc(testUser.uid).set(testUser.toMap()));
});
```

### Façade Testing
```dart
// Mock repositories for façade tests
test('AppRepositoryFacade creates complete order', () async {
  final mockUserRepo = MockUsuarioRepository();
  final mockPedidoRepo = MockPedidoRepository();
  final facade = AppRepositoryFacade(
    usuarioRepository: mockUserRepo,
    pedidoRepository: mockPedidoRepo,
  );
  
  await facade.createUserWithPedidoAndPrescripcion(/* ... */);
  
  verify(mockUserRepo.create(testUser));
  verify(mockPedidoRepo.create(testPedido));
});
```

## 🔄 Future Enhancements

1. **Caching Layer**: Add local caching for frequently accessed data
2. **Offline Support**: Implement offline-first architecture
3. **Data Validation**: Add comprehensive data validation
4. **Audit Trail**: Track data changes for compliance
5. **Performance Optimization**: Implement pagination and lazy loading
6. **Error Handling**: Enhanced error handling and retry mechanisms

## 📚 Integration with Existing Code

To integrate with your existing authentication system:

```dart
// In your auth service
class AuthService {
  static final AppRepositoryFacade _facade = AppRepositoryFacade();
  
  static Future<AuthResult> registerWithEmailAndPassword({
    // ... existing parameters
  }) async {
    // ... existing auth logic
    
    if (result.success) {
      // Create user document using façade
      final userModel = UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email,
        // ... other fields
      );
      
      await _facade.createUser(userModel);
    }
    
    return result;
  }
}
```

This implementation provides a robust, scalable foundation for your MyMeds application's data layer while maintaining clean architecture principles and best practices.