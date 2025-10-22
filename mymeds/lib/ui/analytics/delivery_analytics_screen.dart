import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/delivery_stats.dart';
import '../../services/analytics_service.dart';
import '../../services/user_session.dart';

class DeliveryAnalyticsScreen extends StatefulWidget {
  const DeliveryAnalyticsScreen({super.key});

  @override
  State<DeliveryAnalyticsScreen> createState() => _DeliveryAnalyticsScreenState();
}

class _DeliveryAnalyticsScreenState extends State<DeliveryAnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  DeliveryStats? _stats;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final currentUser = UserSession().currentUser.value;
      
      if (currentUser == null) {
        setState(() {
          _error = 'No hay una sesión activa';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final stats = await _analyticsService.getDeliveryStats(
        userId: currentUser.uid,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando estadísticas: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Análisis de Entregas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDateRange,
            tooltip: 'Seleccionar rango de fechas',
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
          // Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Resumen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Domicilio',
                        _stats!.deliveryCount,
                        _stats!.deliveryPercentage,
                        Colors.blue,
                      ),
                      _buildSummaryItem(
                        'Recogida',
                        _stats!.pickupCount,
                        _stats!.pickupPercentage,
                        Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Trends Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Tendencias Mensuales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildMonthlyChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, double percentage, Color color) {
    return Column(
      children: [
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
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart() {
    if (_stats!.deliveryByMonth.isEmpty && _stats!.pickupByMonth.isEmpty) {
      return const Center(
        child: Text('No hay datos mensuales disponibles'),
      );
    }

    // Combine all months from both maps
    final allMonths = {..._stats!.deliveryByMonth.keys, ..._stats!.pickupByMonth.keys}
        .toList()
        ..sort();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: allMonths.length,
      itemBuilder: (context, index) {
        final month = allMonths[index];
        final deliveryCount = _stats!.deliveryByMonth[month] ?? 0;
        final pickupCount = _stats!.pickupByMonth[month] ?? 0;
        final total = deliveryCount + pickupCount;

        return Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              const Spacer(),
              _buildBar(deliveryCount, total, Colors.blue),
              const SizedBox(height: 4),
              _buildBar(pickupCount, total, Colors.green),
              const SizedBox(height: 8),
              Text(
                month,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(int value, int total, Color color) {
    final height = total > 0 ? (value / total) * 200 : 0.0;
    
    return Container(
      width: 20,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}