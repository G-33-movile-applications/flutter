import 'package:flutter/material.dart';
import '../../models/medicamento_global.dart';
import '../../services/medicine_validation_service.dart';

/// Reusable dialog for handling unknown medicines during prescription upload
/// 
/// Provides options to:
/// - Skip medicine (exclude from prescription)
/// - Save as new medicine (with mock data for admin approval)
/// - Save to unknownMedicines for later review
/// - Search alternative names
class UnknownMedicineDialog extends StatefulWidget {
  final String medicineName;
  final List<MedicamentoGlobal> suggestions;
  
  const UnknownMedicineDialog({
    super.key,
    required this.medicineName,
    this.suggestions = const [],
  });

  /// Show dialog and return user's choice
  /// 
  /// Returns:
  /// - UnknownMedicineAction with selected action and data
  /// - null if cancelled
  static Future<UnknownMedicineAction?> show(
    BuildContext context, {
    required String medicineName,
    List<MedicamentoGlobal> suggestions = const [],
  }) {
    debugPrint('🔔 [UnknownMedicineDialog] Showing dialog for: "$medicineName" with ${suggestions.length} suggestions');
    return showDialog<UnknownMedicineAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnknownMedicineDialog(
        medicineName: medicineName,
        suggestions: suggestions,
      ),
    );
  }

  @override
  State<UnknownMedicineDialog> createState() => _UnknownMedicineDialogState();
}

class _UnknownMedicineDialogState extends State<UnknownMedicineDialog> {
  final _searchController = TextEditingController();
  final _validationService = MedicineValidationService();
  
  bool _isSearching = false;
  List<MedicamentoGlobal> _searchResults = [];
  MedicamentoGlobal? _selectedAlternative;

  @override
  void initState() {
    super.initState();
    _searchResults = widget.suggestions;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAlternatives() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final result = await _validationService.validateMedicine(query);
      
      setState(() {
        _searchResults = result.found 
            ? [result.medicine!, ...result.suggestions]
            : result.suggestions;
        _isSearching = false;
      });

      if (_searchResults.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron medicamentos similares'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Medicamento No Encontrado',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unknown medicine name
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medicamento:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.medicineName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info message
              Text(
                'Este medicamento no está en nuestro catálogo. ¿Qué deseas hacer?',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Search alternatives section
              Text(
                'Buscar Medicamento Alternativo',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar similar...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _searchAlternatives(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSearching ? null : _searchAlternatives,
                    icon: _isSearching
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.search),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),

              // Search results / suggestions
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Medicamentos Similares:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final medicine = _searchResults[index];
                      final isSelected = _selectedAlternative?.id == medicine.id;
                      
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        leading: Radio<String>(
                          value: medicine.id,
                          groupValue: _selectedAlternative?.id,
                          onChanged: (value) {
                            setState(() => _selectedAlternative = medicine);
                          },
                        ),
                        title: Text(
                          medicine.nombre,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${medicine.presentacion} • ${medicine.laboratorio}',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () {
                          setState(() => _selectedAlternative = medicine);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // Skip button
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            UnknownMedicineAction.skip(widget.medicineName),
          ),
          child: const Text('Omitir Medicamento'),
        ),
        
        // Use alternative button (if selected)
        if (_selectedAlternative != null)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(
              UnknownMedicineAction.useAlternative(
                widget.medicineName,
                _selectedAlternative!,
              ),
            ),
            icon: Icon(Icons.check),
            label: const Text('Usar Seleccionado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        
        // Save as new button (if no alternative selected)
        if (_selectedAlternative == null)
          ElevatedButton.icon(
            onPressed: () => _showAddMedicineOptions(),
            icon: Icon(Icons.add),
            label: const Text('Agregar Nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  void _showAddMedicineOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Medicamento'),
        content: const Text(
          '¿Cómo deseas agregar este medicamento?\n\n'
          '• Guardarlo para revisión: Se guardará para que un administrador lo revise.\n\n'
          '• Agregar directamente: Se agregará al catálogo inmediatamente con datos básicos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(
                UnknownMedicineAction.saveForReview(widget.medicineName),
              );
            },
            child: const Text('Guardar para Revisión'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddMedicineForm();
            },
            child: const Text('Agregar Directamente'),
          ),
        ],
      ),
    );
  }

  void _showAddMedicineForm() {
    final nombreController = TextEditingController(text: widget.medicineName);
    final principioActivoController = TextEditingController();
    final presentacionController = TextEditingController(text: 'Tableta');
    final laboratorioController = TextEditingController(text: 'Laboratorio General');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos del Medicamento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: principioActivoController,
                decoration: InputDecoration(
                  labelText: 'Principio Activo',
                  border: OutlineInputBorder(),
                  hintText: 'Opcional',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: presentacionController,
                decoration: InputDecoration(
                  labelText: 'Presentación',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: laboratorioController,
                decoration: InputDecoration(
                  labelText: 'Laboratorio',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre es requerido')),
                );
                return;
              }

              Navigator.of(context).pop();
              Navigator.of(context).pop(
                UnknownMedicineAction.addToGlobal(
                  widget.medicineName,
                  nombre: nombre,
                  principioActivo: principioActivoController.text.trim().isEmpty
                      ? null
                      : principioActivoController.text.trim(),
                  presentacion: presentacionController.text.trim(),
                  laboratorio: laboratorioController.text.trim(),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Action result from UnknownMedicineDialog
class UnknownMedicineAction {
  final UnknownMedicineActionType type;
  final String originalName;
  final MedicamentoGlobal? selectedMedicine;
  final Map<String, String?>? newMedicineData;

  const UnknownMedicineAction._({
    required this.type,
    required this.originalName,
    this.selectedMedicine,
    this.newMedicineData,
  });

  factory UnknownMedicineAction.skip(String originalName) {
    return UnknownMedicineAction._(
      type: UnknownMedicineActionType.skip,
      originalName: originalName,
    );
  }

  factory UnknownMedicineAction.useAlternative(
    String originalName,
    MedicamentoGlobal medicine,
  ) {
    return UnknownMedicineAction._(
      type: UnknownMedicineActionType.useAlternative,
      originalName: originalName,
      selectedMedicine: medicine,
    );
  }

  factory UnknownMedicineAction.saveForReview(String originalName) {
    return UnknownMedicineAction._(
      type: UnknownMedicineActionType.saveForReview,
      originalName: originalName,
    );
  }

  factory UnknownMedicineAction.addToGlobal(
    String originalName, {
    required String nombre,
    String? principioActivo,
    String? presentacion,
    String? laboratorio,
  }) {
    return UnknownMedicineAction._(
      type: UnknownMedicineActionType.addToGlobal,
      originalName: originalName,
      newMedicineData: {
        'nombre': nombre,
        'principioActivo': principioActivo,
        'presentacion': presentacion,
        'laboratorio': laboratorio,
      },
    );
  }
}

enum UnknownMedicineActionType {
  skip,
  useAlternative,
  saveForReview,
  addToGlobal,
}
