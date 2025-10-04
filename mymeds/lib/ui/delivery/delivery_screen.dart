import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/punto_fisico.dart';
import '../../models/prescripcion.dart';
import '../../models/pedido.dart';
import '../../services/user_session.dart';
import '../../facade/app_repository_facade.dart';

class DeliveryScreen extends StatefulWidget {
  final PuntoFisico? pharmacy;
  
  const DeliveryScreen({super.key, this.pharmacy});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final AppRepositoryFacade _facade = AppRepositoryFacade();
  List<Prescripcion> _prescripciones = [];
  Prescripcion? _selectedPrescripcion;
  bool _isPickup = true; // true for pickup, false for delivery
  bool _isLoading = true;
  bool _isCreatingPedido = false;
  String? _errorMessage;
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserPrescripciones();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPrescripciones() async {
    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId != null) {
        final prescripciones = await _facade.getUserPrescripciones(userId);
        setState(() {
          _prescripciones = prescripciones;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Usuario no autenticado';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando prescripciones: $e';
        _isLoading = false;
      });
    }
  }

  String _getRecommendation() {
    final hour = DateTime.now().hour;
    if (8 < hour && hour < 18) {
      return "Recomendación: Recoger en farmacia";
    } else {
      return "Recomendación: Entrega a domicilio";
    }
  }

  Future<void> _createPedido() async {
    // Validation - ensure prescription is selected
    if (_selectedPrescripcion == null || widget.pharmacy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una prescripción'),
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
    if (!_isPickup && _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa la dirección de entrega'),
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
          content: Text('La fecha de entrega debe ser posterior a la fecha de despacho'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingPedido = true;
    });

    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Validation - ensure pharmacy ID is not empty
      if (widget.pharmacy!.id.isEmpty) {
        throw Exception('La farmacia seleccionada no tiene un ID válido');
      }

      // Create pedido with reference to existing prescription - NO PRESCRIPTION CREATION
      final pedido = Pedido(
        identificadorPedido: DateTime.now().millisecondsSinceEpoch.toString(),
        fechaEntrega: fechaEntrega,
        fechaDespacho: fechaDespacho,
        direccionEntrega: _isPickup ? widget.pharmacy!.direccion : _addressController.text.trim(),
        entregado: false,
        entregaEnTienda: _isPickup,
        usuarioId: userId,
        puntoFisicoId: widget.pharmacy!.id,
        prescripcionId: _selectedPrescripcion!.id, // Link to existing prescription
        prescripcion: _selectedPrescripcion, // For in-memory use only
      );

      // Create only the pedido - no prescription duplication
      await _facade.createPedido(pedido);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // If pickup selected, open Google Maps with directions
        if (_isPickup) {
          await _openGoogleMapsDirections();
        }

        // Navigate back to map - use mounted check before navigation
        if (mounted) {
          Navigator.popUntil(context, (route) => route.settings.name == '/map' || route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creando pedido: $e'),
            backgroundColor: Colors.red,
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
    if (widget.pharmacy == null) return;
    
    final lat = widget.pharmacy!.latitud;
    final lng = widget.pharmacy!.longitud;
    
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
    final theme = AppTheme.lightTheme;

    if (widget.pharmacy == null) {
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
          "DELIVERY - ${widget.pharmacy!.nombre}",
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
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
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
                                widget.pharmacy!.nombre,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.pharmacy!.cadena,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.pharmacy!.direccion,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Recommendation
                      Text(
                        _getRecommendation(),
                        style: GoogleFonts.poetsenOne(
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Delivery/Pickup selection
                      Text(
                        'Tipo de entrega:',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Recoger en farmacia'),
                        leading: Radio<bool>(
                          value: true,
                          groupValue: _isPickup,
                          onChanged: (value) {
                            setState(() {
                              _isPickup = value!;
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            _isPickup = true;
                          });
                        },
                      ),
                      ListTile(
                        title: const Text('Entrega a domicilio'),
                        leading: Radio<bool>(
                          value: false,
                          groupValue: _isPickup,
                          onChanged: (value) {
                            setState(() {
                              _isPickup = value!;
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            _isPickup = false;
                          });
                        },
                      ),

                      // Address field for delivery
                      if (!_isPickup) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Dirección de entrega',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.home),
                          ),
                          maxLines: 2,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Prescription selection
                      Text(
                        'Seleccionar prescripción:',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Prescripción",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        value: _selectedPrescripcion == null 
                            ? null 
                            : (_selectedPrescripcion!.id.isEmpty 
                                ? 'prescripcion_${_prescripciones.indexOf(_selectedPrescripcion!)}' 
                                : _selectedPrescripcion!.id),
                        items: _prescripciones.asMap().entries.map((entry) {
                          final index = entry.key;
                          final prescripcion = entry.value;
                          final itemValue = prescripcion.id.isEmpty ? 'prescripcion_$index' : prescripcion.id;
                          return DropdownMenuItem<String>(
                            value: itemValue,
                            child: Text(
                              '${prescripcion.recetadoPor} - ${prescripcion.fechaEmision.day}/${prescripcion.fechaEmision.month}/${prescripcion.fechaEmision.year}',
                            ),
                          );
                        }).toList(),
                        onChanged: (selectedId) {
                          setState(() {
                            if (selectedId != null) {
                              if (selectedId.startsWith('prescripcion_')) {
                                final index = int.parse(selectedId.split('_')[1]);
                                _selectedPrescripcion = _prescripciones[index];
                              } else {
                                _selectedPrescripcion = _prescripciones
                                    .firstWhere((p) => p.id == selectedId);
                              }
                            }
                          });
                        },
                      ),

                      // Show selected prescription medications
                      if (_selectedPrescripcion != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Medicamentos en la prescripción:',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _selectedPrescripcion!.medicamentos.map((med) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.medication, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(med.nombre)),
                                      if (med.esRestringido)
                                        const Icon(Icons.warning, color: Colors.orange, size: 16),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Create order button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isCreatingPedido ? null : _createPedido,
                          child: _isCreatingPedido
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isPickup ? "CONFIRMAR RECOGIDA" : "CONFIRMAR ENTREGA",
                                  style: GoogleFonts.poetsenOne(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
