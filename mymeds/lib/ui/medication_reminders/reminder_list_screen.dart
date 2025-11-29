import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medication_reminder.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';
import '../../services/medicines_repository.dart';
import '../../services/reminder_sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/user_session.dart';
import '../../widgets/reminder_sync_badge.dart';
import 'new_reminder_screen.dart';

class ReminderListScreen extends StatefulWidget {
  final ReminderService reminderService;
  final NotificationService notificationService;
  final MedicinesRepository medicinesRepository;

  const ReminderListScreen({
    super.key,
    required this.reminderService,
    required this.notificationService,
    required this.medicinesRepository,
  });

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  bool _isLoadingBackground = false; // Background refresh in progress
  bool _hasLoadedFromCache = false; // Cached data loaded
  String? _errorMessage;
  final ReminderSyncService _syncService = ReminderSyncService();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
    
    debugPrint('🔍 [ReminderListScreen] initState - UserSession reminders: ${UserSession().currentReminders.value.length}');
    
    // Listen to UserSession reminders (populated from cache)
    UserSession().currentReminders.addListener(_onRemindersUpdated);
    
    // Check if we already have data from cache
    if (UserSession().currentReminders.value.isNotEmpty) {
      debugPrint('✅ [ReminderListScreen] Data already in UserSession, skipping load');
      _hasLoadedFromCache = true;
    } else {
      // If no data yet, trigger a load
      debugPrint('⚠️ [ReminderListScreen] No data in UserSession, triggering load');
      _loadRemindersWithCache();
    }
  }
  
  @override
  void dispose() {
    UserSession().currentReminders.removeListener(_onRemindersUpdated);
    super.dispose();
  }
  
  void _onRemindersUpdated() {
    if (mounted) {
      setState(() {
        _hasLoadedFromCache = UserSession().currentReminders.value.isNotEmpty;
      });
    }
  }

  /// Request notification permissions when user accesses reminder screen
  Future<void> _requestNotificationPermissions() async {
    try {
      await widget.notificationService.init();
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Load reminders with cache-first strategy
  /// 
  /// Strategy:
  /// 1. Load cached reminders immediately (instant UI update)
  /// 2. Check connectivity
  /// 3. Launch background refresh only if online
  /// 4. Update UI when background fetch completes
  Future<void> _loadRemindersWithCache({bool forceRefresh = false}) async {
    final userId = UserSession().currentUser.value?.uid;
    if (userId == null) {
      setState(() {
        _errorMessage = 'Usuario no autenticado';
      });
      return;
    }
    
    debugPrint('🔄 [ReminderListScreen] Starting data load for user: $userId (forceRefresh: $forceRefresh)');
    
    // Step 1: Check if we already have cached data from UserSession
    if (UserSession().currentReminders.value.isNotEmpty) {
      debugPrint('📦 [ReminderListScreen] Using data from UserSession (${UserSession().currentReminders.value.length} reminders)');
      setState(() => _hasLoadedFromCache = true);
    }
    
    // Step 2: Check connectivity status
    final connectivity = ConnectivityService();
    final isOnline = await connectivity.checkConnectivity();
    
    if (!isOnline && !forceRefresh) {
      debugPrint('📴 [ReminderListScreen] Offline - using cached data only');
      if (mounted && _hasLoadedFromCache) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modo sin conexión - mostrando datos guardados')),
        );
      }
      return;
    }
    
    // Step 3: Launch background fetch
    setState(() => _isLoadingBackground = true);
    
    try {
      debugPrint('🚀 [ReminderListScreen] Launching background fetch...');
      
      final reminders = await _syncService.loadReminders(userId, forceRefresh: forceRefresh);
      
      if (!mounted) return;
      
      // Sort by time
      reminders.sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });
      
      // Update UserSession (which triggers our listener)
      UserSession().currentReminders.value = reminders;
      
      setState(() {
        _isLoadingBackground = false;
        _hasLoadedFromCache = true;
        _errorMessage = null;
      });
      
      debugPrint('✅ [ReminderListScreen] Background fetch completed - ${reminders.length} reminders');
      
    } catch (e) {
      debugPrint('❌ [ReminderListScreen] Error loading reminders: $e');
      if (mounted) {
        setState(() {
          _isLoadingBackground = false;
          if (!_hasLoadedFromCache) {
            _errorMessage = 'Error al cargar recordatorios: $e';
          }
        });
      }
    }
  }
  
  /// Get reminders from UserSession (populated from cache)
  List<MedicationReminder> get _reminders {
    return UserSession().currentReminders.value;
  }

  Future<void> _showNewReminderDialog({MedicationReminder? initialReminder}) async {
    final result = await Navigator.of(context).push<MedicationReminder>(
      MaterialPageRoute(
        builder: (context) => NewReminderScreen(
          reminderService: widget.reminderService,
          medicinesRepository: widget.medicinesRepository,
          initialReminder: initialReminder,
        ),
      ),
    );

    if (result != null) {
      _loadRemindersWithCache();
    }
  }

  Future<void> _toggleReminder(MedicationReminder reminder) async {
    // Don't allow optimistic update for once reminders being activated
    // (need to validate if expired first)
    final shouldOptimisticUpdate = !(reminder.recurrence == RecurrenceType.once && !reminder.isActive);
    
    if (shouldOptimisticUpdate) {
      setState(() {
        final reminders = List<MedicationReminder>.from(_reminders);
        final index = reminders.indexWhere((r) => r.id == reminder.id);
        if (index != -1) {
          reminders[index] = reminder.copyWith(isActive: !reminder.isActive);
          UserSession().currentReminders.value = reminders;
        }
      });
    }

    try {
      await widget.reminderService.toggleReminder(reminder.id, !reminder.isActive);
      // Reload to get the actual state
      await _loadRemindersWithCache();
    } catch (e) {
      // Revert on error and show user-friendly message
      if (mounted) {
        final errorMessage = e.toString().contains('ya ha pasado')
            ? 'Este recordatorio ya pasó su hora. Crea uno nuevo.'
            : 'Error al actualizar recordatorio';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadRemindersWithCache();
      }
    }
  }

  Future<void> _deleteReminder(MedicationReminder reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recordatorio'),
        content: Text('¿Eliminar recordatorio para ${reminder.medicineName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.reminderService.deleteReminder(reminder.id);
        await _loadRemindersWithCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recordatorio eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          // Debug button to test 10-second scheduled notification
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Probar notificación en 10s',
            onPressed: () async {
              try {
                await widget.notificationService.debugScheduleInTenSeconds();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🧪 Notificación programada para 10 segundos'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          // Last sync indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _syncService.getCacheMetadata(UserSession().currentUser.value?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final lastSync = snapshot.data!['lastSync'] as String?;
                  if (lastSync != null) {
                    final lastSyncDate = DateTime.parse(lastSync);
                    final now = DateTime.now();
                    final difference = now.difference(lastSyncDate);
                    final syncText = difference.inMinutes < 1
                        ? 'Ahora'
                        : difference.inMinutes < 60
                            ? '${difference.inMinutes}m'
                            : '${difference.inHours}h';
                    return Chip(
                      avatar: const Icon(Icons.sync, size: 14),
                      label: Text(
                        syncText,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    );
                  }
                }
                return Chip(
                  label: const Text(
                    'En línea',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewReminderDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    // Show loading ONLY if no cached data exists
    if (_isLoadingBackground && !_hasLoadedFromCache) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show error ONLY if no cached data exists
    if (_errorMessage != null && !_hasLoadedFromCache) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadRemindersWithCache(forceRefresh: true),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no tienes recordatorios',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Agrega un recordatorio para tus medicamentos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showNewReminderDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar recordatorio'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRemindersWithCache(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return ReminderListItem(
            reminder: reminder,
            onToggle: () => _toggleReminder(reminder),
            onEdit: () => _showNewReminderDialog(initialReminder: reminder),
            onDelete: () => _deleteReminder(reminder),
          );
        },
      ),
    );
  }
}

class ReminderListItem extends StatelessWidget {
  final MedicationReminder reminder;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ReminderListItem({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  /// Check if a \"once\" reminder is expired
  bool get _isExpiredOnceReminder {
    if (reminder.recurrence != RecurrenceType.once) return false;
    
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );
    
    return scheduledTime.isBefore(now.subtract(const Duration(minutes: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.Hm();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isExpired = _isExpiredOnceReminder;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      color: isExpired && !reminder.isActive ? Colors.grey.shade100 : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - reminder details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medicine name
                  Text(
                    reminder.medicineName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isExpired && !reminder.isActive ? Colors.grey.shade600 : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Time and recurrence
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: isExpired && !reminder.isActive ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFormat.format(DateTime(2000, 1, 1, reminder.time.hour, reminder.time.minute))} - ${reminder.getRecurrenceDisplayText()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isExpired && !reminder.isActive ? Colors.grey.shade600 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Status chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isExpired && !reminder.isActive)
                        Chip(
                          label: const Text('Expirado', style: TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: Colors.grey.shade600,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )
                      else
                        // Show sync badge
                        ReminderSyncBadge(
                          syncStatus: reminder.syncStatus,
                          showLabel: true,
                          size: 14,
                        ),
                      if (reminder.isActive)
                        Chip(
                          label: const Text('Activo', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade100,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Created date
                  Text(
                    'Creado: ${dateFormat.format(reminder.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            
            // Right side - controls
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit,
                      tooltip: 'Editar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: onDelete,
                      tooltip: 'Eliminar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Switch(
                  value: reminder.isActive,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
