import 'package:flutter/material.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/system_conditions_provider.dart';
import 'package:provider/provider.dart';
import '../../../services/user_session.dart';

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
