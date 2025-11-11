import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pedido.dart';
import '../../models/punto_fisico.dart';
import '../../services/orders_sync_service.dart';
import '../../services/user_session.dart';
import '../../services/connectivity_service.dart';
import '../../repositories/punto_fisico_repository.dart';

/// Offline-first Orders View
/// 
/// Features:
/// - Loads from cache first (instant UI)
/// - Syncs with Firestore when online
/// - Shows offline indicator
/// - Pull-to-refresh support
/// - Graceful empty states
class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> with AutomaticKeepAliveClientMixin {
  final OrdersSyncService _syncService = OrdersSyncService();
  final ConnectivityService _connectivity = ConnectivityService();
  final PuntoFisicoRepository _pharmacyRepo = PuntoFisicoRepository();
  
  bool _isLoading = true;
  bool _isOnline = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastSyncTime;
  
  // Cache for pharmacy data
  final Map<String, PuntoFisico> _pharmacyCache = {};
  
  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  
  // Get orders from UserSession (populated from persistent cache in HomeScreen)
  List<Pedido> get _orders => UserSession().currentPedidos.value;
  
  @override
  void initState() {
    super.initState();
    
    debugPrint('🔍 [OrdersView] initState - UserSession orders: ${UserSession().currentPedidos.value.length}');
    
    // Listen to UserSession orders (populated from persistent cache in HomeScreen)
    UserSession().currentPedidos.addListener(_onOrdersUpdated);
    
    // Check if we already have data from cache
    if (UserSession().currentPedidos.value.isNotEmpty) {
      debugPrint('✅ [OrdersView] Data already in UserSession, skipping load');
      _isLoading = false;
      _preloadPharmacyData();
    } else {
      // If no data yet, trigger a load
      debugPrint('⚠️ [OrdersView] No data in UserSession, triggering load');
      _initializeOrders();
    }
    
    _listenToConnectivity();
  }
  
  @override
  void dispose() {
    UserSession().currentPedidos.removeListener(_onOrdersUpdated);
    super.dispose();
  }
  
  void _onOrdersUpdated() {
    if (mounted) {
      setState(() {
        // Data changed, update UI
      });
      
      // Preload pharmacy data for new orders
      _preloadPharmacyData();
    }
  }
  
