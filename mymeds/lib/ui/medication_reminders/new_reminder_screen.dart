import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medication_reminder.dart';
import '../../models/medicine.dart';
import '../../services/reminder_scheduling_service.dart';
import '../../services/medicines_repository.dart';

class NewReminderScreen extends StatefulWidget {
  final MedicinesRepository medicinesRepository;
  final MedicationReminder? initialReminder;

  const NewReminderScreen({
    super.key,
    required this.medicinesRepository,
    this.initialReminder,
  });

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _timeController = TextEditingController();

  List<Medicine>? _availableMedicines;
  Medicine? _selectedMedicine;
  TimeOfDay? _selectedTime;
  RecurrenceType _recurrence = RecurrenceType.daily;
  Set<DayOfWeek> _selectedDays = {};
  bool _isActive = true;
  bool _isLoadingMedicines = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _initializeFromReminder();
  }

  Future<void> _loadMedicines() async {
    try {
      final medicines = await widget.medicinesRepository.getUserMedicines();
      if (mounted) {
        setState(() {
          _availableMedicines = medicines;
          _isLoadingMedicines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableMedicines = [];
          _isLoadingMedicines = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar medicamentos: $e')),
        );
      }
    }
  }

  void _initializeFromReminder() {
    if (widget.initialReminder != null) {
      final reminder = widget.initialReminder!;
      _medicineNameController.text = reminder.medicineName;
      _selectedTime = reminder.time;
      _timeController.text = _formatTime(reminder.time);
      _recurrence = reminder.recurrence;
      _selectedDays = Set.from(reminder.specificDays);
      _isActive = reminder.isActive;
    }
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.Hm().format(dt);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
        _timeController.text = _formatTime(time);
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate() || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos requeridos')),
      );
      return;
    }

    if (_recurrence == RecurrenceType.specificDays && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día de la semana')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final reminder = MedicationReminder(
        id: widget.initialReminder?.id ?? '',
        medicineId: _selectedMedicine?.id ?? '',
        medicineName: _medicineNameController.text,
        time: _selectedTime!,
        recurrence: _recurrence,
        specificDays: _selectedDays,
        isActive: _isActive,
        createdAt: widget.initialReminder?.createdAt ?? DateTime.now(),
      );

      // Use ReminderSchedulingService instead of ReminderService
      final schedulingService = ReminderSchedulingService();
      final savedReminder = widget.initialReminder == null
          ? await schedulingService.createReminder(reminder)
          : await schedulingService.updateReminder(reminder);

      if (mounted) {
        Navigator.of(context).pop(savedReminder);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReminder != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar recordatorio' : 'Nuevo recordatorio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Medicine selection
            Text(
              'Seleccionar medicamento de tus medicamentos:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildMedicineDropdown(),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Custom name
            Text(
              'O ingresa un nombre personalizado',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicineNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del medicamento',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa un nombre de medicamento';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Time
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Hora (HH:mm)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              onTap: _pickTime,
              validator: (value) {
                if (_selectedTime == null) {
                  return 'Selecciona una hora';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Frequency
            Text(
              'Frecuencia',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildFrequencySelection(),

            if (_recurrence == RecurrenceType.specificDays) ...[
              const SizedBox(height: 16),
              _buildDaySelection(),
            ],

            const SizedBox(height: 24),

            // Notifications toggle
            Card(
              child: SwitchListTile(
                title: const Text('Notificaciones'),
                subtitle: const Text('Recibir recordatorios a la hora indicada'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveReminder,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineDropdown() {
    if (_isLoadingMedicines) {
      return const LinearProgressIndicator();
    }

    if (_availableMedicines == null || _availableMedicines!.isEmpty) {
      return const Text(
        'No hay medicamentos disponibles',
        style: TextStyle(color: Colors.grey),
      );
    }

    return DropdownButtonFormField<Medicine>(
      value: _selectedMedicine,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Selecciona un medicamento',
      ),
      items: _availableMedicines!.map((medicine) {
        return DropdownMenuItem(
          value: medicine,
          child: Text(medicine.name),
        );
      }).toList(),
      onChanged: (medicine) {
        setState(() {
          _selectedMedicine = medicine;
          if (medicine != null) {
            _medicineNameController.text = medicine.name;
          }
        });
      },
    );
  }

  Widget _buildFrequencySelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Diario'),
          selected: _recurrence == RecurrenceType.daily,
          onSelected: (selected) {
            if (selected) setState(() => _recurrence = RecurrenceType.daily);
          },
        ),
        ChoiceChip(
          label: const Text('Semanal'),
          selected: _recurrence == RecurrenceType.weekly,
          onSelected: (selected) {
            if (selected) setState(() => _recurrence = RecurrenceType.weekly);
          },
        ),
        ChoiceChip(
          label: const Text('Una vez'),
          selected: _recurrence == RecurrenceType.once,
          onSelected: (selected) {
            if (selected) setState(() => _recurrence = RecurrenceType.once);
          },
        ),
        ChoiceChip(
          label: const Text('Días específicos'),
          selected: _recurrence == RecurrenceType.specificDays,
          onSelected: (selected) {
            if (selected) setState(() => _recurrence = RecurrenceType.specificDays);
          },
        ),
      ],
    );
  }

  Widget _buildDaySelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DayOfWeek.values.map((day) {
        final isSelected = _selectedDays.contains(day);
        return FilterChip(
          label: Text(day.abbreviation),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(day);
              } else {
                _selectedDays.remove(day);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
