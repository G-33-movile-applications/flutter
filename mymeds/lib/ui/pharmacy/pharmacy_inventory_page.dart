import 'package:flutter/material.dart';
import '../../models/medicamento.dart';
import '../../models/punto_fisico.dart';
import '../../models/medicamento_punto_fisico.dart';
import '../../facade/app_repository_facade.dart';
import '../../repositories/medicamento_punto_fisico_repository.dart';

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
  final _repository = MedicamentoPuntoFisicoRepository();
  final _facade = AppRepositoryFacade();
  bool _isLoading = true;
  List<MedicamentoPuntoFisico> _inventory = [];
  List<Medicamento> _medicamentos = [];
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

      // Get the inventory relationships first
      _inventory = await _repository.findByPuntoFisicoId(widget.pharmacy.id);
      
      // Get the full medicamento details for each inventory item
      final medicamentoIds = _inventory.map((item) => item.medicamentoId).toList();
      _medicamentos = [];
      
      for (final id in medicamentoIds) {
        final medicamentoData = await _facade.getMedicamentoAvailability(id);
        if (medicamentoData['medicamento'] != null) {
          _medicamentos.add(medicamentoData['medicamento'] as Medicamento);
        }
      }
      
      if (mounted) {
        setState(() {
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

    if (_inventory.isEmpty) {
      return const Center(
        child: Text('No hay medicamentos disponibles en esta farmacia'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _inventory.length,
        itemBuilder: (context, index) {
          final inventoryItem = _inventory[index];
          final medicamento = _medicamentos.firstWhere(
            (m) => m.id == inventoryItem.medicamentoId,
            orElse: () => Pastilla(
              id: inventoryItem.medicamentoId,
              nombre: 'Medicamento no encontrado',
              descripcion: '',
              esRestringido: false,
              dosisMg: 0,
              cantidad: 0,
            ),
          );
          
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
                  Text('Cantidad disponible: ${inventoryItem.cantidad}'),
                  if (medicamento.descripcion.isNotEmpty)
                    Text(medicamento.descripcion),
                  Text('Restringido: ${medicamento.esRestringido ? 'Sí' : 'No'}'),
                  const SizedBox(height: 4),
                  _buildMedicationTypeInfo(medicamento),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedicationTypeInfo(Medicamento medicamento) {
    if (medicamento is Pastilla) {
      return Text('Pastilla - ${medicamento.dosisMg}mg (${medicamento.cantidad} unidades)');
    } else if (medicamento is Unguento) {
      return Text('Ungüento - ${medicamento.concentracion} (${medicamento.cantidadEnvases} envases)');
    } else if (medicamento is Inyectable) {
      return Text('Inyectable - ${medicamento.concentracion}, ${medicamento.volumenPorUnidad}ml (${medicamento.cantidadUnidades} unidades)');
    } else if (medicamento is Jarabe) {
      return Text('Jarabe - ${medicamento.mlPorBotella}ml (${medicamento.cantidadBotellas} botellas)');
    }
    return const Text('Tipo de medicamento no especificado');
  }
}