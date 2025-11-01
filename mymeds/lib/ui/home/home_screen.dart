import 'package:flutter/material.dart';
import 'widgets/feature_card.dart';
import 'widgets/motion_debug_bar.dart';
import 'widgets/data_saver_indicator.dart';
import 'widgets/settings_view.dart';
import '../widgets/connectivity_feedback_banner.dart';
import '../../services/user_session.dart';
import '../../services/background_loader.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/user_model.dart';
import '../../models/prescripcion.dart';
import '../../models/pedido.dart';
import '../prescriptions/prescriptions_list_widget.dart';
import 'package:provider/provider.dart';
import '../../providers/motion_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _dialogOpen = false; // Guard to prevent duplicate dialogs
  late TabController _tabController;
  
  // Background loading state
  bool _isLoadingBackground = false;
  bool _hasLoadedFromCache = false;
  List<Prescripcion> _cachedPrescriptions = [];
  List<Pedido> _cachedOrders = [];
  DateTime? _lastRefreshTime; // Track last refresh for debouncing

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Add listener to MotionProvider for confirmation needs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final motionProvider = context.read<MotionProvider>();
      motionProvider.addListener(_checkDrivingConfirmation);
      _checkDrivingConfirmation(); // Initial check
      
      // Start background data loading
      _loadDataWithBackgroundLoader();
    });
  }
  
  /// Load data using background loader with caching strategy
  /// 
  /// Strategy:
  /// 1. Load cached data immediately (instant UI update)
  /// 2. Check cache validity and connectivity
  /// 3. Launch background fetch only if needed (TTL expired or forced)
  /// 4. Update UI when background fetch completes
  /// 5. Handle offline mode gracefully
  Future<void> _loadDataWithBackgroundLoader({bool forceRefresh = false}) async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      debugPrint('🔄 [HomeScreen] No user logged in, skipping data load');
      return;
    }
    
    // Debounce: prevent multiple simultaneous refreshes
    if (_isLoadingBackground && !forceRefresh) {
      debugPrint('⏸️ [HomeScreen] Already loading, skipping duplicate request');
      return;
    }
    
    // Additional debouncing for manual refresh (prevent spam)
    if (forceRefresh && _lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh.inSeconds < 2) {
        debugPrint('⏸️ [HomeScreen] Refresh debounced (${timeSinceLastRefresh.inSeconds}s since last)');
        return;
      }
    }
    
    debugPrint('🔄 [HomeScreen] Starting data load for user: $userId (forceRefresh: $forceRefresh)');
    
    // Step 1: Load from cache first (instant UI)
    _loadFromCache(userId);
    
    // Step 2: Check connectivity status
    final connectivity = ConnectivityService();
    
    // Force a fresh connectivity check
    final isOnline = await connectivity.checkConnectivity();
    
    if (!isOnline) {
      debugPrint('📴 [HomeScreen] Offline - using cached data only');
      if (mounted) {
        setState(() => _hasLoadedFromCache = true);
        
        // Show offline message only on manual refresh
        if (forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📴 Sin conexión - mostrando datos guardados'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      return;
    }
    
    // Step 3: Check if cache is still valid (unless forced refresh)
    if (!forceRefresh && _hasLoadedFromCache) {
      final cacheService = CacheService();
      final cacheKey = 'prescriptions_$userId';
      
      if (cacheService.isValid(cacheKey)) {
        final remainingTtl = cacheService.getRemainingTtl(cacheKey);
        debugPrint('🧠 [HomeScreen] Using valid cache (TTL remaining: ${remainingTtl}s)');
        return;
      } else {
        debugPrint('⏰ [HomeScreen] Cache expired or invalid, fetching fresh data');
      }
    }
    
    // Step 4: Launch background fetch
    setState(() => _isLoadingBackground = true);
    _lastRefreshTime = DateTime.now();
    
    try {
      debugPrint('🚀 [HomeScreen] Launching background data fetch in isolate...');
      
      // Use concurrent loading for maximum parallelism
      final result = await BackgroundLoader.loadUserDataConcurrent(
        userId: userId,
        includeInactive: false,
        includeDelivered: true,
      );
      
      if (!mounted) return;
      
      // Step 5: Update UI with fresh data from background
      final prescriptions = result['prescriptions'] as List<Prescripcion>;
      final orders = result['orders'] as List<Pedido>;
      
      setState(() {
        _cachedPrescriptions = prescriptions;
        _cachedOrders = orders;
        _isLoadingBackground = false;
        _hasLoadedFromCache = true;
      });
      
      // Step 6: Update cache for next load
      _saveToCache(userId, prescriptions, orders);
      
      // Step 7: Update UserSession state
      UserSession().currentPrescripciones.value = prescriptions;
      UserSession().currentPedidos.value = orders;
      
      debugPrint('✅ [HomeScreen] Background load completed successfully');
      debugPrint('   - Prescriptions: ${prescriptions.length}');
      debugPrint('   - Orders: ${orders.length}');
      
      // Show success message on manual refresh
      if (forceRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos actualizados correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error in background data load: $e');
      if (mounted) {
        setState(() => _isLoadingBackground = false);
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasLoadedFromCache 
                ? '⚠️ Error al actualizar, usando datos guardados' 
                : 'Error al cargar datos: ${e.toString()}'),
            backgroundColor: _hasLoadedFromCache ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Load data from cache (instant, synchronous)
  /// 
  /// This provides immediate UI feedback while background fetch runs
  void _loadFromCache(String userId) {
    final cacheService = CacheService();
    
    // Try to load prescriptions from cache
    final cachedPrescriptions = cacheService.get<List<Prescripcion>>(
      'prescriptions_$userId',
    );
    
    // Try to load orders from cache
    final cachedOrders = cacheService.get<List<Pedido>>(
      'orders_$userId',
    );
    
    if (cachedPrescriptions != null || cachedOrders != null) {
      debugPrint('💾 [HomeScreen] Loaded data from cache');
      debugPrint('   - Cached prescriptions: ${cachedPrescriptions?.length ?? 0}');
      debugPrint('   - Cached orders: ${cachedOrders?.length ?? 0}');
      
      setState(() {
        _cachedPrescriptions = cachedPrescriptions ?? [];
        _cachedOrders = cachedOrders ?? [];
        _hasLoadedFromCache = true;
      });
      
      // Update UserSession with cached data
      if (cachedPrescriptions != null) {
        UserSession().currentPrescripciones.value = cachedPrescriptions;
      }
      if (cachedOrders != null) {
        UserSession().currentPedidos.value = cachedOrders;
      }
    } else {
      debugPrint('💾 [HomeScreen] No cached data found');
    }
  }
  
  /// Save data to cache for next load
  void _saveToCache(String userId, List<Prescripcion> prescriptions, List<Pedido> orders) {
    final cacheService = CacheService();
    
    cacheService.set(
      'prescriptions_$userId',
      prescriptions,
      ttl: const Duration(hours: 1), // Cache for 1 hour
    );
    
    cacheService.set(
      'orders_$userId',
      orders,
      ttl: const Duration(hours: 1), // Cache for 1 hour
    );
    
    debugPrint('💾 [HomeScreen] Data saved to cache');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkDrivingConfirmation() {
    if (!mounted) return;
    
    final motionProvider = context.read<MotionProvider>();
    
    // Guard: only show dialog if needed and not already open
    if (motionProvider.needsUserConfirmation && 
        !motionProvider.alertShown && 
        !_dialogOpen) {
      _showDrivingConfirmationDialog();
    }
  }

  void _showDrivingConfirmationDialog() {
    if (_dialogOpen) return; // Extra safety guard
    
    final motionProvider = context.read<MotionProvider>();
    
    // Mark as shown BEFORE showing dialog to prevent duplicates
    motionProvider.markDialogShown();
    _dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Row(
          children: [
            Icon(Icons.directions_car_rounded, 
              color: Theme.of(context).colorScheme.error, 
              size: 32
            ),
            const SizedBox(width: 12),
            Text('¿Estás conduciendo?',
              style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
            ),
          ],
        ),
        content: Text(
          'Detectamos que podrías estar conduciendo. Por tu seguridad, '
          'algunas funciones se desactivarán si confirmas que estás al volante.',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<MotionProvider>().setIsDrivingConfirmed(false);
              Navigator.pop(context);
            },
            child: const Text(
              'No, no estoy conduciendo',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<MotionProvider>().setIsDrivingConfirmed(true);
              Navigator.pop(context);
            },
            child: const Text('Sí, estoy conduciendo'),
          ),
        ],
      ),
    ).whenComplete(() {
      // Reset guard when dialog closes
      if (mounted) {
        context.read<MotionProvider>().markDialogClosed();
        _dialogOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Watch for provider changes (listener will handle confirmation checks)
    context.watch<MotionProvider>();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('HOME'),
            // Show loading indicator when background fetch is running
            if (_isLoadingBackground) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ],
        ),
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configuración',
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          // Refresh button - triggers background reload
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar datos',
            onPressed: _isLoadingBackground ? null : () {
              _loadDataWithBackgroundLoader();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Mis estadísticas',
            onPressed: () {
              Navigator.pushNamed(context, '/stats');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await UserSession().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.home),
              text: 'Inicio',
            ),
            Tab(
              icon: Icon(Icons.medication),
              text: 'Prescripciones',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connectivity feedback banner (shows when offline)
          const ConnectivityFeedbackBanner(),
          // Data Saver indicator (shown when Data Saver Mode is active)
          const DataSaverIndicator(),
          // Background loading status (for debugging/Viva Voce)
          if (_hasLoadedFromCache && _isLoadingBackground)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Actualizando datos en segundo plano...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDataWithBackgroundLoader,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeTab(theme),
                  _buildPrescriptionsTab(),
                ],
              ),
            ),
          ),
          // Debug status bar at bottom
          const MotionDebugBar(),
        ],
      ),
      drawer: const SettingsView(),
    );
  }

  Widget _buildHomeTab(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Greeting section
              _buildGreetingSection(theme),
              const SizedBox(height: 24),
              // Feature cards
              FeatureCard(
                overline: 'FUNCIONALIDAD',
                title: 'Ver mapa de farmacias',
                description: 'Encuentra sucursales EPS cercanas, horarios y stock estimado.',
                icon: Icons.map_rounded,
                buttonText: 'Abrir mapa',
                onPressed: () {
                  Navigator.pushNamed(context, '/map');
                },
              ),
              const SizedBox(height: 16),
              
              FeatureCard(
                overline: 'FUNCIONALIDAD',
                title: 'Sube tu prescripción',
                description: 'Escanea o carga la fórmula para validar y agilizar tu pedido.',
                icon: Icons.upload_file_rounded,
                buttonText: 'Subir',
                onPressed: () {
                  Navigator.pushNamed(context, '/upload');
                },
              ),
              const SizedBox(height: 16),
              
              FeatureCard(
                overline: 'CUENTA',
                title: 'Ver tu perfil',
                description: 'Datos del usuario, preferencias y accesibilidad.',
                icon: Icons.person_rounded,
                buttonText: 'Ver perfil',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: UserSession().currentUser.value?.uid,
                  );
                },
              ),
              
              // Bottom spacing for better scroll experience
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionsTab() {
    return PrescriptionsListWidget(
      onPrescriptionTap: (prescripcion) async {
        // Navigate to map screen to select pharmacy
        final selectedPharmacy = await Navigator.pushNamed(
          context,
          '/map-select',
          arguments: prescripcion,
        );
        
        // If pharmacy was selected, navigate to delivery screen
        if (selectedPharmacy != null && context.mounted) {
          Navigator.pushNamed(
            context,
            '/delivery',
            arguments: {
              'pharmacy': selectedPharmacy,
              'prescripcion': prescripcion,
            },
          );
        }
      },
    );
  }

  Widget _buildGreetingSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<UserModel?>(
        valueListenable: UserSession().currentUser,
        builder: (context, user, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Row(
                children: [
                  Text(
                    'Hola, ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    user != null ? user.fullName.split(' ').first : 'Usuario',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Text(' 👋'),
                ],
              ),
              const SizedBox(height: 4),
              // Status message
              Text(
                user != null 
                    ? '¿Qué deseas hacer hoy?'
                    : 'Inicia sesión para ver tus prescripciones',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              // Data status indicator (for Viva Voce demonstration)
              if (user != null) ...[
                const SizedBox(height: 12),
                _buildDataStatusChip(theme),
              ],
            ],
          );
        },
      ),
    );
  }
  
  /// Build a chip showing data status (cached vs fresh)
  /// This helps demonstrate the background loading feature during Viva Voce
  Widget _buildDataStatusChip(ThemeData theme) {
    IconData icon;
    String label;
    Color color;
    
    if (_isLoadingBackground) {
      icon = Icons.cloud_sync_rounded;
      label = 'Sincronizando...';
      color = Colors.blue;
    } else if (_hasLoadedFromCache) {
      icon = Icons.cloud_done_rounded;
      label = 'Datos actualizados';
      color = Colors.green;
    } else {
      icon = Icons.cloud_off_rounded;
      label = 'Sin conexión';
      color = Colors.orange;
    }
    
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '• ${_cachedPrescriptions.length} prescripciones • ${_cachedOrders.length} pedidos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}