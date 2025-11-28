import 'package:flutter/material.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/system_conditions_provider.dart';
import 'package:provider/provider.dart';
import '../../../services/user_session.dart';
import '../../../services/auth_service.dart';
import '../../../services/autofill_service.dart';

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

                        // Smart Autofill Section
                        _buildSectionTitle(theme, 'Autocompletado Inteligente'),
                        const SizedBox(height: 12),
                        _buildSmartAutofillSettings(context, theme),
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

  /// Build Smart Autofill settings section
  Widget _buildSmartAutofillSettings(BuildContext context, ThemeData theme) {
    return FutureBuilder<bool>(
      future: Future.value(AutofillService().isEnabled),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? true;
        
        return Column(
          children: [
            _buildSettingCard(
              context: context,
              icon: Icons.auto_awesome_rounded,
              title: 'Autocompletado Inteligente',
              subtitle: 'Sugerencias automáticas basadas en tu historial',
              value: isEnabled,
              onChanged: (value) async {
                await AutofillService().setEnabled(value);
                setState(() {});
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? '✨ Autocompletado Inteligente activado'
                          : 'Autocompletado Inteligente desactivado',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context: context,
              icon: Icons.delete_sweep_rounded,
              title: 'Borrar historial de autocompletado',
              onPressed: () async {
                _showClearAutofillDialog(context, theme);
              },
            ),
            const SizedBox(height: 12),
            _buildAutofillStatistics(context, theme),
          ],
        );
      },
    );
  }

  /// Build autofill statistics widget
  Widget _buildAutofillStatistics(BuildContext context, ThemeData theme) {
    final stats = AutofillService().getStatistics();
    final activeEntries = stats['activeEntries'] ?? 0;
    final fieldsCovered = stats['fieldsCovered'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Estadísticas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow(theme, 'Sugerencias guardadas', '$activeEntries'),
          const SizedBox(height: 6),
          _buildStatRow(theme, 'Campos con sugerencias', '$fieldsCovered'),
        ],
      ),
    );
  }

  /// Build a statistics row
  Widget _buildStatRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// Show dialog to confirm clearing autofill history
  void _showClearAutofillDialog(BuildContext context, ThemeData theme) {
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
          '¿Estás seguro de que deseas borrar todo el historial de autocompletado?\n\n'
          'Esta acción no se puede deshacer y perderás todas las sugerencias aprendidas.',
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
              await AutofillService().clearAllHistory();
              
              if (context.mounted) {
                Navigator.pop(context);
                
                setState(() {}); // Refresh statistics
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🗑️ Historial borrado correctamente'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Borrar'),
          ),
        ],
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
}
