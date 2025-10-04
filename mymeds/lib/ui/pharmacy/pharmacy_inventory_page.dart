import 'package:flutter/material.dart';
import '../../models/medicamento.dart';
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
  Map<String, dynamic> _pharmacyData = {};
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

      final pharmacyData = await _facade.getPharmacyWithMedicamentos(widget.pharmacy.id);
      
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

    final medications = _pharmacyData['medications'] as List<Medicamento>? ?? [];
    final availability = _pharmacyData['availability'] as Map<String, dynamic>? ?? {};

    if (medications.isEmpty) {
      return const Center(
        child: Text('No hay medicamentos disponibles en esta farmacia'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: medications.length,
        itemBuilder: (context, index) {
          final medicamento = medications[index];
          final stock = availability[medicamento.id] as Map<String, dynamic>? ?? {};
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                medicamento.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Cantidad disponible: ${stock['cantidad'] ?? 0}'),
                  Text('Precio: \$${stock['precio'] ?? 0.0}'),
                  Text('${medicamento.descripcion}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}