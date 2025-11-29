// Example: Inventory Check Service Usage
// This file demonstrates how to use the InventoryCheckService

import 'package:flutter/material.dart';
import '../../services/inventory_check_service.dart';
import '../../models/inventory_check_result.dart';

/// Example widget showing inventory check implementation
class InventoryCheckExample extends StatefulWidget {
  final String userId;
  final String prescriptionId;
  final String pharmacyId;

  const InventoryCheckExample({
    super.key,
    required this.userId,
    required this.prescriptionId,
    required this.pharmacyId,
  });

  @override
  State<InventoryCheckExample> createState() => _InventoryCheckExampleState();
}

class _InventoryCheckExampleState extends State<InventoryCheckExample> {
  final _inventoryService = InventoryCheckService();
  
  InventoryCheckResult? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkInventory();
  }

  /// Check inventory availability
  Future<void> _checkInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _inventoryService.checkPrescriptionAvailability(
        prescriptionId: widget.prescriptionId,
        pharmacyId: widget.pharmacyId,
        userId: widget.userId,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });

      // Print statistics
      _inventoryService.printCacheStats();
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
        title: const Text('Inventory Check Example'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkInventory,
        child: const Icon(Icons.refresh),
      ),
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
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkInventory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_result == null) {
      return const Center(
        child: Text('No data'),
      );
    }

    return _buildResultView(_result!);
  }

  Widget _buildResultView(InventoryCheckResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        result.allAvailable ? Icons.check_circle : Icons.warning,
                        color: result.allAvailable ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.pharmacyName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              result.allAvailable
                                  ? 'All medicines available'
                                  : '${result.unavailableMedicines.length} medicine(s) unavailable',
                              style: TextStyle(
                                color: result.allAvailable ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Price',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '\$${result.totalPrice.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medicines',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${result.availableMedicines.length}/${result.medicines.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      if (result.fromCache)
                        const Chip(
                          label: Text('Cached'),
                          avatar: Icon(Icons.cached, size: 16),
                        ),
                    ],
                  ),
                  if (result.missingDataCount > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${result.missingDataCount} medicine(s) with missing inventory data (fallback pricing applied)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Medicine List
          Text(
            'Medicines',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...result.medicines.map((medicine) => _buildMedicineCard(medicine)),
          
          const SizedBox(height: 16),
          
          // Metadata
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metadata',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  _buildMetadataRow('Checked at', _formatDateTime(result.checkedAt)),
                  _buildMetadataRow('Prescription ID', result.prescriptionId),
                  _buildMetadataRow('Pharmacy ID', result.pharmacyId),
                  _buildMetadataRow('From cache', result.fromCache ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(MedicineAvailability medicine) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          medicine.available ? Icons.check_circle : Icons.cancel,
          color: medicine.available ? Colors.green : Colors.red,
        ),
        title: Text(medicine.medicineName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock: ${medicine.stock}'),
            if (medicine.missingData)
              const Text(
                'Missing inventory data (fallback price applied)',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
          ],
        ),
        trailing: Text(
          '\$${medicine.price.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: medicine.missingData ? Colors.orange : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} - ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
