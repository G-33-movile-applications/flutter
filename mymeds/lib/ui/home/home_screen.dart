import 'package:flutter/material.dart';
import 'widgets/feature_card.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';
import '../../models/user_model.dart';
import '../analytics/delivery_analytics_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/motion_provider.dart';
import '../../services/motion_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motionProvider = context.watch<MotionProvider>();
    final motionState = motionProvider.motionState;
    final manualState = motionProvider.manualState;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('HOME'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            // TODO: implement drawer/navigation menu
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Ver estadísticas',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => const DeliveryAnalyticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: implement notifications
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
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting section
                _buildGreetingSection(theme),
                const SizedBox(height: 24),
                // Motion status panel
                _buildMotionStatusPanel(context, motionState, manualState),
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
      ),
    );
  }

  Widget _buildGreetingSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    user != null ? user.fullName.split(' ').first : 'Usuario',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
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
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

Widget _buildMotionStatusPanel(
    BuildContext context,
    MotionState current,
    MotionState? manual,
  ) {
    final motionProvider = context.read<MotionProvider>();

    String stateToEmoji(MotionState s) {
      switch (s) {
        case MotionState.idle:
          return '🪑';
        case MotionState.walking:
          return '🚶‍♂️';
        case MotionState.running:
          return '🏃‍♂️';
        case MotionState.driving:
          return '🚗';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado del movimiento',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          // Current sensor reading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sensor detecta:'),
              Text('${stateToEmoji(current)} ${current.name.toUpperCase()}'),
            ],
          ),

          const SizedBox(height: 12),

          // Manual mode info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Modo manual:'),
              Text(manual != null
                  ? '${stateToEmoji(manual)} ${manual.name.toUpperCase()}'
                  : 'Ninguno'),
            ],
          ),

          const SizedBox(height: 12),

          // Manual buttons
          Wrap(
            spacing: 8,
            children: MotionState.values.map((state) {
              final isActive = manual == state;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isActive ? Colors.blueAccent : Colors.grey[300],
                  foregroundColor: isActive ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  motionProvider.setManualState(isActive ? null : state);
                },
                child: Text(state.name.toUpperCase()),
              );
            }).toList(),
          ),
        ],
      ),
    );
}  
}