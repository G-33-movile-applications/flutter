import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/prescripcion_with_medications.dart';
import '../../../models/medicamento_prescripcion.dart';

/// Reusable widget to display prescription details with medications
/// 
/// Shows: medico, diagnostico, fechaCreacion, and list of medications
/// with their dosage information loaded from Firestore subcollections.
class PrescriptionPreviewWidget extends StatelessWidget {
  final PrescripcionWithMedications prescription;
  final VoidCallback? onEdit;
  final VoidCallback? onUpload;
  final bool showActions;
  final bool isLoading;

  const PrescriptionPreviewWidget({
    super.key,
    required this.prescription,
    this.onEdit,
    this.onUpload,
    this.showActions = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Prescripción Médica',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (prescription.activa)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Text(
                      'ACTIVA',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.error),
                    ),
                    child: Text(
                      'INACTIVA',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const Divider(height: 24),

            // Prescription details
            _buildInfoRow(
              icon: Icons.person,
              label: 'Médico',
              value: prescription.medico,
              theme: theme,
            ),
            const SizedBox(height: 12),
            
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Fecha',
              value: dateFormatter.format(prescription.fechaCreacion),
              theme: theme,
            ),
            const SizedBox(height: 12),
            
            _buildInfoRow(
              icon: Icons.description,
              label: 'Diagnóstico',
              value: prescription.diagnostico,
              theme: theme,
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            // Medications section
            Row(
              children: [
                Icon(
                  Icons.medication,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Medicamentos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${prescription.medicationCount}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (prescription.hasMedications)
              ...prescription.medicamentos.map((med) => _buildMedicationCard(med, theme))
            else
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No hay medicamentos en esta prescripción',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Action buttons
            if (showActions) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  if (onEdit != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (onEdit != null && onUpload != null) const SizedBox(width: 12),
                  if (onUpload != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : onUpload,
                        icon: isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(isLoading ? 'Subiendo...' : 'Subir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(MedicamentoPrescripcion med, ThemeData theme) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    med.nombre,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!med.activo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.error),
                    ),
                    child: Text(
                      'INACTIVO',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMedicationDetail(
              'Dosis',
              '${med.dosisMg} mg',
              theme,
            ),
            _buildMedicationDetail(
              'Frecuencia',
              'Cada ${med.frecuenciaHoras} horas',
              theme,
            ),
            _buildMedicationDetail(
              'Duración',
              '${med.duracionDias} días',
              theme,
            ),
            _buildMedicationDetail(
              'Período',
              '${dateFormatter.format(med.fechaInicio)} - ${dateFormatter.format(med.fechaFin)}',
              theme,
            ),
            if (med.observaciones != null && med.observaciones!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Observaciones: ${med.observaciones}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationDetail(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
