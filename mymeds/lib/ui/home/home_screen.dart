import 'package:flutter/material.dart';
import 'widgets/feature_card.dart';
import 'widgets/motion_debug_bar.dart';
import 'widgets/data_saver_indicator.dart';
import 'widgets/settings_view.dart';
import '../widgets/connectivity_feedback_banner.dart';
import '../../services/user_session.dart';
import '../../models/user_model.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Add listener to MotionProvider for confirmation needs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final motionProvider = context.read<MotionProvider>();
      motionProvider.addListener(_checkDrivingConfirmation);
      _checkDrivingConfirmation(); // Initial check
    });
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
        title: const Text('HOME'),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHomeTab(theme),
                _buildPrescriptionsTab(),
              ],
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
            ],
          );
        },
      ),
    );
  }
}