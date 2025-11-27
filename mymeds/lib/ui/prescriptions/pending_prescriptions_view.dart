import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/prescription_draft_cache.dart';
import '../../services/connectivity_service.dart';

/// Pending Prescriptions View
///
/// Shows drafts and prescriptions pending upload/sync.
/// Features:
/// - Lists all draft prescriptions
/// - Shows upload status (pending, uploading, synced)
/// - Allows resuming draft creation
/// - Allows deleting drafts
/// - Offline-friendly UI
class PendingPrescriptionsView extends StatefulWidget {
  const PendingPrescriptionsView({super.key});

  @override
  State<PendingPrescriptionsView> createState() =>
      _PendingPrescriptionsViewState();
}

class _PendingPrescriptionsViewState extends State<PendingPrescriptionsView> {
  final PrescriptionDraftCache _draftCache = PrescriptionDraftCache();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isLoading = true;
  bool _isOnline = true;
  List<String> _draftIds = [];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
    _checkConnectivity();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);

    try {
      final draftIds = _draftCache.getAllDraftIds();

      if (mounted) {
        setState(() {
          _draftIds = draftIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading drafts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar borrador'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este borrador? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _draftCache.removeDraft(draftId);
      _loadDrafts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Borrador eliminado'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _resumeDraft(String draftId) async {
    final draft = _draftCache.getDraft(draftId);
    if (draft == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: borrador no encontrado'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Determine which upload page to navigate to based on draft ID
    String route;
    if (draftId.startsWith('ocr_')) {
      route = '/upload/ocr';
    } else if (draftId.startsWith('nfc_')) {
      route = '/upload/nfc';
    } else {
      // Fallback to general upload page
      route = '/upload';
    }

    // Navigate to appropriate upload screen with draft data
    if (mounted) {
      Navigator.pushNamed(
        context,
        route,
        arguments: {'draftId': draftId, 'draft': draft},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Borradores Pendientes'),
        actions: [
          if (_draftIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Limpiar borradores antiguos',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Limpiar borradores'),
                    content: const Text(
                      '¿Deseas eliminar todos los borradores antiguos (más de 7 días)?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  // Cleanup will be done automatically on next init
                  await _draftCache.init();
                  _loadDrafts();
                }
              },
            ),
        ],
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_draftIds.isEmpty) {
      return _buildEmptyState(theme, isDark);
    }

    return Column(
      children: [
        // Status indicator
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange[800], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Sin conexión - Los borradores se sincronizarán cuando estés online',
                  style: TextStyle(color: Colors.orange[800], fontSize: 12),
                ),
              ],
            ),
          ),

        // Drafts list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDrafts,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _draftIds.length,
              itemBuilder: (context, index) {
                final draftId = _draftIds[index];
                final draft = _draftCache.getDraft(draftId);

                if (draft == null) return const SizedBox.shrink();

                return _buildDraftCard(draft, theme, isDark);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftCard(
    PrescriptionDraft draft,
    ThemeData theme,
    bool isDark,
  ) {
    final dateFormatter = DateFormat('d MMM yyyy, HH:mm');
    final age = DateTime.now().difference(draft.lastModified);
    final ageText = age.inHours < 24
        ? 'Hace ${age.inHours}h'
        : 'Hace ${age.inDays}d';

    // Determine draft type and extract relevant info
    final draftType = draft.data['type'] as String? ?? 'unknown';
    final isOcr = draftType == 'ocr';
    final isNfc = draftType == 'nfc';

    // Extract info based on type
    final String medico;
    final String diagnostico;
    final int medicationCount;
    final int imageCount;

    if (isOcr) {
      medico = draft.data['medico'] as String? ?? 'Sin médico';
      diagnostico = draft.data['diagnostico'] as String? ?? 'Sin diagnóstico';
      medicationCount = (draft.data['medications'] as List?)?.length ?? 0;
      imageCount = draft.data['imageCount'] as int? ?? draft.imagePaths.length;
    } else if (isNfc) {
      final prescriptionData =
          draft.data['prescription'] as Map<String, dynamic>?;
      medico = prescriptionData?['medico'] as String? ?? 'Sin médico';
      diagnostico =
          prescriptionData?['diagnostico'] as String? ?? 'Sin diagnóstico';
      medicationCount = draft.data['medicationCount'] as int? ?? 0;
      imageCount = 0; // NFC has no images
    } else {
      // Fallback for unknown type
      medico = 'Desconocido';
      diagnostico = 'Desconocido';
      medicationCount = 0;
      imageCount = 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _resumeDraft(draft.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status badge + Age
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Borrador',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ageText,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Doctor name
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      medico,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Diagnosis
              Row(
                children: [
                  Icon(
                    Icons.assignment,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      diagnostico,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Images count (for OCR drafts)
              if (imageCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.image,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$imageCount ${imageCount == 1 ? "imagen" : "imágenes"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // Medications count
              if (medicationCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.medication,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$medicationCount ${medicationCount == 1 ? "medicamento" : "medicamentos"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // Draft type badge
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isOcr ? Icons.camera_alt : Icons.nfc,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOcr ? 'OCR / Cámara' : 'NFC',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Last modified
              const SizedBox(height: 8),
              Text(
                'Última modificación: ${dateFormatter.format(draft.lastModified)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
              ),

              // Actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteDraft(draft.id),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _resumeDraft(draft.id),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Continuar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drafts_outlined,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No hay borradores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Los borradores de prescripciones aparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/upload'),
              icon: const Icon(Icons.add),
              label: const Text('Crear prescripción'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
