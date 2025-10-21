import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../models/prescripcion.dart';
import '../../services/ocr_service.dart';
import '../../services/user_session.dart';
import '../../repositories/prescripcion_repository.dart';
import '../../theme/app_theme.dart';

class OcrUploadPage extends StatefulWidget {
  const OcrUploadPage({super.key});

  @override
  State<OcrUploadPage> createState() => _OcrUploadPageState();
}

class _OcrUploadPageState extends State<OcrUploadPage> {
  final OcrService _ocrService = OcrService();
  final PrescripcionRepository _prescripcionRepo = PrescripcionRepository();

  File? _selectedImage;
  String? _extractedText;
  bool _isProcessing = false;
  bool _isUploading = false;
  
  // Editable prescription data
  final TextEditingController _medicoController = TextEditingController();
  final TextEditingController _diagnosticoController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  // Editable medications data
  final List<Map<String, dynamic>> _medications = [];

  @override
  void dispose() {
    _medicoController.dispose();
    _diagnosticoController.dispose();
    super.dispose();
  }

  Future<void> _handleCameraCapture() async {
    setState(() {
      _isProcessing = true;
      _selectedImage = null;
      _extractedText = null;
      _medications.clear();
    });

    try {
      final image = await _ocrService.capturePhoto();
      
      if (image == null) {
        _showInfoSnackBar('Captura cancelada');
        return;
      }

      await _processImage(image);
    } on PlatformException catch (e) {
      debugPrint('Camera permission error: $e');
      if (e.code == 'camera_access_denied' || 
          e.message?.toLowerCase().contains('permission') == true) {
        _showPermissionDeniedDialog(
          'Permisos de Cámara',
          'La aplicación necesita acceso a la cámara para tomar fotos de las prescripciones.\n\n'
          'Por favor, ve a Configuración > Aplicaciones > MyMeds > Permisos y activa el permiso de Cámara.',
        );
      } else {
        _showErrorSnackBar('Error al acceder a la cámara: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('Camera capture error: $e');
      _showErrorSnackBar('Error al capturar imagen: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleGalleryPick() async {
    setState(() {
      _isProcessing = true;
      _selectedImage = null;
      _extractedText = null;
      _medications.clear();
    });

    try {
      final image = await _ocrService.pickImageFromGallery();
      
      if (image == null) {
        _showInfoSnackBar('Selección cancelada');
        return;
      }

      await _processImage(image);
    } on PlatformException catch (e) {
      debugPrint('Storage permission error: $e');
      if (e.code == 'photo_access_denied' || 
          e.code == 'read_external_storage_denied' ||
          e.message?.toLowerCase().contains('permission') == true) {
        _showPermissionDeniedDialog(
          'Permisos de Almacenamiento',
          'La aplicación necesita acceso a tus fotos y archivos para seleccionar imágenes.\n\n'
          'Por favor, ve a Configuración > Aplicaciones > MyMeds > Permisos y activa el permiso de Almacenamiento/Fotos.',
        );
      } else {
        _showErrorSnackBar('Error al acceder a la galería: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      _showErrorSnackBar('Error al seleccionar imagen: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(File image) async {
    setState(() {
      _selectedImage = image;
      _isProcessing = true;
    });

    try {
      // Extract text from image
      final text = await _ocrService.extractTextFromFile(image);
      
      if (text.isEmpty) {
        _showErrorSnackBar('No se pudo extraer texto de la imagen');
        return;
      }

      setState(() => _extractedText = text);

      // Parse prescription data with improved algorithm
      final parsedData = await _ocrService.parsePrescriptionText(text);
      
      // Get confidence score
      final confidence = parsedData['_confidence'] as int? ?? 0;
      
      // Populate controllers with parsed data
      _medicoController.text = parsedData['doctor'] ?? '';
      _diagnosticoController.text = parsedData['diagnosis'] ?? '';
      
      if (parsedData['date'] != null) {
        _selectedDate = parsedData['date'] as DateTime;
      }

      // Parse medications
      // Parse date if found
      if (parsedData['date'] != null && parsedData['date'] is DateTime) {
        _selectedDate = parsedData['date'] as DateTime;
      }

      // Parse medications
      if (parsedData['medications'] != null && parsedData['medications'] is List) {
        final medsList = parsedData['medications'] as List;
        setState(() {
          _medications.clear();
          for (var med in medsList) {
            _medications.add({
              'nombre': med['name'] ?? 'Medicamento',
              'dosisMg': (med['dosage'] ?? 500.0),
              'frecuenciaHoras': med['frequency'] ?? 8,
              'duracionDias': med['duration'] ?? 7,
              'observaciones': med['notes'] ?? '',
              'controller_nombre': TextEditingController(text: med['name'] ?? 'Medicamento'),
              'controller_dosis': TextEditingController(text: (med['dosage'] ?? 500.0).toString()),
              'controller_frecuencia': TextEditingController(text: (med['frequency'] ?? 8).toString()),
              'controller_duracion': TextEditingController(text: (med['duration'] ?? 7).toString()),
              'controller_observaciones': TextEditingController(text: med['notes'] ?? ''),
            });
          }
        });
      }

      // If no medications found, add one empty medication
      if (_medications.isEmpty) {
        _addEmptyMedication();
      }

      // Show success with confidence score
      if (confidence >= 70) {
        _showSuccessSnackBar('Texto extraído exitosamente (Confianza: $confidence%)');
      } else if (confidence >= 40) {
        _showInfoSnackBar('Texto extraído con confianza media ($confidence%). Por favor revisa los datos.');
      } else {
        _showErrorSnackBar('Confianza baja ($confidence%). Por favor revisa y corrige los datos manualmente.');
      }
      
      // Show improved confirmation dialog to review extracted data
      await Future.delayed(const Duration(milliseconds: 500));
      _showExtractedDataReview(confidence: confidence, parsedData: parsedData);
    } catch (e) {
      debugPrint('OCR processing error: $e');
      _showErrorSnackBar('Error al procesar imagen: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addEmptyMedication() {
    setState(() {
      _medications.add({
        'nombre': 'Medicamento',
        'dosisMg': 500.0,
        'frecuenciaHoras': 8,
        'duracionDias': 7,
        'observaciones': '',
        'controller_nombre': TextEditingController(text: 'Medicamento'),
        'controller_dosis': TextEditingController(text: '500.0'),
        'controller_frecuencia': TextEditingController(text: '8'),
        'controller_duracion': TextEditingController(text: '7'),
        'controller_observaciones': TextEditingController(text: ''),
      });
    });
  }

  void _removeMedication(int index) {
    setState(() {
      // Dispose controllers
      _medications[index]['controller_nombre']?.dispose();
      _medications[index]['controller_dosis']?.dispose();
      _medications[index]['controller_frecuencia']?.dispose();
      _medications[index]['controller_duracion']?.dispose();
      _medications[index]['controller_observaciones']?.dispose();
      
      _medications.removeAt(index);
    });
  }

  void _showExtractedDataReview({required int confidence, required Map<String, dynamic> parsedData}) {
    // Determine confidence level
    Color confidenceColor;
    IconData confidenceIcon;
    String confidenceText;
    
    if (confidence >= 70) {
      confidenceColor = Colors.green;
      confidenceIcon = Icons.check_circle;
      confidenceText = 'Alta';
    } else if (confidence >= 40) {
      confidenceColor = Colors.orange;
      confidenceIcon = Icons.warning;
      confidenceText = 'Media';
    } else {
      confidenceColor = Colors.red;
      confidenceIcon = Icons.error;
      confidenceText = 'Baja';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(confidenceIcon, color: confidenceColor),
            const SizedBox(width: 12),
            const Expanded(child: Text('Datos Extraídos')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Confidence indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: confidenceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: confidenceColor, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(confidenceIcon, color: confidenceColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confianza: $confidenceText ($confidence%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: confidenceColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            confidence >= 70 
                                ? 'Los datos se ven bien, pero revísalos antes de guardar.'
                                : 'Por favor revisa y corrige los campos manualmente.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Extracted fields summary
              const Text(
                'Campos detectados:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              
              _buildFieldStatus('Médico', parsedData['doctor']),
              _buildFieldStatus('Diagnóstico', parsedData['diagnosis']),
              _buildFieldStatus('Fecha', parsedData['date'] != null ? 'Detectada' : 'No detectada'),
              _buildFieldStatus('Medicamentos', '${(parsedData['medications'] as List?)?.length ?? 0} encontrados'),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes editar todos los campos en el formulario de abajo.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Revisar y Editar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldStatus(String label, dynamic value) {
    final bool detected = value != null && 
                         value.toString().isNotEmpty && 
                         !value.toString().contains('No detectado');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: detected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${detected ? (value is DateTime ? 'Detectado' : value.toString()) : 'No detectado'}',
              style: TextStyle(
                fontSize: 13,
                color: detected ? Colors.black87 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    // Validate required fields
    if (_medicoController.text.trim().isEmpty) {
      _showErrorSnackBar('El nombre del médico es requerido');
      return;
    }

    if (_diagnosticoController.text.trim().isEmpty) {
      _showErrorSnackBar('El diagnóstico es requerido');
      return;
    }

    if (_medications.isEmpty) {
      _showErrorSnackBar('Debe agregar al menos un medicamento');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Confirmar Carga',
      message: '¿Deseas guardar esta prescripción en tu cuenta?\n\n'
          'Médico: ${_medicoController.text}\n'
          'Medicamentos: ${_medications.length}',
      confirmText: 'Guardar',
    );

    if (confirmed != true) return;

    setState(() => _isUploading = true);

    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        _showErrorSnackBar('Usuario no autenticado');
        return;
      }

      // Create prescription
      final prescriptionId = 'presc_ocr_${DateTime.now().millisecondsSinceEpoch}';
      final prescription = Prescripcion(
        id: prescriptionId,
        fechaCreacion: _selectedDate,
        diagnostico: _diagnosticoController.text.trim(),
        medico: _medicoController.text.trim(),
        activa: true,
      );

      // Create medications
      final medications = <Map<String, dynamic>>[];
      for (int i = 0; i < _medications.length; i++) {
        final med = _medications[i];
        final medicationId = 'med_${prescriptionId}_$i';
        
        // Get values from controllers
        final nombre = (med['controller_nombre'] as TextEditingController).text.trim();
        final dosis = double.tryParse((med['controller_dosis'] as TextEditingController).text) ?? 500.0;
        final frecuencia = int.tryParse((med['controller_frecuencia'] as TextEditingController).text) ?? 8;
        final duracion = int.tryParse((med['controller_duracion'] as TextEditingController).text) ?? 7;
        final observaciones = (med['controller_observaciones'] as TextEditingController).text.trim();

        final fechaInicio = DateTime.now();
        final fechaFin = fechaInicio.add(Duration(days: duracion));

        medications.add({
          'id': medicationId,
          'medicamentoRef': '/medicamentosGlobales/$medicationId',
          'nombre': nombre,
          'dosisMg': dosis,
          'frecuenciaHoras': frecuencia,
          'duracionDias': duracion,
          'fechaInicio': fechaInicio.toIso8601String(),
          'fechaFin': fechaFin.toIso8601String(),
          'observaciones': observaciones.isNotEmpty ? observaciones : null,
          'activo': true,
          'userId': userId,
          'prescripcionId': prescriptionId,
        });
      }

      // Upload to Firestore
      await _prescripcionRepo.createWithMedicamentos(
        userId: userId,
        prescripcion: prescription,
        medicamentos: medications,
      );

      // Refresh user session
      await UserSession().refreshPrescripciones();

      if (!mounted) return;

      _showSuccessDialog(
        title: 'Prescripción Guardada',
        message: 'La prescripción ha sido guardada exitosamente en tu cuenta.\n\n'
            'ID: $prescriptionId\n'
            'Medicamentos: ${medications.length}',
      );

      // Clear form after successful upload
      setState(() {
        _selectedImage = null;
        _extractedText = null;
        _medicoController.clear();
        _diagnosticoController.clear();
        _medications.clear();
      });
    } catch (e) {
      debugPrint('Upload error: $e');
      _showErrorSnackBar('Error al guardar prescripción: ${e.toString()}');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Los permisos son necesarios para el correcto funcionamiento de la app.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: Opening settings requires permission_handler package
              // For now, user needs to manually go to settings
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargar Prescripción por Imagen'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.camera_alt,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Captura tu Prescripción',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toma una foto o selecciona una imagen de tu galería para extraer automáticamente los datos de la prescripción',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Text(
              'Seleccionar Imagen',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Cámara',
                    onPressed: _isProcessing ? null : _handleCameraCapture,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Galería',
                    onPressed: _isProcessing ? null : _handleGalleryPick,
                  ),
                ),
              ],
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Procesando imagen...\nExtrayendo texto con ML Kit',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Image Preview
            if (_selectedImage != null && !_isProcessing) ...[
              const SizedBox(height: 24),
              Text(
                'Imagen Seleccionada',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            // Editable Prescription Form
            if (_extractedText != null && !_isProcessing) ...[
              const SizedBox(height: 24),
              Text(
                'Datos de la Prescripción',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _medicoController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Médico *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _diagnosticoController,
                        decoration: const InputDecoration(
                          labelText: 'Diagnóstico *',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Fecha de Emisión'),
                        subtitle: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Medicamentos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addEmptyMedication,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Medications List
              ..._medications.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                return _buildMedicationCard(index, med);
              }),

              const SizedBox(height: 24),

              // Upload Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _handleUpload,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isUploading ? 'Guardando...' : 'Guardar Prescripción'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Help Section
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Text(
                          'Consejos para mejores resultados',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem('Asegúrate de que la imagen esté bien iluminada'),
                    _buildHelpItem('Mantén el texto enfocado y legible'),
                    _buildHelpItem('Evita sombras o reflejos en la imagen'),
                    _buildHelpItem('Revisa y corrige los datos extraídos antes de guardar'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppTheme.primaryColor),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index, Map<String, dynamic> med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medicamento ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeMedication(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_nombre'] as TextEditingController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Medicamento *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: med['controller_dosis'] as TextEditingController,
                    decoration: const InputDecoration(
                      labelText: 'Dosis (mg) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: med['controller_frecuencia'] as TextEditingController,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia (hrs) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_duracion'] as TextEditingController,
              decoration: const InputDecoration(
                labelText: 'Duración (días) *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_observaciones'] as TextEditingController,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
