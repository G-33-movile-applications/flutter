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
    final theme = Theme.of(context);
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
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Future: Navigate to medicine details
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
                  // Medicine icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication,
                      color: theme.colorScheme.primary,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF0F172A), // High contrast
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildTypeBadge(context, tipo),
                      ],
                    ),
                  ),
                  // Stock availability indicator
                  _buildStockIndicator(context, cantidad),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Medicine details grid
              _buildDetailsGrid(context, [
                _DetailItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Cantidad',
                  value: cantidad.toString(),
                  color: cantidad > 10
                      ? Colors.green
                      : cantidad > 0
                      ? Colors.orange
                      : Colors.red,
                ),
                _DetailItem(
                  icon: Icons.attach_money,
                  label: 'Precio',
                  value: currencyFormat.format(precio),
                  color: theme.colorScheme.primary,
                ),
              ]),

              const SizedBox(height: 12),

              // Description
              if (descripcion.isNotEmpty && descripcion != 'Sin descripción')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          descripcion,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF1F2937), // Good contrast
                            height: 1.4,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tipo.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStockIndicator(BuildContext context, int cantidad) {
    final theme = Theme.of(context);
    final bool inStock = cantidad > 0;
    final bool lowStock = cantidad > 0 && cantidad <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: inStock
            ? (lowStock
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15))
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inStock
              ? (lowStock ? Colors.orange : Colors.green)
              : Colors.red,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: inStock
                ? (lowStock ? Colors.orange.shade700 : Colors.green.shade700)
                : Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            inStock ? (lowStock ? 'Poco stock' : 'Disponible') : 'Agotado',
            style: theme.textTheme.labelSmall?.copyWith(
              color: inStock
                  ? (lowStock ? Colors.orange.shade700 : Colors.green.shade700)
                  : Colors.red.shade700,
              fontWeight: FontWeight.bold,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(item.icon, color: item.color, size: 24),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            item.value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: item.color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showMedicineDetails(BuildContext context, Map<String, dynamic> med) {
    final theme = Theme.of(context);
    final nombre = med['nombre'] ?? 'Medicamento sin nombre';
    final descripcion = med['descripcion'] ?? 'Sin descripción disponible';
    final cantidad = med['cantidad'] ?? 0;
    final precio = med['precio'] ?? 0.0;
    final tipo = med['tipo'] ?? 'medicamento';

    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.medication,
                          color: theme.colorScheme.primary,
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildTypeBadge(context, tipo),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Details
                  _buildModalDetailRow(
                    context,
                    Icons.inventory_2,
                    'Cantidad disponible',
                    cantidad.toString(),
                  ),
                  const SizedBox(height: 16),
                  _buildModalDetailRow(
                    context,
                    Icons.attach_money,
                    'Precio unitario',
                    currencyFormat.format(precio),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Descripción',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      descripcion,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1F2937),
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
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
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
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