  Future<void> _initializeOrders() async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No hay usuario autenticado';
      });
      return;
    }
    
    // Check connectivity
    _isOnline = await _connectivity.checkConnectivity();
    
    // If we already have orders in UserSession, show them immediately
    if (_orders.isNotEmpty) {
      debugPrint('📦 [OrdersView] Using orders from UserSession (${_orders.length} orders)');
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      
      // Preload pharmacy data if online
      if (_isOnline) {
        _preloadPharmacyData();
      }
      return;
    }
    
    try {
      // Load orders (cache-first strategy, works offline too)
      // Note: OrdersSyncService.loadOrders() automatically updates UserSession.currentPedidos
      await _syncService.loadOrders(userId);
      
      // Get cache metadata
      final metadata = await _syncService.getCacheMetadata(userId);
      if (metadata != null && metadata['lastSync'] != null) {
        _lastSyncTime = DateTime.parse(metadata['lastSync'] as String);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null; // Clear any previous errors
        });
        
        // Preload pharmacy data (skip if offline to avoid errors)
        if (_isOnline) {
          _preloadPharmacyData();
        }
      }
    } catch (e) {
      debugPrint('❌ [OrdersView] Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Only show error if we're online and have no cached data
          if (_isOnline) {
            _errorMessage = 'Error al cargar pedidos: ${e.toString()}';
          } else {
            // Offline - just finish loading, show empty state if no orders
            _errorMessage = null;
          }
        });
      }
    }
  }
  
  void _listenToConnectivity() {
    _connectivity.connectionStream.listen((connectionType) {
      final isOnline = connectionType != ConnectionType.none;
      if (mounted && isOnline != _isOnline) {
        setState(() => _isOnline = isOnline);
        
        // Auto-sync when coming back online
        if (isOnline) {
          _handleRefresh();
        }
      }
    });
  }
  
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    final userId = UserSession().currentUid;
    if (userId == null) return;
    
    // Check connectivity before attempting refresh
    final isOnline = await _connectivity.checkConnectivity();
    
    if (!isOnline) {
      // Don't show error when offline, just show info message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📴 Sin conexión - Mostrando datos guardados'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    setState(() => _isRefreshing = true);
    
    try {
      // Force refresh from Firestore
      // Note: OrdersSyncService.forceRefresh() automatically updates UserSession.currentPedidos
      await _syncService.forceRefresh(userId);
      
      final metadata = await _syncService.getCacheMetadata(userId);
      if (metadata != null && metadata['lastSync'] != null) {
        _lastSyncTime = DateTime.parse(metadata['lastSync'] as String);
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
        
        _preloadPharmacyData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_orders.length} pedidos actualizados'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [OrdersView] Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error al actualizar: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
  
  Future<void> _preloadPharmacyData() async {
    // Skip if offline to avoid unnecessary errors
    if (!_isOnline) {
      debugPrint('📴 [OrdersView] Skipping pharmacy preload - offline');
      return;
    }
    
    // Get unique pharmacy IDs
    final pharmacyIds = _orders.map((order) => order.puntoFisicoId).toSet();
    
    // Load all pharmacies without batching to avoid setState issues
    for (String pharmacyId in pharmacyIds) {
      if (!_pharmacyCache.containsKey(pharmacyId)) {
        try {
          final pharmacy = await _pharmacyRepo.read(pharmacyId);
          if (pharmacy != null) {
            _pharmacyCache[pharmacyId] = pharmacy;
          }
        } catch (e) {
          debugPrint('⚠️ Failed to load pharmacy $pharmacyId: $e');
          // Continue loading other pharmacies even if one fails
        }
      }
    }
    
    // Single setState at the end to avoid multiple rebuilds
    if (mounted) {
      setState(() {});
    }
  }
  
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Use theme color instead of hardcoded grey
      body: Column(
        children: [
          // Compact status indicator - only show when offline
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.orange.withValues(alpha: 0.15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange[800], size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Sin conexión',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_lastSyncTime != null)
                    Text(
                      'Última sync: ${_formatLastSync(_lastSyncTime!)}',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          
          // Main content
          Expanded(
            child: _buildContent(theme, isDark),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando pedidos...',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return _buildErrorState(theme, isDark);
    }
    
    if (_orders.isEmpty) {
      return _buildEmptyState(theme, isDark);
    }
    
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        // Critical: Use standard physics, remove cacheExtent for now
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final order = _orders[index];
          final pharmacy = _pharmacyCache[order.puntoFisicoId];
          
          // Remove RepaintBoundary - it can cause gray screen issues
          return _buildOrderCard(order, pharmacy, theme, isDark);
        },
      ),
    );
  }
  
  Widget _buildOrderCard(Pedido order, PuntoFisico? pharmacy, ThemeData theme, bool isDark) {
    final statusColor = _getStatusColor(order.estado);
    final statusIcon = _getStatusIcon(order.estado);
    final statusText = _getStatusText(order.estado);
    
    // Don't use RepaintBoundary - it can cause gray screen rendering issues
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
          onTap: () => _showOrderDetails(order, pharmacy),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status badge + Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('d MMM yyyy').format(order.fechaPedido),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Pharmacy name
              Row(
                children: [
                  Icon(
                    Icons.local_pharmacy,
                    size: 18,
                    color: _primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Use cached pharmacy name if available (for offline display)
                      order.cachedPharmacyName ?? pharmacy?.nombre ?? 'Farmacia no disponible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Delivery type and address
              Row(
                children: [
                  Icon(
                    order.tipoEntrega == 'domicilio' ? Icons.home : Icons.store,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.tipoEntrega == 'domicilio'
                          ? 'Entrega a domicilio'
                          : 'Recogida en tienda',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              
              if (order.tipoEntrega == 'domicilio' && order.direccionEntrega.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    order.direccionEntrega,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              
              // Order ID
              const SizedBox(height: 8),
              Text(
                'ID: ${order.id.substring(0, 16)}...',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOnline ? Icons.receipt_long_outlined : Icons.cloud_off_outlined,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _isOnline ? 'No hay pedidos' : 'Sin conexión',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isOnline
                  ? 'Aún no has realizado ningún pedido'
                  : 'Conéctate a internet para ver tus pedidos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            if (_isOnline) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/map'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Crear primer pedido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Error al cargar pedidos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showOrderDetails(Pedido order, PuntoFisico? pharmacy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Title
                Text(
                  'Detalles del pedido',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildDetailRow('Estado', _getStatusText(order.estado), Icons.info_outline, isDark),
                _buildDetailRow('Fecha', DateFormat('d MMMM yyyy, HH:mm').format(order.fechaPedido), Icons.calendar_today, isDark),
                _buildDetailRow('Farmacia', pharmacy?.nombre ?? 'Cargando...', Icons.local_pharmacy, isDark),
                _buildDetailRow('Tipo de entrega', order.tipoEntrega == 'domicilio' ? 'Entrega a domicilio' : 'Recogida en tienda', Icons.local_shipping, isDark),
                if (order.direccionEntrega.isNotEmpty)
                  _buildDetailRow('Dirección', order.direccionEntrega, Icons.location_on, isDark),
                _buildDetailRow('ID del pedido', order.id, Icons.tag, isDark),
                _buildDetailRow('ID de prescripción', order.prescripcionId, Icons.medical_services, isDark),
                
                if (order.fechaEntrega != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Fecha de entrega', DateFormat('d MMMM yyyy').format(order.fechaEntrega!), Icons.check_circle_outline, isDark),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'entregado':
        return Colors.green;
      case 'en_proceso':
        return Colors.blue;
      case 'pendiente':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String estado) {
    switch (estado) {
      case 'entregado':
        return Icons.check_circle;
      case 'en_proceso':
        return Icons.local_shipping;
      case 'pendiente':
        return Icons.schedule;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
  
  String _getStatusText(String estado) {
    switch (estado) {
      case 'entregado':
        return 'Entregado';
      case 'en_proceso':
        return 'En proceso';
      case 'pendiente':
        return 'Pendiente';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }
  
  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      // Don't use locale-specific formatting to avoid initialization issues
      return DateFormat('d MMM, HH:mm').format(lastSync);
    }
  }
}
