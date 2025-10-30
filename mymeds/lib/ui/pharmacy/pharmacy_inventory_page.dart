import 'package:flutter/material.dart';
import '../../models/punto_fisico.dart';
import '../../facade/app_repository_facade.dart';

class PharmacyInventoryPage extends StatefulWidget {
  final PuntoFisico pharmacy;

  const PharmacyInventoryPage({
    super.key,
    required this.pharmacy,
  });

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

      final List<Map<String, dynamic>> pharmacyData =
          await _facade.getMedicamentosDisponiblesEnPuntosFisicos(
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.pharmacy.nombre),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInventory,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_pharmacyData.isEmpty) {
      return Center(
        child: Text(
          'No hay medicamentos disponibles en esta farmacia',
          style: TextStyle(color: theme.colorScheme.onSurface),
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

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: theme.colorScheme.surface,
            child: ListTile(
              title: Text(
                med['nombre'] ?? 'Medicamento sin nombre',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Cantidad disponible: ${med['cantidad'] ?? 0}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    'Precio: \$${(med['precio'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    med['descripcion'] ?? 'Sin descripción',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
