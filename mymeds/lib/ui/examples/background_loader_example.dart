// Example: Background Loader Usage
// This file demonstrates how to use the BackgroundLoader service

import 'package:flutter/material.dart';
import '../../services/background_loader.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/prescripcion.dart';
import '../../models/pedido.dart';

/// Example widget showing background loading implementation
class BackgroundLoaderExample extends StatefulWidget {
  final String userId;

  const BackgroundLoaderExample({
    super.key,
    required this.userId,
  });

  @override
  State<BackgroundLoaderExample> createState() => _BackgroundLoaderExampleState();
}

class _BackgroundLoaderExampleState extends State<BackgroundLoaderExample> {
  List<Prescripcion> _prescriptions = [];
  List<Pedido> _orders = [];
  bool _isLoading = false;
  bool _hasCache = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load data with cache-first strategy
  Future<void> _loadData() async {
    // 1. Load from cache immediately
    _loadFromCache();

    // 2. Check connectivity
    if (!ConnectivityService().isConnected) {
      debugPrint('Offline - using cached data only');
      return;
    }

    // 3. Launch background fetch
    setState(() => _isLoading = true);

    try {
      // OPTION 1: Load both concurrently (fastest)
      final result = await BackgroundLoader.loadUserDataConcurrent(
        userId: widget.userId,
        includeInactive: false,
        includeDelivered: true,
      );

      // OPTION 2: Load separately
      // final result = await BackgroundLoader.loadUserData(
      //   userId: widget.userId,
      //   includeInactive: false,
      //   includeDelivered: true,
      // );

      if (!mounted) return;

      setState(() {
        _prescriptions = result['prescriptions'] as List<Prescripcion>;
        _orders = result['orders'] as List<Pedido>;
        _isLoading = false;
      });

      // 4. Update cache
      _saveToCache();

      debugPrint('Background load completed: ${_prescriptions.length} prescriptions, ${_orders.length} orders');
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load from cache (instant)
  void _loadFromCache() {
    final cache = CacheService();
    
    final cachedPrescriptions = cache.get<List<Prescripcion>>(
      'prescriptions_${widget.userId}',
    );
    
    final cachedOrders = cache.get<List<Pedido>>(
      'orders_${widget.userId}',
    );

    if (cachedPrescriptions != null || cachedOrders != null) {
      setState(() {
        _prescriptions = cachedPrescriptions ?? [];
        _orders = cachedOrders ?? [];
        _hasCache = true;
      });
      debugPrint('Loaded from cache: ${_prescriptions.length} prescriptions, ${_orders.length} orders');
    }
  }

  /// Save to cache
  void _saveToCache() {
    final cache = CacheService();
    
    cache.set(
      'prescriptions_${widget.userId}',
      _prescriptions,
      ttl: const Duration(hours: 1),
    );
    
    cache.set(
      'orders_${widget.userId}',
      _orders,
      ttl: const Duration(hours: 1),
    );

    debugPrint('Saved to cache');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Loader Demo'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            // Status card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoading
                              ? Icons.cloud_sync
                              : _hasCache
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                          color: _isLoading
                              ? Colors.blue
                              : _hasCache
                                  ? Colors.green
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLoading
                              ? 'Syncing...'
                              : _hasCache
                                  ? 'Up to date'
                                  : 'Offline',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prescriptions: ${_prescriptions.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Orders: ${_orders.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            // Prescriptions section
            if (_prescriptions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Prescriptions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._prescriptions.map((p) => ListTile(
                    leading: const Icon(Icons.medication),
                    title: Text(p.medico),
                    subtitle: Text(p.diagnostico),
                    trailing: Text(
                      p.activa ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: p.activa ? Colors.green : Colors.grey,
                      ),
                    ),
                  )),
            ],

            // Orders section
            if (_orders.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._orders.map((o) => ListTile(
                    leading: const Icon(Icons.shopping_bag),
                    title: Text('Order ${o.id}'),
                    subtitle: Text(o.direccionEntrega),
                    trailing: Chip(
                      label: Text(o.estado),
                      backgroundColor: _getStatusColor(o.estado),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'entregado':
        return Colors.green.shade100;
      case 'en_proceso':
        return Colors.blue.shade100;
      case 'cancelado':
        return Colors.red.shade100;
      default:
        return Colors.orange.shade100;
    }
  }
}
