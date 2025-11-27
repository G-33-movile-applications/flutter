import 'package:flutter/material.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/system_conditions_provider.dart';
import '../../../providers/smart_notification_provider.dart';
import 'package:provider/provider.dart';
import '../../../services/user_session.dart';
import '../../../services/auth_service.dart';

/// Settings drawer widget that slides in from the left
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Configuración',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings content
            Expanded(
              child: Consumer<SettingsProvider>(
                builder: (context, settingsProvider, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Theme Section
                        _buildSectionTitle(theme, 'Tema'),
                        const SizedBox(height: 12),
                        Consumer<SystemConditionsProvider>(
                          builder: (context, systemConditions, child) {
                            return _buildSettingCard(
                              context: context,
                              icon: systemConditions.isDarkMode
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              title: 'Modo Oscuro',
                              subtitle: systemConditions.isDarkMode
                                  ? 'Actualmente en modo oscuro'
                                  : 'Actualmente en modo claro',
                              value: systemConditions.isDarkMode,
                              onChanged: (value) {
                                systemConditions.toggleThemeMode();
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Data Saver Mode Section
                        _buildSectionTitle(theme, 'Datos'),
                        const SizedBox(height: 12),
                        _buildSettingCard(
                          context: context,
                          icon: Icons.data_saver_on_rounded,
                          title: 'Modo Ahorro de Datos',
                          subtitle:
                              'Reduce el consumo de datos cuando está activado',
                          value: settingsProvider.dataSaverModeEnabled,
                          onChanged: (value) {
                            settingsProvider.toggleDataSaverMode(value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? 'Modo Ahorro de Datos activado'
                                      : 'Modo Ahorro de Datos desactivado',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Notifications Section
                        _buildSectionTitle(theme, 'Notificaciones'),
                        const SizedBox(height: 12),
                        _buildSettingCard(
                          context: context,
                          icon: Icons.notifications_rounded,
                          title: 'Notificaciones Generales',
                          subtitle: 'Recibe notificaciones de la aplicación',
                          value: settingsProvider.notificationsEnabled,
                          onChanged: (value) {
                            settingsProvider.toggleNotifications(value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSettingCard(
                          context: context,
                          icon: Icons.notifications_active_rounded,
                          title: 'Notificaciones Push',
                          subtitle:
                              'Notificaciones en tiempo real sobre entregas',
                          value: settingsProvider.pushNotificationsEnabled,
                          enabled:
                              settingsProvider.notificationsEnabled, // Only if general notifications are on
                          onChanged: (value) {
                            settingsProvider.togglePushNotifications(value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSettingCard(
                          context: context,
                          icon: Icons.mail_rounded,
                          title: 'Notificaciones por Email',
                          subtitle: 'Recibe actualizaciones por correo',
                          value: settingsProvider.emailNotificationsEnabled,
                          enabled:
                              settingsProvider.notificationsEnabled, // Only if general notifications are on
                          onChanged: (value) {
                            settingsProvider.toggleEmailNotifications(value);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Smart Notifications Section
                        _buildSectionTitle(theme, 'Notificaciones Inteligentes'),
                        const SizedBox(height: 12),
                        Consumer<SmartNotificationProvider>(
                          builder: (context, smartNotifications, child) {
                            return Column(
                              children: [
                                _buildSettingCard(
                                  context: context,
                                  icon: Icons.psychology_rounded,
                                  title: 'Optimización Inteligente',
                                  subtitle: 'Aprende cuándo prefieres recibir notificaciones',
                                  value: smartNotifications.smartNotificationsEnabled,
                                  enabled: settingsProvider.notificationsEnabled,
                                  onChanged: (value) {
                                    smartNotifications.setSmartNotificationsEnabled(value);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          value
                                              ? '🧠 Notificaciones inteligentes activadas'
                                              : 'Notificaciones inteligentes desactivadas',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildSmartNotificationInfoCard(
                                  context,
                                  theme,
                                  smartNotifications,
                                  settingsProvider,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Account Information Section
                        _buildSectionTitle(theme, 'Cuenta'),
                        const SizedBox(height: 12),
                        _buildAccountInfoCard(context, theme),
                        const SizedBox(height: 24),

                        // Help & Support Section
                        _buildSectionTitle(theme, 'Ayuda'),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context: context,
                          icon: Icons.info_rounded,
                          title: 'Acerca de MyMeds',
                          onPressed: () {
                            _showAboutDialog(context, theme);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context: context,
                          icon: Icons.privacy_tip_rounded,
                          title: 'Política de Privacidad',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Política de privacidad - En desarrollo'),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Logout Section
                        _buildSectionTitle(theme, 'Sesión'),
                        const SizedBox(height: 12),
                        _buildLogoutButton(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Close button at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a section title
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Build a setting card with toggle
  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value && enabled,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build account information card
  Widget _buildAccountInfoCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ValueListenableBuilder(
          valueListenable: UserSession().currentUser,
          builder: (context, user, child) {
            return Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Usuario',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'Sin email',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build an action button
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build logout button
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleLogout(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cerrar Sesión',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.red.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle logout action
  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?\n\n'
          'Se eliminará tu sesión guardada y tendrás que iniciar sesión nuevamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Perform logout
        await AuthService.logout();

        if (context.mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          // Close settings drawer
          Navigator.of(context).pop();

          // Navigate to login screen and remove all previous routes
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sesión cerrada correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          // Close loading dialog if still open
          Navigator.of(context).pop();

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Show about dialog
  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Acerca de MyMeds',
          style: theme.textTheme.titleLarge,
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MyMeds v1.0.0\n\n'
                'Una aplicación para gestionar tus prescripciones y encontrar farmacias cercanas.\n\n'
                '© 2025 MyMeds. Todos los derechos reservados.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Build smart notification info card with analytics and controls
  Widget _buildSmartNotificationInfoCard(
    BuildContext context,
    ThemeData theme,
    SmartNotificationProvider smartNotifications,
    SettingsProvider settingsProvider,
  ) {
    final analytics = smartNotifications.analytics;
    final isEnabled = smartNotifications.smartNotificationsEnabled && 
                      settingsProvider.notificationsEnabled;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Información y Estadísticas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (smartNotifications.analyticsLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Analytics or info message
            if (!isEnabled)
              _buildInfoMessage(
                theme,
                Icons.info_outline_rounded,
                'Activa las notificaciones inteligentes para comenzar a aprender tus preferencias',
                Colors.blue,
              )
            else if (analytics == null || !analytics.hasEnoughData)
              _buildInfoMessage(
                theme,
                Icons.schedule_rounded,
                'Recopilando datos... Se necesitan al menos 20 notificaciones en 7 días para empezar el aprendizaje',
                Colors.orange,
              )
            else
              Column(
                children: [
                  // Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          theme,
                          'Total',
                          analytics.totalNotifications.toString(),
                          Icons.notifications_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          theme,
                          'Abiertos',
                          analytics.openedCount.toString(),
                          Icons.check_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          theme,
                          'Tasa',
                          analytics.openRatePercentage,
                          Icons.trending_up_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days tracked
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rastreando durante ${analytics.daysTracked} días',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Quiet Hours Section
            Row(
              children: [
                Icon(
                  Icons.bedtime_rounded,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Horario Silencioso',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      smartNotifications.quietHoursDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    onPressed: () => _showQuietHoursDialog(
                      context,
                      smartNotifications,
                    ),
                    tooltip: 'Editar horario',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                    onPressed: smartNotifications.analyticsLoading
                        ? null
                        : () async {
                            await smartNotifications.refreshAnalytics();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Estadísticas actualizadas'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.science_rounded, size: 18),
                    label: const Text('Prueba'),
                    onPressed: !isEnabled
                        ? null
                        : () async {
                            await smartNotifications.sendTestNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🧪 Notificación de prueba enviada'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),

            if (analytics != null && analytics.totalNotifications > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Borrar Historial'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () => _showClearHistoryDialog(
                    context,
                    smartNotifications,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build info message
  Widget _buildInfoMessage(
    ThemeData theme,
    IconData icon,
    String message,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build stat box
  Widget _buildStatBox(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Show quiet hours configuration dialog
  void _showQuietHoursDialog(
    BuildContext context,
    SmartNotificationProvider smartNotifications,
  ) {
    int tempStartHour = smartNotifications.quietStartHour;
    int tempEndHour = smartNotifications.quietEndHour;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.bedtime_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Horario Silencioso'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se enviarán notificaciones durante estas horas:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              // Start hour picker
              Row(
                children: [
                  const Expanded(
                    child: Text('Hora de inicio:'),
                  ),
                  DropdownButton<int>(
                    value: tempStartHour,
                    items: List.generate(24, (hour) {
                      return DropdownMenuItem(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        tempStartHour = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // End hour picker
              Row(
                children: [
                  const Expanded(
                    child: Text('Hora de fin:'),
                  ),
                  DropdownButton<int>(
                    value: tempEndHour,
                    items: List.generate(24, (hour) {
                      return DropdownMenuItem(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        tempEndHour = value!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                smartNotifications.setQuietHours(
                  startHour: tempStartHour,
                  endHour: tempEndHour,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Horario silencioso actualizado'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show clear history confirmation dialog
  void _showClearHistoryDialog(
    BuildContext context,
    SmartNotificationProvider smartNotifications,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            const Text('Borrar Historial'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas borrar todo el historial de notificaciones?\n\n'
          'Esta acción eliminará todos los datos de aprendizaje y el sistema '
          'tendrá que empezar desde cero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await smartNotifications.clearHistory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🗑️ Historial borrado correctamente'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Borrar Todo'),
          ),
        ],
      ),
    );
  }
}
