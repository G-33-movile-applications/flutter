import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../models/prescripcion.dart';
import '../../providers/motion_provider.dart';
import '../../services/user_session.dart';
import '../../repositories/prescripcion_repository.dart';
import '../widgets/driving_overlay.dart';

class PdfUploadPage extends StatefulWidget {
  const PdfUploadPage({super.key});

  @override
  State<PdfUploadPage> createState() => _PdfUploadPageState();
}

class _PdfUploadPageState extends State<PdfUploadPage> {
  final PrescripcionRepository _prescripcionRepo = PrescripcionRepository();
  
  File? _selectedPdfFile;
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
    // Dispose medication controllers
    for (final med in _medications) {
      med['controller_nombre']?.dispose();
      med['controller_dosis']?.dispose();
      med['controller_frecuencia']?.dispose();
      med['controller_duracion']?.dispose();
      med['controller_observaciones']?.dispose();
    }
    super.dispose();
  }

  /// Select and process PDF file
  Future<void> _selectFile() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      
      setState(() {
        _selectedPdfFile = file;
      });

      // Extract and parse PDF text
      await _extractAndParsePdf(file);
    } catch (e) {
      debugPrint('Error selecting PDF: $e');
      _showErrorSnackBar('Error al seleccionar archivo: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Extract text from PDF and parse prescription data
  Future<void> _extractAndParsePdf(File pdfFile) async {
    setState(() => _isProcessing = true);

    try {
      // Extract text from PDF
      final fileBytes = pdfFile.readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: fileBytes);

      final StringBuffer textBuffer = StringBuffer();
      for (int i = 0; i < document.pages.count; i++) {
        String pageText = PdfTextExtractor(document).extractText(startPageIndex: i);
        textBuffer.writeln(pageText);
        textBuffer.writeln(); // Add spacing between pages
      }

      document.dispose();

      final extractedText = textBuffer.toString().trim();
      
      if (extractedText.isEmpty) {
        _showErrorSnackBar('No se pudo extraer texto del PDF');
        return;
      }

      setState(() => _extractedText = extractedText);

      // Parse prescription data from extracted text
      final parsedData = _parsePrescriptionFromText(extractedText);
      
      // Update UI with parsed data
      _medicoController.text = parsedData['medico'] ?? '';
      _diagnosticoController.text = parsedData['diagnostico'] ?? '';
      
      if (parsedData['fecha'] != null) {
        _selectedDate = parsedData['fecha'];
      }

      // Update medications
      setState(() {
        _medications.clear();
        if (parsedData['medicamentos'] != null && (parsedData['medicamentos'] as List).isNotEmpty) {
          for (final med in parsedData['medicamentos']) {
            _medications.add({
              'controller_nombre': TextEditingController(text: med['nombre'] ?? ''),
              'controller_dosis': TextEditingController(text: med['dosis'] ?? ''),
              'controller_frecuencia': TextEditingController(text: med['frecuencia'] ?? ''),
              'controller_duracion': TextEditingController(text: med['duracion'] ?? ''),
              'controller_observaciones': TextEditingController(text: med['observaciones'] ?? ''),
            });
          }
        }
      });

      // If no medications found, add one empty medication
      if (_medications.isEmpty) {
        _addEmptyMedication();
      }

      _showSuccessSnackBar('Datos extraídos del PDF. Por favor revísalos y edítalos si es necesario.');
      
      // Show review dialog
      await Future.delayed(const Duration(milliseconds: 500));
      _showExtractedDataReview();
    } catch (e) {
      debugPrint('PDF processing error: $e');
      _showErrorSnackBar('Error al procesar PDF: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Parse prescription data from extracted text (simplified parsing)
  Map<String, dynamic> _parsePrescriptionFromText(String text) {
    final Map<String, dynamic> result = {
      'medico': null,
      'diagnostico': null,
      'fecha': DateTime.now(),
      'medicamentos': [],
    };

    try {
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      // Simple pattern matching for common prescription fields
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        
        // Look for doctor name
        if ((line.contains('doctor') || line.contains('médico') || line.contains('dr.') || line.contains('dra.')) && result['medico'] == null) {
          // Try to extract name from same line or next line
          String doctorName = lines[i].replaceAll(RegExp(r'(doctor|médico|dr\.?|dra\.?)\s*:?\s*', caseSensitive: false), '').trim();
          if (doctorName.isEmpty && i + 1 < lines.length) {
            doctorName = lines[i + 1];
          }
          if (doctorName.isNotEmpty) {
            result['medico'] = doctorName;
          }
        }
        
        // Look for diagnosis
        if ((line.contains('diagnóstico') || line.contains('diagnostico') || line.contains('diagnos')) && result['diagnostico'] == null) {
          String diagnosis = lines[i].replaceAll(RegExp(r'(diagnóstico|diagnostico)\s*:?\s*', caseSensitive: false), '').trim();
          if (diagnosis.isEmpty && i + 1 < lines.length) {
            diagnosis = lines[i + 1];
          }
          if (diagnosis.isNotEmpty) {
            result['diagnostico'] = diagnosis;
          }
        }
        
        // Look for medications (simplified - just look for common medication indicators)
        if (line.contains('medicamento') || line.contains('medicación') || line.contains('prescripción')) {
          // Try to extract medications from following lines
          for (int j = i + 1; j < lines.length && j < i + 10; j++) {
            final medLine = lines[j];
            if (medLine.length > 5 && !medLine.toLowerCase().contains('observaciones')) {
              result['medicamentos'].add({
                'nombre': medLine,
                'dosis': '',
                'frecuencia': '',
                'duracion': '',
                'observaciones': '',
              });
            }
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('Error parsing prescription text: $e');
    }

    return result;
  }

  /// Add empty medication to the list
  void _addEmptyMedication() {
    if (_medications.length >= 50) {
      _showErrorSnackBar('Máximo 50 medicamentos permitidos');
      return;
    }
    
    setState(() {
      _medications.add({
        'controller_nombre': TextEditingController(),
        'controller_dosis': TextEditingController(),
        'controller_frecuencia': TextEditingController(),
        'controller_duracion': TextEditingController(),
        'controller_observaciones': TextEditingController(),
      });
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications[index]['controller_nombre']?.dispose();
      _medications[index]['controller_dosis']?.dispose();
      _medications[index]['controller_frecuencia']?.dispose();
      _medications[index]['controller_duracion']?.dispose();
      _medications[index]['controller_observaciones']?.dispose();
      _medications.removeAt(index);
    });
  }

  void _showExtractedDataReview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos Extraídos del PDF'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Se han extraído los siguientes datos. Por favor revísalos y edítalos si es necesario.'),
              const SizedBox(height: 16),
              _buildFieldStatus('Médico', _medicoController.text),
              _buildFieldStatus('Diagnóstico', _diagnosticoController.text),
              _buildFieldStatus('Medicamentos', _medications.isNotEmpty ? '${_medications.length} detectados' : 'Ninguno'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldStatus(String label, dynamic value) {
    final bool detected = value != null && 
                         value.toString().isNotEmpty && 
                         value.toString() != '0' &&
                         value.toString() != 'Ninguno';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.warning,
            color: detected ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${detected ? "Detectado" : "No detectado"}',
              style: TextStyle(
                color: detected ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    // Validate doctor name
    final medicoText = _medicoController.text.trim();
    if (medicoText.isEmpty) {
      _showErrorSnackBar('Por favor ingresa el nombre del médico');
      return;
    }
    
    if (medicoText.length < 5) {
      _showErrorSnackBar('El nombre del médico debe tener al menos 5 caracteres');
      return;
    }

    // Validate diagnosis
    final diagnosticoText = _diagnosticoController.text.trim();
    if (diagnosticoText.isEmpty) {
      _showErrorSnackBar('Por favor ingresa el diagnóstico');
      return;
    }
    
    if (diagnosticoText.length < 3) {
      _showErrorSnackBar('El diagnóstico debe tener al menos 3 caracteres');
      return;
    }

    // Validate medications
    if (_medications.isEmpty) {
      _showErrorSnackBar('Por favor agrega al menos un medicamento');
      return;
    }

    // Validate each medication
    List<String> errors = [];
    for (int i = 0; i < _medications.length; i++) {
      final nombre = _medications[i]['controller_nombre']?.text.trim() ?? '';
      final dosis = _medications[i]['controller_dosis']?.text.trim() ?? '';
      final frecuencia = _medications[i]['controller_frecuencia']?.text.trim() ?? '';
      final duracion = _medications[i]['controller_duracion']?.text.trim() ?? '';
      
      if (nombre.isEmpty) {
        errors.add('Medicamento ${i + 1}: Nombre es requerido');
      } else if (nombre.length < 3) {
        errors.add('Medicamento ${i + 1}: Nombre muy corto');
      }
      
      if (dosis.isEmpty) {
        errors.add('Medicamento ${i + 1}: Dosis es requerida');
      }
      
      if (frecuencia.isEmpty) {
        errors.add('Medicamento ${i + 1}: Frecuencia es requerida');
      }
      
      if (duracion.isEmpty) {
        errors.add('Medicamento ${i + 1}: Duración es requerida');
      }
    }
    
    if (errors.isNotEmpty) {
      _showValidationErrorDialog(errors.join('\n'));
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Guardar Prescripción',
      message: '¿Deseas guardar esta prescripción con ${_medications.length} medicamento(s)?',
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

      // Generate unique prescription ID
      final prescripcionId = 'pres_${DateTime.now().millisecondsSinceEpoch}';

      // Create prescription object
      final prescripcion = Prescripcion(
        id: prescripcionId,
        medico: medicoText,
        diagnostico: diagnosticoText,
        fechaCreacion: _selectedDate,
        activa: true,
      );

      // Save prescription with medications using subcollection approach
      final medicamentos = _medications.map((med) {
        final nombre = med['controller_nombre']?.text.trim() ?? '';
        final dosis = med['controller_dosis']?.text.trim() ?? '';
        final frecuencia = med['controller_frecuencia']?.text.trim() ?? '';
        final duracion = med['controller_duracion']?.text.trim() ?? '';
        final observaciones = med['controller_observaciones']?.text.trim() ?? '';
        
        // Parse duration to days (simple parsing)
        int duracionDias = 7; // default
        final duracionMatch = RegExp(r'(\d+)').firstMatch(duracion);
        if (duracionMatch != null) {
          duracionDias = int.tryParse(duracionMatch.group(1)!) ?? 7;
        }
        
        // Parse frequency to hours (simple parsing)
        int frecuenciaHoras = 8; // default
        final frecuenciaMatch = RegExp(r'(\d+)').firstMatch(frecuencia);
        if (frecuenciaMatch != null) {
          frecuenciaHoras = int.tryParse(frecuenciaMatch.group(1)!) ?? 8;
        }

        return {
          'id': 'med_${DateTime.now().millisecondsSinceEpoch}_${_medications.indexOf(med)}',
          'medicamentoRef': '/medicamentosGlobales/unknown',
          'nombre': nombre,
          'dosisMg': 0.0, // We don't parse the actual dosage amount
          'frecuenciaHoras': frecuenciaHoras,
          'duracionDias': duracionDias,
          'fechaInicio': _selectedDate,
          'fechaFin': _selectedDate.add(Duration(days: duracionDias)),
          'observaciones': '$dosis - $frecuencia - $duracion${observaciones.isNotEmpty ? " - $observaciones" : ""}',
          'activo': true,
          'userId': userId,
          'prescripcionId': prescripcionId,
        };
      }).toList();

      await _prescripcionRepo.createWithMedicamentos(
        userId: userId,
        prescripcion: prescripcion,
        medicamentos: medicamentos,
      );

      if (!mounted) return;

      _showSuccessDialog(
        title: 'Éxito',
        message: 'Prescripción guardada exitosamente con ${_medications.length} medicamento(s)',
      );

      // Clear form
      setState(() {
        _selectedPdfFile = null;
        _extractedText = null;
        _medicoController.clear();
        _diagnosticoController.clear();
        _selectedDate = DateTime.now();
        for (final med in _medications) {
          med['controller_nombre']?.dispose();
          med['controller_dosis']?.dispose();
          med['controller_frecuencia']?.dispose();
          med['controller_duracion']?.dispose();
          med['controller_observaciones']?.dispose();
        }
        _medications.clear();
      });
    } catch (e) {
      debugPrint('Error saving prescription: $e');
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
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showValidationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Errores de Validación'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
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
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDriving = context.watch<MotionProvider>().isDriving;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              "Cargar Prescripción PDF",
              style: theme.appBarTheme.titleTextStyle,
            ),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Cargar desde PDF',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona un archivo PDF de tu prescripción médica',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // File selection button
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    onTap: _isProcessing ? null : _selectFile,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _selectedPdfFile == null ? Icons.picture_as_pdf : Icons.check_circle,
                              size: 60,
                              color: _selectedPdfFile == null ? Colors.orange : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedPdfFile == null 
                                ? 'Seleccionar Archivo PDF' 
                                : 'PDF Seleccionado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (_selectedPdfFile != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _selectedPdfFile!.path.split('\\').last,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                if (_isProcessing) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Procesando PDF...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],

                // Extracted data form
                if (_extractedText != null && !_isProcessing) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Datos de la Prescripción',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Doctor field
                  TextField(
                    controller: _medicoController,
                    decoration: const InputDecoration(
                      labelText: 'Médico *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Diagnosis field
                  TextField(
                    controller: _diagnosticoController,
                    decoration: const InputDecoration(
                      labelText: 'Diagnóstico *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Date picker
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Fecha de Prescripción'),
                    subtitle: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 24),
                  
                  // Medications section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Medicamentos',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _addEmptyMedication,
                        icon: const Icon(Icons.add),
                        tooltip: 'Agregar medicamento',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Medications list
                  ..._medications.asMap().entries.map((entry) {
                    final index = entry.key;
                    final med = entry.value;
                    return _buildMedicationCard(index, med);
                  }),

                  const SizedBox(height: 24),

                  // Upload button
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _handleUpload,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isUploading ? 'Guardando...' : 'Guardar Prescripción'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Help Section
                Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              '¿Cómo funciona?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHelpItem('Selecciona un archivo PDF de tu prescripción'),
                        _buildHelpItem('El texto será extraído automáticamente'),
                        _buildHelpItem('Revisa y edita los datos detectados'),
                        _buildHelpItem('Agrega o modifica medicamentos según sea necesario'),
                        _buildHelpItem('Guarda la prescripción en tu cuenta'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Driving overlay
        if (isDriving)
          DrivingOverlay(
            customMessage: "Por seguridad, no puedes cargar prescripciones mientras conduces.",
          ),
      ],
    );
  }

  Widget _buildMedicationCard(int index, Map<String, dynamic> med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                  onPressed: () => _removeMedication(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar medicamento',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_nombre'],
              decoration: const InputDecoration(
                labelText: 'Nombre del Medicamento *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_dosis'],
              decoration: const InputDecoration(
                labelText: 'Dosis *',
                hintText: 'Ej: 500mg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_frecuencia'],
              decoration: const InputDecoration(
                labelText: 'Frecuencia *',
                hintText: 'Ej: Cada 8 horas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_duracion'],
              decoration: const InputDecoration(
                labelText: 'Duración *',
                hintText: 'Ej: 7 días',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: med['controller_observaciones'],
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Indicaciones adicionales',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
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
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
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