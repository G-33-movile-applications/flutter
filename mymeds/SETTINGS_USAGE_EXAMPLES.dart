/// Example Usage Patterns for Settings in MyMeds App
///
/// This file demonstrates how to use the Settings system in various parts of the application.
/// Copy and adapt these patterns for your needs.

// ============================================================================
// EXAMPLE 1: Using Data Saver Mode in Image Downloads
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PrescriptionImageViewer extends StatelessWidget {
  final String imageUrl;

  const PrescriptionImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isSaverMode = context.watch<SettingsProvider>().dataSaverModeEnabled;

    return Image.network(
      imageUrl,
      cacheHeight: isSaverMode ? 200 : 400,
      cacheWidth: isSaverMode ? 300 : 600,
      filterQuality: isSaverMode ? FilterQuality.low : FilterQuality.high,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
  }
}

// ============================================================================
// EXAMPLE 2: Checking Notifications Before Sending
// ============================================================================

class NotificationService {
  Future<void> sendDeliveryNotification(String message) async {
    final context = /* Get context somehow */;
    final settingsProvider = context.read<SettingsProvider>();

    // Check settings before sending any notification
    if (!settingsProvider.notificationsEnabled) {
      debugPrint('Notifications are disabled by user');
      return;
    }

    // Check specific notification type
    if (shouldSendPushNotification() &&
        !settingsProvider.pushNotificationsEnabled) {
      debugPrint('Push notifications are disabled');
      return;
    }

    if (shouldSendEmailNotification() &&
        !settingsProvider.emailNotificationsEnabled) {
      debugPrint('Email notifications are disabled');
      return;
    }

    // Send notification
    _actuallyNotify(message);
  }

  bool shouldSendPushNotification() => true;
  bool shouldSendEmailNotification() => false;
  void _actuallyNotify(String message) {}
}

// ============================================================================
// EXAMPLE 3: Auto-Refresh Based on Data Saver Mode
// ============================================================================

class PharmacyListWidget extends StatefulWidget {
  const PharmacyListWidget({super.key});

  @override
  State<PharmacyListWidget> createState() => _PharmacyListWidgetState();
}

class _PharmacyListWidgetState extends State<PharmacyListWidget> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  void _setupAutoRefresh() {
    final settings = context.read<SettingsProvider>();

    // Cancel any existing timer
    _refreshTimer?.cancel();

    // Set refresh interval based on data saver mode
    final Duration refreshInterval =
        settings.dataSaverModeEnabled ? Duration(minutes: 5) : Duration(seconds: 30);

    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      _refreshPharmacies();
    });
  }

  void _refreshPharmacies() {
    debugPrint('Refreshing pharmacies...');
    // Implement refresh logic
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-setup timer if settings changed
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

// ============================================================================
// EXAMPLE 4: Conditional Features Based on Settings
// ============================================================================

class DeliveryMapScreen extends StatelessWidget {
  const DeliveryMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return GoogleMap(
          // Disable location tracking if data saver is on
          myLocationEnabled: !settings.dataSaverModeEnabled,
          // Reduce update frequency in data saver mode
          myLocationButtonEnabled: !settings.dataSaverModeEnabled,
          compassEnabled: !settings.dataSaverModeEnabled,
          trafficEnabled: !settings.dataSaverModeEnabled,
          zoomControlsEnabled: true,
        );
      },
    );
  }
}

// ============================================================================
// EXAMPLE 5: Reading Settings in a Service
// ============================================================================

class AnalyticsService {
  final BuildContext context;

  AnalyticsService(this.context);

  /// Log an event, respecting user privacy settings
  Future<void> logEvent(String eventName, Map<String, dynamic> parameters) async {
    final settings = context.read<SettingsProvider>();

    // Don't send analytics if notifications are disabled
    // (user likely wants privacy)
    if (!settings.notificationsEnabled) {
      debugPrint('Analytics disabled - user has notifications turned off');
      return;
    }

    // Send analytics
    debugPrint('Logging event: $eventName with $parameters');
  }

  /// Get analytics batch size based on data saver mode
  int getAnalyticsBatchSize() {
    final settings = context.read<SettingsProvider>();
    return settings.dataSaverModeEnabled ? 10 : 50;
  }
}

// ============================================================================
// EXAMPLE 6: Listening to Settings Changes
// ============================================================================

class SmartPrescriptionReminder extends StatefulWidget {
  const SmartPrescriptionReminder({super.key});

  @override
  State<SmartPrescriptionReminder> createState() =>
      _SmartPrescriptionReminderState();
}

