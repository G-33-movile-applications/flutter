import 'package:flutter/material.dart';
import '../../models/prescripcion.dart';
import '../../models/punto_fisico.dart';
import '../../services/bill_generator_service.dart';
import '../../theme/app_theme.dart';

/// Payment Success Screen
/// 
/// Displays:
/// - Success animation/checkmark
/// - Order confirmation details
/// - Bill preview thumbnail
/// - Actions: View Bill, Share Bill, Track Order, Done
/// 
/// Features:
/// - Auto-generates bill on entry
/// - Blocks back navigation to payment screen
/// - Works offline (bill already generated locally)
class PaymentSuccessScreen extends StatefulWidget {
  final String orderId;
  final String paymentId;
  final double total;
  final String paymentMethod;
  final Prescripcion prescription;
  final PuntoFisico pharmacy;
  final String? billLocalPath;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
    required this.paymentId,
    required this.total,
    required this.paymentMethod,
    required this.prescription,
    required this.pharmacy,
    this.billLocalPath,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  final BillGeneratorService _billService = BillGeneratorService();
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup success animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Block back navigation
    return WillPopScope(
      onWillPop: () async {
        // Return to home instead of payment screen
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pago Exitoso'),
          centerTitle: true,
          automaticallyImplyLeading: false, // Remove back button
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 32),
              
              // Success animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Success message
                    Text(
                      '¡Pago Exitoso!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Tu pedido ha sido confirmado',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Order details card
                    _buildOrderDetailsCard(theme),
                    
                    const SizedBox(height: 16),
                    
                    // Payment details card
                    _buildPaymentDetailsCard(theme),
                    
                    const SizedBox(height: 16),
                    
                    // Delivery details card
                    _buildDeliveryDetailsCard(theme),
                    
                    const SizedBox(height: 24),
                    
                    // Bill actions
                    if (widget.billLocalPath != null)
                      _buildBillActionsCard(theme),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    _buildActionButtons(theme),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detalles del Pedido',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow('Order ID', widget.orderId),
            _buildInfoRow('Total Pagado', '\$${widget.total.toStringAsFixed(2)}'),
            _buildInfoRow('Método de Pago', _formatPaymentMethod(widget.paymentMethod)),
            _buildInfoRow('Prescripción', widget.prescription.id),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.payment,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pago Confirmado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Tu transacción ha sido procesada exitosamente',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetailsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_pharmacy, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Información de Entrega',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow('Farmacia', widget.pharmacy.nombre),
            _buildInfoRow('Dirección', widget.pharmacy.direccion),
            if (widget.pharmacy.telefono != null && widget.pharmacy.telefono!.isNotEmpty)
              _buildInfoRow('Teléfono', widget.pharmacy.telefono!),
            _buildInfoRow(
              'Tiempo Estimado',
              'El pedido será procesado en 24-48 horas',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillActionsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Factura Generada',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _viewBill,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver Factura'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareBill,
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _trackOrder,
            icon: const Icon(Icons.local_shipping),
            label: const Text('Rastrear Pedido'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _returnToHome,
            icon: const Icon(Icons.home),
            label: const Text('Volver al Inicio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'credit':
        return 'Tarjeta de Crédito';
      case 'debit':
        return 'Tarjeta de Débito';
      case 'cash_on_delivery':
        return 'Pago Contra Entrega';
      case 'mock':
        return 'Pago de Prueba';
      default:
        return method;
    }
  }

  void _viewBill() async {
    if (widget.billLocalPath == null) {
      _showMessage('Factura no disponible');
      return;
    }

    try {
      await _billService.openBill(widget.billLocalPath!);
    } catch (e) {
      _showMessage('Error al abrir factura: ${e.toString()}');
    }
  }

  void _shareBill() async {
    if (widget.billLocalPath == null) {
      _showMessage('Factura no disponible');
      return;
    }

    try {
      await _billService.shareBill(widget.billLocalPath!);
    } catch (e) {
      _showMessage('Error al compartir factura: ${e.toString()}');
    }
  }

  void _trackOrder() {
    // Navigate to order tracking screen
    // TODO: Implement order tracking screen
    _showMessage('Función de rastreo en desarrollo');
  }

  void _returnToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
