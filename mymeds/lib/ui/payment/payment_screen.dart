import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/prescripcion.dart';
import '../../models/punto_fisico.dart';
import '../../services/payment_processing_service.dart';
import '../../services/bill_generator_service.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../repositories/medicamento_prescripcion_repository.dart';
import 'payment_success_screen.dart';

/// Payment Review and Method Selection Screen
/// 
/// Displays:
/// - Prescription details
/// - Medicines list with pricing
/// - Totals (subtotal, delivery, total)
/// - Payment method selector
/// - Pharmacy information
/// - "Proceed to Pay" button
class PaymentScreen extends StatefulWidget {
  final Prescripcion prescription;
  final PuntoFisico pharmacy;
  final bool isPickup; // true for pickup, false for delivery
  final String? deliveryAddress;

  const PaymentScreen({
    super.key,
    required this.prescription,
    required this.pharmacy,
    required this.isPickup,
    this.deliveryAddress,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentProcessingService _paymentService = PaymentProcessingService();
  final BillGeneratorService _billService = BillGeneratorService();
  final MedicamentoPrescripcionRepository _medicamentoRepo = MedicamentoPrescripcionRepository();

  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _medicines = [];
  String? _errorMessage;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'credit',
      'name': 'Tarjeta de Crédito',
      'icon': Icons.credit_card,
      'description': 'Visa, Mastercard, American Express',
    },
    {
      'id': 'debit',
      'name': 'Tarjeta de Débito',
      'icon': Icons.payment,
      'description': 'Tarjetas de débito bancarias',
    },
    {
      'id': 'cash_on_delivery',
      'name': 'Pago Contra Entrega',
      'icon': Icons.local_atm,
      'description': 'Pague al recibir su pedido',
    },
    {
      'id': 'mock',
      'name': 'Pago de Prueba',
      'icon': Icons.developer_mode,
      'description': 'Solo para desarrollo',
    },
  ];

  double get _deliveryFee => widget.isPickup ? 0.0 : 5000.0; // $5,000 COP for delivery

  double get _subtotal {
    return _medicines.fold<double>(
      0.0,
      (sum, med) => sum + ((med['subtotal'] ?? 0) as num).toDouble(),
    );
  }

