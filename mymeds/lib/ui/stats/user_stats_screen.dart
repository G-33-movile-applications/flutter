import 'package:flutter/material.dart';
import '../../models/user_stats.dart';
import '../../services/user_stats_service.dart';
import '../../services/user_session.dart';
import '../../models/punto_fisico.dart';

class UserStatsScreen extends StatefulWidget {
  const UserStatsScreen({super.key});

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  final UserStatsService _statsService = UserStatsService();
  bool _isLoading = true;
  String? _error;
  UserStats? _stats;
  List<Map<String, dynamic>> _topPharmacies = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final stats = await _statsService.getUserStats(userId);
      final topPharmacies = await _statsService.getTopPharmacies(userId, limit: 5);

      setState(() {
        _stats = stats;
        _topPharmacies = topPharmacies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando estadísticas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mis Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStats,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stats == null) {
      return const Center(
        child: Text('No hay datos disponibles'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Orders Card
          _buildTotalOrdersCard(),
          const SizedBox(height: 16),

          // Delivery Mode Preference Card
          _buildDeliveryModeCard(),
          const SizedBox(height: 16),

          // Top Pharmacies Card
          _buildTopPharmaciesCard(),
        ],
      ),
    );
  }

  Widget _buildTotalOrdersCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '${_stats!.totalOrders}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pedidos Totales',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryModeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Preferencia de Entrega',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildModeItem(
                    'Domicilio',
                    _stats!.deliveryCount,
                    _stats!.deliveryPercentage,
                    Theme.of(context).colorScheme.primary,
                    Icons.home,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeItem(
                    'Recogida',
                    _stats!.pickupCount,
                    _stats!.pickupPercentage,
                    Theme.of(context).colorScheme.secondary,
                    Icons.store,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Preferred mode indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _stats!.preferredDeliveryMode == 'domicilio'
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: _stats!.preferredDeliveryMode == 'domicilio'
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Modo preferido: ${_stats!.preferredDeliveryMode == "domicilio" ? "Domicilio" : "Recogida"}',
                    style: TextStyle(
                      color: _stats!.preferredDeliveryMode == 'domicilio'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
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

  Widget _buildModeItem(
      String label, int count, double percentage, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPharmaciesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Farmacias Más Frecuentes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_topPharmacies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No hay datos de farmacias disponibles',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ),
              )
            else
              ..._topPharmacies.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final pharmacy = data['pharmacy'] as PuntoFisico;
                final orderCount = data['orderCount'] as int;
                final isTopPharmacy = index == 0;
                final theme = Theme.of(context);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isTopPharmacy
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : theme.colorScheme.outline.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTopPharmacy
                          ? theme.colorScheme.primary.withOpacity(0.3)
                          : theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isTopPharmacy
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isTopPharmacy
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Pharmacy info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacy.nombre,
                              style: theme
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pharmacy.direccion,
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Order count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isTopPharmacy
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$orderCount pedidos',
                          style: TextStyle(
                            color: isTopPharmacy
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
