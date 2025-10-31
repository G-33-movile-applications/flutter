import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/connectivity_service.dart';
import 'package:provider/provider.dart';

/// Indicator widget that shows when Data Saver Mode is active
/// 
/// Displays:
/// - Banner showing Data Saver is active
/// - Current connection type (Wi-Fi, Mobile, Offline)
/// - Sync queue status if Data Saver is enabled
class DataSaverIndicator extends StatelessWidget {
  const DataSaverIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        if (!settingsProvider.dataSaverModeEnabled) {
          return const SizedBox.shrink();
        }

        final connectionType = settingsProvider.currentConnectionType;
        final queueSize = settingsProvider.syncQueueSize;
        final isWiFi = connectionType == ConnectionType.wifi;
        final isMobile = connectionType == ConnectionType.mobile;
        final isOffline = connectionType == ConnectionType.none;

        String connectionText = 'Desconectado';
        IconData connectionIcon = Icons.cloud_off_rounded;
        Color connectionColor = Colors.grey;

        if (isWiFi) {
          connectionText = 'Wi-Fi conectado';
          connectionIcon = Icons.wifi_rounded;
          connectionColor = Colors.green;
        } else if (isMobile) {
          connectionText = 'Datos móviles';
          connectionIcon = Icons.signal_cellular_alt_rounded;
          connectionColor = Colors.orange;
        }

        return Column(
          children: [
            // Main Data Saver banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Light blue background
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Data Saver icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.data_saver_on_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Modo Ahorro de Datos',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            // Active indicator dot
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              connectionIcon,
                              size: 14,
                              color: connectionColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              connectionText,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                            if (queueSize > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• $queueSize sync pendiente${queueSize > 1 ? 's' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Info icon
                  Icon(
                    Icons.info_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            // Secondary info banner if offline
            if (isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estás offline. La app funcionará solo con datos en caché.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.red,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            // Sync queue pending banner
            if (queueSize > 0 && !isWiFi)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.orange.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esperando Wi-Fi para sincronizar $queueSize operación${queueSize > 1 ? 'es' : ''}...',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.orange,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
