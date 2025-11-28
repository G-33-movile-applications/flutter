import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medication_reminder.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';
import '../../services/medicines_repository.dart';
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
  List<MedicationReminder>? _reminders;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reminders = await widget.reminderService.loadReminders();
      if (mounted) {
        setState(() {
          _reminders = reminders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar recordatorios: $e';
          _isLoading = false;
        });
      }
    }
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
      _loadReminders();
    }
  }

  Future<void> _toggleReminder(MedicationReminder reminder) async {
    // Optimistic UI update
    setState(() {
      final index = _reminders!.indexWhere((r) => r.id == reminder.id);
      if (index != -1) {
        _reminders![index] = reminder.copyWith(isActive: !reminder.isActive);
      }
    });

    try {
      await widget.reminderService.toggleReminder(reminder.id, !reminder.isActive);
    } catch (e) {
      // Revert on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar recordatorio: $e')),
        );
        await _loadReminders();
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
        await _loadReminders();
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: const Text(
                'En línea',
                style: TextStyle(fontSize: 12),
              ),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
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
                onPressed: _loadReminders,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reminders == null || _reminders!.isEmpty) {
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
      onRefresh: _loadReminders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _reminders!.length,
        itemBuilder: (context, index) {
          final reminder = _reminders![index];
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

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.Hm();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
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
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Time and recurrence
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFormat.format(DateTime(2000, 1, 1, reminder.time.hour, reminder.time.minute))} - ${reminder.getRecurrenceDisplayText()}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Status chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: const Text('Sincronizado', style: TextStyle(fontSize: 11)),
                        backgroundColor: Colors.green.shade100,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
