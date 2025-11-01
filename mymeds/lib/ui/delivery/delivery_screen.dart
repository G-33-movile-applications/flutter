import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/punto_fisico.dart';
import '../../models/prescripcion.dart';
import '../../models/pedido.dart';
import '../../services/user_session.dart';
import '../../facade/app_repository_facade.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';
import '../../utils/address_validator.dart';

/// Enum to represent different address selection types
enum AddressType {
  home('Dirección de casa', Icons.home),
  current('Ubicación actual', Icons.my_location),
  other('Otra dirección', Icons.location_on);

  const AddressType(this.label, this.icon);
  final String label;
  final IconData icon;
}

class DeliveryScreen extends StatefulWidget {
  final PuntoFisico? pharmacy;
  final Prescripcion? prescripcion; // Optional: pre-selected prescription
  
  const DeliveryScreen({super.key, this.pharmacy, this.prescripcion});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final AppRepositoryFacade _facade = AppRepositoryFacade();
  final LocationService _locationService = LocationService();
  
  List<Prescripcion> _prescripciones = [];
  Prescripcion? _selectedPrescripcion;
  PuntoFisico? _selectedPharmacy; // Store pharmacy (from widget or selected later)
  bool _isPickup = true; // true for pickup, false for delivery
  bool _isLoading = true;
  bool _isCreatingPedido = false;
  String? _errorMessage;
  bool _hasInitializedDeliveryMode = false; // Track if we've set initial delivery mode
  bool _hasPrescriptions = false; // Track if user has any prescriptions
  
  // Address-related state variables
  final TextEditingController _addressController = TextEditingController();
  AddressType _selectedAddressType = AddressType.home;
  UserModel? _currentUser;
  String? _homeAddress;
  String? _currentLocationAddress;
  bool _isLoadingCurrentLocation = false;
  bool _isLoadingHomeAddress = false;
  String? _addressValidationError;

