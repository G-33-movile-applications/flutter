import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../models/pago.dart';
import '../../models/factura.dart';
import '../../services/payment_processing_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

/// Payment History Screen - Shows all payments with bills and sync status
/// 
/// Displays:
/// - All payments from SQLite (synced and queued)
/// - Bill for each payment with PDF viewer
/// - Sync status indicator
/// - Payment details (date, total, method, status)
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final PaymentProcessingService _paymentService = PaymentProcessingService();
  
  bool _isLoading = true;
  List<Pago> _payments = [];
  Map<String, Factura?> _bills = {};
  Set<String> _queuedPayments = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all payments from SQLite
      final payments = await _paymentService.getAllPayments();
      
      // Load queued payments (not synced)
      final queuedPayments = await _paymentService.getQueuedPayments();
      final queuedIds = queuedPayments.map((p) => p.id).toSet();

      // Load bills for each payment
      final bills = <String, Factura?>{};
      for (final payment in payments) {
        final bill = await _paymentService.getBillForPayment(payment.id);
        bills[payment.id] = bill;
      }

      setState(() {
        _payments = payments;
        _bills = bills;
        _queuedPayments = queuedIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pagos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPaymentHistory,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPaymentHistory,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay pagos aún',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu historial de pagos aparecerá aquí',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length,
        itemBuilder: (context, index) {
          final payment = _payments[index];
          final bill = _bills[payment.id];
          final isQueued = _queuedPayments.contains(payment.id);
          
          return _buildPaymentCard(payment, bill, isQueued);
        },
      ),
    );
  }

  Widget _buildPaymentCard(Pago payment, Factura? bill, bool isQueued) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showPaymentDetails(payment, bill),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pago #${payment.id.split('_').last}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(payment.status, isQueued),
                ],
              ),
              const SizedBox(height: 8),
              
              // Date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(payment.transactionDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Total amount
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '\$${payment.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Payment method
              Row(
                children: [
                  const Icon(Icons.payment, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _formatPaymentMethod(payment.method),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              
              // Bill info
              if (bill != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt,
                          size: 16,
                          color: bill.pdfUrl != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bill.pdfUrl != null
                              ? 'Factura sincronizada en la nube'
                              : 'Factura guardada localmente',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: bill.pdfUrl != null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _viewBill(bill),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Ver'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isQueued) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    if (isQueued) {
      backgroundColor = Colors.orange[100]!;
      textColor = Colors.orange[900]!;
      icon = Icons.sync;
      label = 'En cola';
    } else {
      switch (status) {
        case 'completed':
          backgroundColor = Colors.green[100]!;
          textColor = Colors.green[900]!;
          icon = Icons.check_circle;
          label = 'Completado';
          break;
        case 'processing':
          backgroundColor = Colors.blue[100]!;
          textColor = Colors.blue[900]!;
          icon = Icons.hourglass_empty;
          label = 'Procesando';
          break;
        case 'failed':
          backgroundColor = Colors.red[100]!;
          textColor = Colors.red[900]!;
          icon = Icons.error;
          label = 'Fallido';
          break;
        default:
          backgroundColor = Colors.grey[200]!;
          textColor = Colors.grey[800]!;
          icon = Icons.pending;
          label = 'Pendiente';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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

  void _showPaymentDetails(Pago payment, Factura? bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Detalles del Pago',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              
              // Payment ID
              _buildDetailRow('ID de Pago', payment.id),
              _buildDetailRow('ID de Pedido', payment.orderId),
              _buildDetailRow('ID de Prescripción', payment.prescriptionId),
              _buildDetailRow('ID de Farmacia', payment.pharmacyId),
              _buildDetailRow('Total', '\$${payment.total.toStringAsFixed(2)}'),
              _buildDetailRow('Costo de Envío', '\$${payment.deliveryFee.toStringAsFixed(2)}'),
              _buildDetailRow('Método de Pago', _formatPaymentMethod(payment.method)),
              _buildDetailRow('Estado', payment.status.toUpperCase()),
              _buildDetailRow(
                'Fecha',
                DateFormat('MMMM dd, yyyy HH:mm:ss').format(payment.transactionDate),
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Medicines
              Text(
                'Medicamentos (${payment.prices.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...payment.prices.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '\$${entry.value.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  )),
              
              if (bill != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Bill info
                Text(
                  'Información de la Factura',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('ID de Factura', bill.id),
                _buildDetailRow(
                  'Creado',
                  DateFormat('MMMM dd, yyyy HH:mm:ss').format(bill.createdAt),
                ),
                _buildDetailRow(
                  'Estado',
                  bill.pdfUrl != null ? 'Sincronizado en la nube' : 'Solo local',
                ),
                if (bill.localPdfPath.isNotEmpty)
                  _buildDetailRow('Ruta Local', bill.localPdfPath),
                if (bill.pdfUrl != null)
                  _buildDetailRow('URL en la Nube', bill.pdfUrl!),

                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _viewBill(bill);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Ver Factura PDF'),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewBill(Factura bill) async {
    if (bill.localPdfPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo de factura no encontrado localmente')),
      );
      return;
    }

    // Check if file exists
    final file = File(bill.localPdfPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo de factura no encontrado. Puede haber sido eliminado.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Try to open the PDF file with default viewer
    try {
      final result = await OpenFile.open(bill.localPdfPath);
      
      if (result.type != ResultType.done) {
        // If opening failed, show dialog with options
        if (mounted) {
          _showBillOptionsDialog(bill);
        }
      }
    } catch (e) {
      // If error occurred, show dialog with options
      if (mounted) {
        _showBillOptionsDialog(bill);
      }
    }
  }

  void _showBillOptionsDialog(Factura bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red),
            SizedBox(width: 12),
            Text('Factura PDF'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID de Factura: ${bill.id}'),
            const SizedBox(height: 8),
            Text(
              'Ruta Local:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              bill.localPdfPath,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
            if (bill.pdfUrl != null) ...[
              const SizedBox(height: 8),
              const Text(
                'URL en la Nube:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                bill.pdfUrl!,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El PDF se abrirá con tu visor predeterminado',
                      style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (bill.localPdfPath.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final result = await OpenFile.open(bill.localPdfPath);
                if (result.type != ResultType.done && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${result.message}')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          if (bill.localPdfPath.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bill.localPdfPath));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ruta copiada al portapapeles')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Ruta'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
