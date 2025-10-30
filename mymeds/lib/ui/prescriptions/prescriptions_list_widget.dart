import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/prescripcion.dart';
import '../../services/user_session.dart';

class PrescriptionsListWidget extends StatefulWidget {
  final Function(Prescripcion)? onPrescriptionTap;
  
  const PrescriptionsListWidget({
    super.key,
    this.onPrescriptionTap,
  });

  @override
  State<PrescriptionsListWidget> createState() => _PrescriptionsListWidgetState();
}

class _PrescriptionsListWidgetState extends State<PrescriptionsListWidget> {
  bool _isLoading = true;
  List<Prescripcion> _prescripciones = [];
  String? _errorMessage;
  String _filterStatus = 'all'; // 'all', 'active', 'inactive'
  
  @override
  void initState() {
    super.initState();
    _loadPrescripciones();
  }

  Future<void> _loadPrescripciones() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .get();

      final prescripciones = snapshot.docs
          .map((doc) => Prescripcion.fromMap(doc.data(), documentId: doc.id))
          .toList();

      // Sort: active first, then by date (newest first)
      prescripciones.sort((a, b) {
        if (a.activa != b.activa) {
          return a.activa ? -1 : 1; // Active first
        }
        return b.fechaCreacion.compareTo(a.fechaCreacion); // Newest first
      });

      setState(() {
        _prescripciones = prescripciones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando prescripciones: $e';
        _isLoading = false;
      });
    }
  }

  List<Prescripcion> get _filteredPrescripciones {
    if (_filterStatus == 'all') {
      return _prescripciones;
    } else if (_filterStatus == 'active') {
      return _prescripciones.where((p) => p.activa).toList();
    } else {
      return _prescripciones.where((p) => !p.activa).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter chips
        _buildFilterChips(),
        const SizedBox(height: 16),
        
        // Prescriptions list
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todas',
            value: 'all',
            count: _prescripciones.length,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Activas',
            value: 'active',
            count: _prescripciones.where((p) => p.activa).length,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Inactivas',
            value: 'inactive',
            count: _prescripciones.where((p) => !p.activa).length,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final isSelected = _filterStatus == value;
    final theme = Theme.of(context);
    
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterStatus = value;
          });
        }
      },
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPrescripciones,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredList = _filteredPrescripciones;

    if (filteredList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _filterStatus == 'all'
                    ? 'No tienes prescripciones'
                    : 'No hay prescripciones ${_filterStatus == "active" ? "activas" : "inactivas"}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sube una prescripción para comenzar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/upload');
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir Prescripción'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPrescripciones,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final prescripcion = filteredList[index];
          return _buildPrescripcionCard(prescripcion);
        },
      ),
    );
  }

  Widget _buildPrescripcionCard(Prescripcion prescripcion) {
    final isActive = prescripcion.activa;
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: isActive
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Activa' : 'Inactiva',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Date
                  Text(
                    _formatDate(prescripcion.fechaCreacion),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Doctor
              Row(
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Médico',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          prescripcion.medico.isNotEmpty
                              ? prescripcion.medico
                              : 'No especificado',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Diagnosis
              if (prescripcion.diagnostico.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnóstico',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            prescripcion.diagnostico,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Action button for active prescriptions
              if (isActive && widget.onPrescriptionTap != null) ...[
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => widget.onPrescriptionTap!(prescripcion),
                      icon: const Icon(Icons.local_pharmacy, size: 18),
                      label: const Text('Buscar Farmacia'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 2,
                        shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: const Size(140, 36),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks ${weeks == 1 ? "semana" : "semanas"}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? "mes" : "meses"}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Hace $years ${years == 1 ? "año" : "años"}';
    }
  }
}