class _SmartPrescriptionReminderState extends State<SmartPrescriptionReminder> {
  late SettingsProvider _settingsProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settingsProvider = context.read<SettingsProvider>();
    _settingsProvider.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    // Adjust reminder behavior when settings change
    if (_settingsProvider.notificationsEnabled) {
      _scheduleReminderNotifications();
    } else {
      _cancelReminderNotifications();
    }
  }

  void _scheduleReminderNotifications() {
    debugPrint('Scheduling prescription reminders...');
  }

  void _cancelReminderNotifications() {
    debugPrint('Cancelling prescription reminders...');
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

// ============================================================================
// EXAMPLE 7: Resetting Settings (Advanced)
// ============================================================================

class SettingsManagementScreen extends StatelessWidget {
  const SettingsManagementScreen({super.key});

  void _resetSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer Configuración'),
        content: const Text(
          '¿Estás seguro de que deseas restablecer toda la configuración a los valores predeterminados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsProvider>().resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuración restablecida'),
                ),
              );
            },
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _resetSettings(context),
      child: const Text('Restablecer Configuración'),
    );
  }
}

// ============================================================================
// EXAMPLE 8: Settings Validation and Dependent Logic
// ============================================================================

class NotificationConfigValidator {
  static Future<bool> canSendNotification(
    BuildContext context, {
    required NotificationType type,
  }) async {
    final settings = context.read<SettingsProvider>();

    // General notifications must be enabled
    if (!settings.notificationsEnabled) return false;

    // Check specific type
    switch (type) {
      case NotificationType.push:
        return settings.pushNotificationsEnabled;
      case NotificationType.email:
        return settings.emailNotificationsEnabled;
    }
  }

  static Future<void> ensureNotificationsEnabled(
    BuildContext context, {
    required NotificationType type,
  }) async {
    final canSend = await canSendNotification(context, type: type);
    if (!canSend) {
      // Optionally open settings to enable notifications
      if (context.mounted) {
        Scaffold.of(context).openDrawer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, habilita las notificaciones en Configuración'),
          ),
        );
      }
    }
  }
}

enum NotificationType { push, email }

// ============================================================================
// EXAMPLE 9: Performance Optimization Based on Settings
// ============================================================================

class OptimizedImageCache {
  static int getMaxImageCacheSize(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    // Data saver mode: smaller cache
    if (settings.dataSaverModeEnabled) {
      return 50 * 1024 * 1024; // 50 MB
    }

    // Normal mode: larger cache
    return 200 * 1024 * 1024; // 200 MB
  }

  static bool shouldPrecacheMaps(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    // Don't precache maps if data saver is enabled
    return !settings.dataSaverModeEnabled;
  }
}

// ============================================================================
// EXAMPLE 10: Settings-Aware User Experience
// ============================================================================

class SmartUserExperienceManager {
  static void adjustAppBehavior(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    if (settings.dataSaverModeEnabled) {
      // Data Saver Adjustments
      debugPrint('Enabling data saver optimizations:');
      debugPrint('- Reduced image quality');
      debugPrint('- Disabled auto-sync');
      debugPrint('- Reduced animation frame rate');
      debugPrint('- Larger cache intervals');
    }

    if (!settings.notificationsEnabled) {
      debugPrint('Notifications disabled - adjusting UX');
    }

    if (!settings.pushNotificationsEnabled) {
      debugPrint('Push notifications disabled - using in-app alerts only');
    }

    if (!settings.emailNotificationsEnabled) {
      debugPrint('Email notifications disabled - no email updates');
    }
  }
}

// ============================================================================
// HOW TO USE THESE EXAMPLES
// ============================================================================
/*

1. IMPORTING:
   - Make sure SettingsProvider is available in your context
   - Add it to pubspec.yaml: provider: ^6.1.5+1

2. ACCESSING SETTINGS:
   
   // Read value once (for actions, not rebuilds)
   final dataSaver = context.read<SettingsProvider>().dataSaverModeEnabled;
   
   // Watch for changes (rebuilds widget when value changes)
   final dataSaver = context.watch<SettingsProvider>().dataSaverModeEnabled;
   
   // Consumer widget (scoped watching)
   Consumer<SettingsProvider>(
     builder: (context, settings, _) => Text(settings.dataSaverModeEnabled ? 'ON' : 'OFF'),
   )

3. UPDATING SETTINGS:
   
   await context.read<SettingsProvider>().toggleDataSaverMode(true);

4. LISTENING TO CHANGES:
   
   context.read<SettingsProvider>().addListener(() {
     debugPrint('Settings changed!');
   });

5. TESTING:
   
   testWidgets('Widget respects data saver mode', (tester) async {
     await tester.pumpWidget(
       MultiProvider(
         providers: [
           ChangeNotifierProvider(
             create: (_) => SettingsProvider()..toggleDataSaverMode(true),
           ),
         ],
         child: const YourWidget(),
       ),
     );
     expect(find.byType(YourWidget), findsOneWidget);
   });

*/