  @override
  void initState() {
    super.initState();
    _selectedPharmacy = widget.pharmacy; // Initialize with passed pharmacy
    _selectedPrescripcion = widget.prescripcion; // Initialize with passed prescription
    _loadUserPrescripciones();
    _loadUserData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Load active prescriptions for the user
  Future<void> _loadUserPrescripciones() async {
    try {
      final userId = UserSession().currentUser.value?.uid;
      print('🔍 Loading active prescriptions for user: $userId');
      
      if (userId != null && userId.isNotEmpty) {
        // Fetch only active prescriptions
        final prescripciones = await _facade.getActiveUserPrescripciones(userId);
        print('✅ Loaded ${prescripciones.length} active prescriptions');
        
        setState(() {
          _prescripciones = prescripciones;
          _hasPrescriptions = prescripciones.isNotEmpty;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Usuario no autenticado o ID de usuario vacío';
          _hasPrescriptions = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading prescriptions: $e');
      setState(() {
        _errorMessage = 'Error cargando prescripciones: $e';
        _hasPrescriptions = false;
        _isLoading = false;
      });
    }
  }

  /// Load user data and initialize address information
  Future<void> _loadUserData() async {
    try {
      _currentUser = UserSession().currentUser.value;
      if (_currentUser != null) {
        await _loadHomeAddress();
        _initializeDeliveryModeFromPreferences();
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  /// Initialize delivery mode based on user preferences
  void _initializeDeliveryModeFromPreferences() {
    if (_hasInitializedDeliveryMode || _currentUser?.preferencias == null) {
      return;
    }

    final preferredMode = _currentUser!.preferencias!.modoEntregaPreferido;
    final shouldUseDelivery = preferredMode == 'domicilio';
    
    setState(() {
      _isPickup = !shouldUseDelivery;
      _hasInitializedDeliveryMode = true;
    });

    // If switching to delivery mode and we have home address, populate it
    if (shouldUseDelivery && _homeAddress != null && _selectedAddressType == AddressType.home) {
      _addressController.text = _homeAddress!;
      _logAddressSelection('home', _homeAddress!);
    }

    print('🔧 Initialized delivery mode from user preference: $preferredMode (isPickup: $_isPickup)');
  }

  /// Load the user's home address from their profile
  Future<void> _loadHomeAddress() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoadingHomeAddress = true;
    });

    try {
      // Get complete home address from user model
      final address = _currentUser!.direccion;
      final city = _currentUser!.city;
      final department = _currentUser!.department;
      
      // Build complete address string
      List<String> addressParts = [];
      if (address.isNotEmpty) addressParts.add(address);
      if (city.isNotEmpty) addressParts.add(city);
      if (department.isNotEmpty) addressParts.add(department);
      
      _homeAddress = addressParts.isNotEmpty ? addressParts.join(', ') : null;
      
      // Clean the address to remove duplicates
      if (_homeAddress != null) {
        _homeAddress = AddressValidator.cleanAddress(_homeAddress!);
      }
      
      // If home address is available and delivery is selected, auto-fill it
      if (_homeAddress != null && !_isPickup && _selectedAddressType == AddressType.home) {
        _addressController.text = _homeAddress!;
        _logAddressSelection('home', _homeAddress!);
      }
      
      print('🏠 Home address loaded: $_homeAddress');
    } catch (e) {
      print('❌ Error loading home address: $e');
      _homeAddress = null;
    } finally {
      setState(() {
        _isLoadingHomeAddress = false;
      });
    }
  }

  /// Load the user's current location and convert to address
  /// Uses the same location method as MapScreen for accuracy
  Future<void> _loadCurrentLocationAddress() async {
    setState(() {
      _isLoadingCurrentLocation = true;
      _addressValidationError = null; // Clear any previous errors
    });

    try {
      // Get current position using the same method as MapScreen
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw Exception('No se pudo obtener la ubicación actual');
      }

      print('📍 Current position: ${position.latitude}, ${position.longitude}');

      // Convert coordinates to address
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (address == null) {
        throw Exception('No se pudo convertir las coordenadas a dirección');
      }

      _currentLocationAddress = address;
      
      // Clean the address to remove duplicates and format properly
      if (_currentLocationAddress != null) {
        _currentLocationAddress = AddressValidator.cleanAddress(_currentLocationAddress!);
      }
      
      // If current location is available and selected, auto-fill it
      if (_currentLocationAddress != null && 
          !_isPickup && 
          _selectedAddressType == AddressType.current) {
        _addressController.text = _currentLocationAddress!;
        _logAddressSelection('current', _currentLocationAddress!);
      }
      
      print('📍 Current location address loaded: $_currentLocationAddress');
    } catch (e) {
      print('❌ Error loading current location address: $e');
      _currentLocationAddress = null;
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error obteniendo ubicación: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
      }
    }
  }

  /// Handle address type selection changes
  void _onAddressTypeChanged(AddressType? newType) {
    if (newType == null) return;

    setState(() {
      _selectedAddressType = newType;
      _addressValidationError = null; // Clear validation error when switching types
    });

    switch (newType) {
      case AddressType.home:
        if (_homeAddress != null) {
          _addressController.text = _homeAddress!;
          _logAddressSelection('home', _homeAddress!);
        } else {
          _loadHomeAddress();
        }
        break;
      case AddressType.current:
        if (_currentLocationAddress != null) {
          _addressController.text = _currentLocationAddress!;
          _logAddressSelection('current', _currentLocationAddress!);
        } else {
          _loadCurrentLocationAddress();
        }
        break;
      case AddressType.other:
        _addressController.clear();
        break;
    }
  }

  /// Log address selection for analytics
  void _logAddressSelection(String type, String address) {
    print('📊 Address selection analytics: Type=$type, Address=${address.length > 50 ? '${address.substring(0, 50)}...' : address}');
    // TODO: In production, send this to your analytics service
    // AnalyticsService.logEvent('address_selected', {
    //   'type': type,
    //   'address_length': address.length,
    //   'pharmacy_id': widget.pharmacy?.id,
    // });
  }

  /// Load address suggestions when delivery option is selected
  Future<void> _loadAddressSuggestions() async {
    // Load home address if not already loaded
    if (_homeAddress == null && _currentUser != null) {
      await _loadHomeAddress();
    }
    
    // Load current location if not already loaded and user prefers current location
    if (_currentLocationAddress == null && _selectedAddressType == AddressType.current) {
      await _loadCurrentLocationAddress();
    }
  }

  /// Validates the current address in the text field
  void _validateCurrentAddress() {
    final address = _addressController.text.trim();
    final validationResult = AddressValidator.validateAddress(address);
    
    setState(() {
      _addressValidationError = validationResult;
    });
  }

  /// Handles address input changes and validates in real-time
  void _onAddressChanged(String value) {
    // Validate address for manual input or edited auto-filled addresses
    if (_selectedAddressType == AddressType.other || 
        (_selectedAddressType != AddressType.other && value.trim() != _getAddressDataForType(_selectedAddressType)?.trim())) {
      _validateCurrentAddress();
      _logAddressSelection('manual_edit', value);
    } else {
      // Clear validation error for pre-filled addresses
      setState(() {
        _addressValidationError = null;
      });
    }
  }

  /// Get address data for a specific address type
  String? _getAddressDataForType(AddressType type) {
    switch (type) {
      case AddressType.home:
        return _homeAddress;
      case AddressType.current:
        return _currentLocationAddress;
      case AddressType.other:
        return null;
    }
  }

  /// Get loading state for a specific address type
  bool _getLoadingStateForType(AddressType type) {
    switch (type) {
      case AddressType.home:
        return _isLoadingHomeAddress;
      case AddressType.current:
        return _isLoadingCurrentLocation;
      case AddressType.other:
        return false;
    }
  }

  /// Get helper text based on the selected address type
  String _getHelperTextForAddressType() {
    // If there's a validation error, don't show the helper text as it's already shown as errorText
    if (_addressValidationError != null) {
      return '';
    }

    switch (_selectedAddressType) {
      case AddressType.home:
      case AddressType.current:
      case AddressType.other:
        return 'Asegúrate de incluir todos los detalles necesarios para la entrega';
    }
  }

  /// Handle delivery mode changes and auto-populate address if needed
  void _onDeliveryModeChanged(bool isPickup) {
    setState(() {
      _isPickup = isPickup;
      _addressValidationError = null; // Clear validation error when switching modes
    });

    // If switching to delivery mode and we have home address selected, populate it immediately
    if (!isPickup && _selectedAddressType == AddressType.home && _homeAddress != null) {
      _addressController.text = _homeAddress!;
      _logAddressSelection('home', _homeAddress!);
    }
    // If switching to delivery mode and current location is selected, load it
    else if (!isPickup && _selectedAddressType == AddressType.current) {
      _loadCurrentLocationAddress();
    }
    // Clear address field when switching to pickup mode
    else if (isPickup) {
      _addressController.clear();
    }

    // Load address suggestions for delivery mode
    if (!isPickup) {
      _loadAddressSuggestions();
    }
  }

  /// Check if the current user has any active prescriptions available
  /// This method validates prescription availability for delivery creation
  Future<bool> userHasPrescriptions() async {
    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null || userId.isEmpty) {
        print('❌ [Prescription Check] User not authenticated');
        return false;
      }

      final prescripciones = await _facade.getActiveUserPrescripciones(userId);
      final hasValidPrescriptions = prescripciones.isNotEmpty;
      
      print('🔍 [Prescription Check] User $userId has ${prescripciones.length} active prescriptions');
      return hasValidPrescriptions;
    } catch (e) {
      print('❌ [Prescription Check] Error checking prescriptions: $e');
      return false;
    }
  }