  double get _total => _subtotal + _deliveryFee;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _initServices();
    await _loadMedicinesWithPricing();
  }

  Future<void> _initServices() async {
    await _paymentService.init();
    await _billService.init();
  }

  /// Load medicines from prescription and add mock pricing
  Future<void> _loadMedicinesWithPricing() async {
    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Load medications from prescription subcollection
      final medicamentos = await _medicamentoRepo.getMedicamentosByPrescripcion(
        userId: userId,
        prescripcionId: widget.prescription.id,
      );

      if (medicamentos.isEmpty) {
        // Show user-friendly dialog instead of throwing error
        if (mounted) {
          _showEmptyPrescriptionDialog();
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Add mock pricing for each medication
      final medicinesWithPricing = medicamentos.map((med) {
        // Mock pricing: $2,000 - $50,000 COP per unit
        final pricePerUnit = 15000.0; // $15,000 COP per medication
        final quantity = 1; // Default quantity
        final subtotal = pricePerUnit * quantity;

        return {
          'medicationId': med.id,
          'medicationName': med.nombre,
          'dosage': '${med.dosisMg} mg',
          'quantity': quantity,
          'pricePerUnit': pricePerUnit,
          'subtotal': subtotal,
        };
      }).toList();

      setState(() {
        _medicines = medicinesWithPricing;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading medicines: $e');
      setState(() {
        _errorMessage = 'Error cargando medicamentos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar y Pagar'),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : _errorMessage != null
              ? _buildErrorScreen()
              : _isProcessing
                  ? _buildProcessingScreen()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPrescriptionCard(theme),
                          const SizedBox(height: 16),
                          _buildMedicinesCard(theme),
                          const SizedBox(height: 16),
                          _buildPharmacyCard(theme),
                          const SizedBox(height: 16),
                          _buildTotalsCard(theme),
                          const SizedBox(height: 16),
                          _buildPaymentMethodSelector(theme),
                          const SizedBox(height: 24),
                          _buildProceedButton(theme),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Cargando información...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Procesando pago...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Por favor espere',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(ThemeData theme) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Prescripción',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow('Médico', widget.prescription.medico),
            _buildInfoRow('Diagnóstico', widget.prescription.diagnostico),
            _buildInfoRow(
              'Fecha',
              dateFormatter.format(widget.prescription.fechaCreacion),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicinesCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Medicamentos (${_medicines.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ..._medicines.map(_buildMedicineItem),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineItem(Map<String, dynamic> medicine) {
    final name = medicine['medicationName'] as String? ?? 'Medicamento';
    final dosage = medicine['dosage'] as String? ?? '';
    final quantity = medicine['quantity'] as int? ?? 0;
    final pricePerUnit = (medicine['pricePerUnit'] ?? 0) as num;
    final subtotal = (medicine['subtotal'] ?? 0) as num;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (dosage.isNotEmpty)
                  Text(
                    dosage,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                Text(
                  'Cantidad: $quantity',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${pricePerUnit.toStringAsFixed(2)} c/u',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '\$${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_pharmacy, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Farmacia',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow('Nombre', widget.pharmacy.nombre),
            _buildInfoRow('Dirección', widget.pharmacy.direccion),
            if (widget.pharmacy.telefono != null && widget.pharmacy.telefono!.isNotEmpty)
              _buildInfoRow('Teléfono', widget.pharmacy.telefono!),
            _buildInfoRow(
              'Tipo de entrega',
              widget.isPickup ? 'Recoger en tienda' : 'Entrega a domicilio',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', _subtotal),
            const SizedBox(height: 8),
            _buildTotalRow('Envío', _deliveryFee),
            const Divider(height: 16),
            _buildTotalRow(
              'TOTAL',
              _total,
              isBold: true,
              fontSize: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: isBold ? AppTheme.primaryColor : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de Pago',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._paymentMethods.map((method) {
          final isSelected = _selectedPaymentMethod == method['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPaymentMethod = method['id'] as String;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryColor.withOpacity(0.1) 
                    : (theme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : (theme.brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    method['icon'] as IconData,
                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppTheme.primaryColor : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          method['description'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProceedButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _selectedPaymentMethod == null || _isProcessing
            ? null
            : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Text(
          'Proceder al Pago (\$${_total.toStringAsFixed(2)})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) {
      _showError('Por favor seleccione un método de pago');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Process payment and create order
      final result = await _paymentService.processPayment(
        userId: userId,
        prescriptionId: widget.prescription.id,
        pharmacyId: widget.pharmacy.id,
        pharmacyName: widget.pharmacy.nombre,
        pharmacyAddress: widget.pharmacy.direccion,
        total: _total,
        deliveryFee: _deliveryFee,
        method: _selectedPaymentMethod!,
        medicines: _medicines,
        deliveryType: widget.isPickup ? 'pickup' : 'home',
        deliveryAddress: widget.deliveryAddress,
      );

      if (result['success'] == true) {
        final orderId = result['orderId'] as String;
        final paymentId = result['paymentId'] as String;
        
        // Get payment for bill generation
        final payment = await _paymentService.getPaymentById(paymentId);
        if (payment == null) {
          throw Exception('Payment not found');
        }
        
        // Generate bill
        final billResult = await _billService.generateBill(
          payment: payment,
          orderDetails: {
            'userName': UserSession().currentUser.value?.nombre ?? 'Usuario',
            'userEmail': UserSession().currentUser.value?.email ?? '',
            'phoneNumber': UserSession().currentUser.value?.telefono ?? '',
            'pharmacyName': widget.pharmacy.nombre,
            'pharmacyAddress': widget.pharmacy.direccion,
            'pharmacyPhone': widget.pharmacy.telefono,
            'items': _medicines,
            'subtotal': _subtotal,
            'deliveryFee': _deliveryFee,
            'totalAmount': _total,
            'orderId': orderId,
          },
        );

        print('✅ Payment processed successfully: Order $orderId, Payment $paymentId');

        // Navigate to success screen
        if (mounted) {
          // Pop all the way back and push success screen
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                orderId: orderId,
                paymentId: paymentId,
                total: _total,
                paymentMethod: _selectedPaymentMethod!,
                prescription: widget.prescription,
                pharmacy: widget.pharmacy,
                billLocalPath: billResult['localPath'] as String?,
              ),
            ),
          );
        }
      } else {
        _showError(result['message'] as String? ?? 'Error al procesar pago');
      }
    } catch (e) {
      print('❌ Error processing payment: $e');
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showEmptyPrescriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Prescripción vacía'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta prescripción no tiene medicamentos asociados.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Por favor, selecciona otra prescripción o agrega medicamentos a esta.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
