import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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
      // Pass stats to avoid duplicate query
      final topPharmacies = await _statsService.getTopPharmacies(userId, limit: 5, stats: stats);

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
      backgroundColor: AppTheme.scaffoldBackgroundColor,
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

          // Medicine Statistics Card (Business Question Type 2)
          _buildMedicineStatsCard(),
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
            const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Color(0xFF1565C0), // Darker blue for better contrast
            ),
            const SizedBox(height: 12),
            Text(
              '${_stats!.totalOrders}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: const Color(0xFF1565C0), // Darker blue for better contrast
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pedidos Totales',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF37474F), // Darker gray for better contrast
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineStatsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estadísticas de Medicamentos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF212121),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Total medicines requested
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1565C0).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.medication_liquid,
                          color: Color(0xFF1565C0),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_stats!.totalMedicinesRequested}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF1565C0),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Medicamentos Solicitados',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Last claim date
            if (_stats!.lastClaimDate != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Último Reclamo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF37474F),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(_stats!.lastClaimDate!),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF37474F),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay medicamentos reclamados aún',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF37474F),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace ${weeks} ${weeks == 1 ? 'semana' : 'semanas'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace ${months} ${months == 1 ? 'mes' : 'meses'}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
                const Icon(Icons.local_shipping, color: Color(0xFF1565C0)), // Darker blue for better contrast
                const SizedBox(width: 8),
                Text(
                  'Preferencia de Entrega',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF212121), // Dark gray for better contrast
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
                    const Color(0xFF1565C0), // Darker blue for better contrast
                    Icons.home,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeItem(
                    'Recogida',
                    _stats!.pickupCount,
                    _stats!.pickupPercentage,
                    const Color(0xFF2E7D32), // Darker green for better contrast
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
                    ? const Color(0xFF1565C0).withOpacity(0.1) // Darker blue for better contrast
                    : const Color(0xFF1565C0).withOpacity(0.1), // Darker green for better contrast
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: _stats!.preferredDeliveryMode == 'domicilio'
                        ? const Color(0xFF1565C0) // Darker blue for better contrast
                        : const Color(0xFF1565C0), // Darker green for better contrast
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Modo preferido: ${_stats!.preferredDeliveryMode == "domicilio" ? "Domicilio" : "Recogida"}',
                    style: TextStyle(
                      color: _stats!.preferredDeliveryMode == 'domicilio'
                          ? const Color(0xFF1565C0) // Darker blue for better contrast
                          : const Color(0xFF1565C0), // Darker green for better contrast
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
    // Use darker colors for better contrast (WCAG AA compliant)
    final Color darkColor = color == const Color(0xFF1565C0) 
        ? const Color(0xFF1565C0) // Darker blue for domicilio
        : const Color(0xFF2E7D32); // Darker green for recogida
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: darkColor, size: 32),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: darkColor,
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
                  color: const Color(0xFF37474F), // Darker gray for better contrast
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
                const Icon(Icons.medication, color: Color(0xFF1565C0)), // Darker blue for better contrast
                const SizedBox(width: 8),
                Text(
                  'Farmacias Más Frecuentes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF212121), // Dark gray for better contrast
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_topPharmacies.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No hay datos de farmacias disponibles',
                    style: TextStyle(color: Color(0xFF37474F)), // Darker gray for better contrast
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

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isTopPharmacy
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTopPharmacy
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
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
                              ? AppTheme.primaryColor
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pharmacy.direccion,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF37474F), // Darker gray for better contrast
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
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$orderCount pedidos',
                          style: TextStyle(
                            color: isTopPharmacy ? Colors.white : const Color(0xFF212121), // Darker color for better contrast
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