  /// Widget displayed when user has no prescriptions
  /// Shows informative message and redirect button to upload screen
  Widget _buildNoPrescriptionsWidget() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'No hay prescripciones disponibles',
              style: GoogleFonts.poetsenOne(
                textStyle: theme.textTheme.headlineSmall,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Message
            Text(
              'No puedes crear un pedido porque no tienes ninguna prescripción subida o associada a tu cuenta.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Upload button
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to upload prescription screen
                Navigator.pushNamed(context, '/upload');
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir Prescripción'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget containing the main delivery form
  /// Displayed when user has valid prescriptions
  Widget _buildDeliveryForm() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pharmacy info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farmacia Seleccionada',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPharmacy!.nombre,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _selectedPharmacy!.direccion,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prescription selection
          Text(
            'Selecciona una prescripción:',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Show prescription lock indicator if preselected
          if (widget.prescripcion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Prescripción preseleccionada',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: DropdownButtonFormField<Prescripcion>(
              value: _selectedPrescripcion,
              isExpanded: true, // Fix overflow issue
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Selecciona una prescripción',
                filled: widget.prescripcion != null,
                fillColor: widget.prescripcion != null 
                    ? Colors.grey.withValues(alpha: 0.1) 
                    : null,
              ),
              items: _prescripciones.map((prescripcion) {
                return DropdownMenuItem(
                  value: prescripcion,
                  child: Text(
                    '${prescripcion.medico} - ${prescripcion.diagnostico}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.prescripcion != null 
                          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
              onChanged: widget.prescripcion != null ? null : (value) {
                setState(() {
                  _selectedPrescripcion = value;
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // Delivery mode selection
          Text(
            'Método de entrega:',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Pickup option
          RadioListTile<bool>(
            title: const Text('Recoger en farmacia'),
            subtitle: const Text('Recoge tu pedido directamente en la farmacia'),
            value: true,
            groupValue: _isPickup,
            onChanged: (value) => _onDeliveryModeChanged(value ?? true),
          ),
          
          // Delivery option
          RadioListTile<bool>(
            title: const Text('Entrega a domicilio'),
            subtitle: const Text('Recibe tu pedido en tu dirección'),
            value: false,
            groupValue: _isPickup,
            onChanged: (value) => _onDeliveryModeChanged(value ?? false),
          ),

          // Address input for delivery
          if (!_isPickup) ...[
            const SizedBox(height: 16),
            Text(
              'Dirección de entrega:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Address type selection
            DropdownButtonFormField<AddressType>(
              value: _selectedAddressType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tipo de dirección',
              ),
              items: AddressType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(type.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onAddressTypeChanged,
            ),
            const SizedBox(height: 12),
            
            // Address input field
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Dirección',
                hintText: 'Ingresa tu dirección completa',
                errorText: _addressValidationError,
                helperText: _getHelperTextForAddressType(),
                suffixIcon: _getLoadingStateForType(_selectedAddressType)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              onChanged: _onAddressChanged,
              maxLines: 2,
            ),
          ],

          const SizedBox(height: 32),

          // Create order button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedPrescripcion != null && !_isCreatingPedido)
                  ? _createPedido
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isCreatingPedido
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creando pedido...'),
                      ],
                    )
                  : Text(
                      _isPickup ? 'Crear pedido (Recoger)' : 'Crear pedido (Domicilio)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPedido() async {
    // Get user ID first for use in error handling
    final userId = UserSession().currentUser.value?.uid;
    
    // Validation - ensure prescription is selected
    if (_selectedPrescripcion == null || _selectedPharmacy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedPrescripcion == null 
              ? 'Selecciona una prescripción' 
              : 'Selecciona una farmacia'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation - ensure prescription has valid ID
    if (_selectedPrescripcion!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La prescripción seleccionada no tiene un ID válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation - ensure delivery address for home delivery
    if (!_isPickup) {
      final address = _addressController.text.trim();
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa la dirección de entrega'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate address format
      final addressValidationError = AddressValidator.validateAddress(address);
      if (addressValidationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dirección inválida: $addressValidationError'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Additional validation to ensure all required fields for Firestore
    final deliveryAddress = _isPickup ? _selectedPharmacy!.direccion : _addressController.text.trim();
    if (deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Dirección de entrega vacía'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPharmacy!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: ID de farmacia vacío'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate dates
    final now = DateTime.now();
    final fechaDespacho = now;
    final fechaEntrega = now.add(const Duration(days: 1));
    
    if (fechaEntrega.isBefore(fechaDespacho)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Fecha de entrega debe ser posterior a fecha de despacho'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingPedido = true;
    });

    try {
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Validation - ensure pharmacy ID is not empty
      if (_selectedPharmacy!.id.isEmpty) {
        throw Exception('La farmacia seleccionada no tiene un ID válido');
      }

      // Generate a unique pedido ID with prefix using UUID
      const uuid = Uuid();
      final pedidoId = 'ped_${uuid.v4().replaceAll('-', '').substring(0, 16)}';
      
      // Create pedido with reference to existing prescription - NO PRESCRIPTION CREATION
      final pedido = Pedido(
        id: pedidoId,
        prescripcionId: _selectedPrescripcion!.id,
        puntoFisicoId: _selectedPharmacy!.id,
        tipoEntrega: _isPickup ? 'recogida' : 'domicilio',
        direccionEntrega: _isPickup ? _selectedPharmacy!.direccion : _addressController.text.trim(),
        estado: 'en_proceso', // Set as required: "en_proceso" for confirmed orders
        fechaPedido: fechaDespacho,
        fechaEntrega: fechaEntrega,
      );

      print('🔄 Creating pedido with ID: $pedidoId for user: $userId');
      print('📦 Pedido details: tipoEntrega=${pedido.tipoEntrega}, estado=${pedido.estado}, prescripcionId=${pedido.prescripcionId}');

      // 🌐 Use offline-aware method that handles connectivity
      final result = await _facade.createPedidoWithSync(
        pedido: pedido,
        userId: userId,
        prescripcionId: _selectedPrescripcion!.id,
        prescripcionUpdates: {'activa': false}, // Deactivate prescription after order
      );
      
      final success = result['success'] as bool? ?? false;
      final isOffline = result['isOffline'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Unknown result';
      
      if (!success) {
        // Handle error case
        throw Exception(message);
      }
      
      print(isOffline 
        ? '📴 Pedido queued offline: $message'
        : '✅ Pedido created online: usuarios/$userId/pedidos/$pedidoId');

      if (mounted) {
        // Show appropriate message based on connectivity
        final snackBarColor = isOffline ? Colors.orange : Colors.green;
        final snackBarIcon = isOffline ? Icons.cloud_off : Icons.check_circle;
        final snackBarMessage = isOffline 
          ? '📴 Tu pedido se enviará cuando tengas conexión' 
          : '✅ Pedido creado exitosamente';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(snackBarIcon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(snackBarMessage)),
              ],
            ),
            backgroundColor: snackBarColor,
            duration: Duration(seconds: isOffline ? 6 : 3),
          ),
        );

        // If pickup selected and ONLINE, open Google Maps with directions
        if (_isPickup && !isOffline) {
          // Wrap in try-catch to prevent crash if Maps fails
          try {
            await _openGoogleMapsDirections();
          } catch (e) {
            print('⚠️ Warning: Could not open Google Maps: $e');
            // Don't throw - order was created successfully
          }
        }

        // Navigate away after showing message
        if (mounted) {
          Navigator.popUntil(context, (route) => route.settings.name == '/map' || route.isFirst);
        }
      }
    } catch (e) {
      print('❌ Error creating pedido: $e');
      print('🔍 Error context: userId=$userId, prescripcionId=${_selectedPrescripcion?.id}, pharmacyId=${_selectedPharmacy?.id}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creando pedido: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPedido = false;
        });
      }
    }
  }

  Future<void> _openGoogleMapsDirections() async {
    if (_selectedPharmacy == null) return;
    
    final lat = _selectedPharmacy!.latitud;
    final lng = _selectedPharmacy!.longitud;
    
    // Google Maps directions URL
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir Google Maps'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error abriendo Google Maps: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedPharmacy == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "DELIVERY",
            style: GoogleFonts.poetsenOne(
              textStyle: theme.textTheme.headlineMedium,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: theme.colorScheme.primary,
        ),
        body: const Center(
          child: Text('No se seleccionó farmacia'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "DELIVERY - ${_selectedPharmacy!.nombre}",
          style: GoogleFonts.poetsenOne(
            textStyle: theme.textTheme.headlineMedium,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          await _loadUserPrescripciones();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : !_hasPrescriptions
                  ? _buildNoPrescriptionsWidget() // Show no prescriptions message
                  : _buildDeliveryForm(), // Show normal delivery form
    );
  }
}
