import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/punto_fisico.dart';
import '../../facade/app_repository_facade.dart';

class PharmacyInventoryPage extends StatefulWidget {
  final PuntoFisico pharmacy;

  const PharmacyInventoryPage({super.key, required this.pharmacy});

  @override
  State<PharmacyInventoryPage> createState() => _PharmacyInventoryPageState();
}

class _PharmacyInventoryPageState extends State<PharmacyInventoryPage> {
  final _facade = AppRepositoryFacade();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pharmacyData = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final List<Map<String, dynamic>> pharmacyData = await _facade
          .getMedicamentosDisponiblesEnPuntosFisicos(
            puntoFisicoId: widget.pharmacy.id,
          );

      if (mounted) {
        setState(() {
          _pharmacyData = pharmacyData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pharmacy.nombre), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar el inventario',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadInventory,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pharmacyData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay medicamentos disponibles',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Esta farmacia no tiene medicamentos en stock actualmente',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pharmacyData.length,
        itemBuilder: (context, index) {
          final med = _pharmacyData[index];
          return _buildMedicineCard(context, med);
        },
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Map<String, dynamic> med) {
    final nombre = med['nombre'] ?? 'Medicamento sin nombre';
    final descripcion = med['descripcion'] ?? 'Sin descripción';
    final cantidad = med['cantidad'] ?? 0;
    final precio = med['precio'] ?? 0.0;
    final tipo = med['tipo'] ?? 'medicamento';

    // Format currency
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showMedicineDetails(context, med);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Medicine name and availability badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medicine icon with improved contrast
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1565C0).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.medication,
                      color: Color(0xFF1565C0),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Medicine name and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _buildTypeBadge(context, tipo),
                      ],
                    ),
                  ),
                  // Stock availability indicator
                  _buildStockIndicator(context, cantidad),
                ],
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 16),

              // Medicine details grid
              _buildDetailsGrid(context, [
                _DetailItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Cantidad',
                  value: cantidad.toString(),
                  color: cantidad > 10
                      ? const Color(0xFF2E7D32)
                      : cantidad > 0
                      ? const Color(0xFFE65100)
                      : const Color(0xFFC62828),
                ),
                _DetailItem(
                  icon: Icons.attach_money,
                  label: 'Precio',
                  value: currencyFormat.format(precio),
                  color: const Color(0xFF1565C0),
                ),
              ]),

              const SizedBox(height: 12),

              // Description with improved contrast
              if (descripcion.isNotEmpty && descripcion != 'Sin descripción')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          descripcion,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String tipo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF1565C0).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        tipo.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF1565C0),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStockIndicator(BuildContext context, int cantidad) {
    final bool inStock = cantidad > 0;
    final bool lowStock = cantidad > 0 && cantidad <= 10;

    // Define colors with high contrast
    final Color backgroundColor;
    final Color textColor;
    final String label;

    if (!inStock) {
      backgroundColor = const Color(0xFFC62828);
      textColor = Colors.white;
      label = 'Agotado';
    } else if (lowStock) {
      backgroundColor = const Color(0xFFE65100);
      textColor = Colors.white;
      label = 'Poco stock';
    } else {
      backgroundColor = const Color(0xFF2E7D32);
      textColor = Colors.white;
      label = 'Disponible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid(BuildContext context, List<_DetailItem> items) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildDetailItem(context, item),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailItem(BuildContext context, _DetailItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(item.icon, color: item.color, size: 26),
          const SizedBox(height: 8),
          Text(
            item.label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showMedicineDetails(BuildContext context, Map<String, dynamic> med) async {
    // Get basic info from inventory
    final nombre = med['nombre'] ?? 'Medicamento sin nombre';
    final cantidad = med['cantidad'] ?? 0;
    final precio = med['precio'] ?? 0.0;
    final medicamentoId = med['id'] as String?;

    print('🔍 [PharmacyInventory] Opening details for medication:');
    print('   - nombre: $nombre');
    print('   - medicamentoId from inventory: $medicamentoId');
    print('   - cantidad: $cantidad');
    print('   - precio: $precio');

    // Show loading dialog while fetching full details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    String descripcion = 'Sin descripción disponible';
    String presentacion = 'Medicamento';
    String? laboratorio;
    String? principioActivo;

    // Try to fetch full medication details from global collection
    if (medicamentoId != null && medicamentoId.isNotEmpty) {
      try {
        print('🔍 [PharmacyInventory] Fetching full medication details from global collection...');
        final medicamento = await _facade.getMedicamentoById(medicamentoId);
        
        if (medicamento != null) {
          print('✅ [PharmacyInventory] Medication found in global collection:');
          print('   - id: ${medicamento.id}');
          print('   - nombre: ${medicamento.nombre}');
          print('   - descripcion: ${medicamento.descripcion}');
          print('   - presentacion: ${medicamento.presentacion}');
          print('   - laboratorio: ${medicamento.laboratorio}');
          print('   - principioActivo: ${medicamento.principioActivo}');
          
          descripcion = medicamento.descripcion.isNotEmpty 
              ? medicamento.descripcion 
              : 'Sin descripción disponible';
          presentacion = medicamento.presentacion.isNotEmpty
              ? medicamento.presentacion
              : 'Medicamento';
          laboratorio = medicamento.laboratorio;
          principioActivo = medicamento.principioActivo;
        } else {
          print('❌ [PharmacyInventory] Medication NOT FOUND in global collection with id: $medicamentoId');
        }
      } catch (e) {
        print('❌ [PharmacyInventory] Error fetching medication details: $e');
        // Continue with basic info from inventory
      }
    } else {
      print('⚠️ [PharmacyInventory] No medicamentoId available to fetch details');
    }

    // Close loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (!context.mounted) return;

    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
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
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with improved contrast
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF1565C0).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: Color(0xFF1565C0),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildTypeBadge(context, presentacion),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Divider(height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 24),

                  // Details with improved contrast
                  _buildModalDetailRow(
                    context,
                    Icons.inventory_2,
                    'Cantidad disponible',
                    cantidad.toString(),
                    cantidad > 10
                        ? const Color(0xFF2E7D32)
                        : cantidad > 0
                        ? const Color(0xFFE65100)
                        : const Color(0xFFC62828),
                  ),
                  const SizedBox(height: 16),
                  _buildModalDetailRow(
                    context,
                    Icons.attach_money,
                    'Precio unitario',
                    currencyFormat.format(precio),
                    const Color(0xFF1565C0),
                  ),
                  const SizedBox(height: 24),

                  // Description with improved contrast
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      descripcion,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Additional medication information
                  if (laboratorio != null && laboratorio.isNotEmpty) ...[
                    _buildModalDetailRow(
                      context,
                      Icons.factory,
                      'Laboratorio',
                      laboratorio,
                      const Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (principioActivo != null && principioActivo.isNotEmpty) ...[
                    _buildModalDetailRow(
                      context,
                      Icons.science,
                      'Principio Activo',
                      principioActivo,
                      const Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Close button with improved styling
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
