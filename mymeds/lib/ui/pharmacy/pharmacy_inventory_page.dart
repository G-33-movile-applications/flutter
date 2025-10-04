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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pharmacy.nombre),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
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
      return const Center(
        child: Text('No hay medicamentos disponibles en esta farmacia'),
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
            child: ListTile(
              title: Text(
                med['nombre'] ?? 'Medicamento sin nombre',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Cantidad disponible: ${med['cantidad'] ?? 0}'),
                  Text('Precio: \$${(med['precio'] ?? 0).toStringAsFixed(2)}'),
                  Text(med['descripcion'] ?? 'Sin descripción'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
