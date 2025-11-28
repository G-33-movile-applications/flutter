import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/prescripcion.dart';
import '../../services/ocr_service.dart';
import '../../services/user_session.dart';
import '../../services/connectivity_service.dart';
import '../../services/prescription_draft_cache.dart';
import '../../services/medicine_validation_service.dart';
import '../../repositories/prescripcion_repository.dart';
import '../widgets/unknown_medicine_dialog.dart';

class OcrUploadPage extends StatefulWidget {
  const OcrUploadPage({super.key});

  @override
  State<OcrUploadPage> createState() => _OcrUploadPageState();
}

class _OcrUploadPageState extends State<OcrUploadPage> {
  final OcrService _ocrService = OcrService();
  final PrescripcionRepository _prescripcionRepo = PrescripcionRepository();
  final PrescriptionDraftCache _draftCache = PrescriptionDraftCache();
  final MedicineValidationService _medicineValidation = MedicineValidationService();
  
  // Generate unique draft ID for each OCR session
  late final String _draftId;
  bool _draftIdInitialized = false;

  // Changed to support multiple images (max 3)
  final List<File> _selectedImages = [];
  final int _maxImages = 3;
  
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
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize draft ID only once
    if (!_draftIdInitialized) {
      _draftIdInitialized = true;
      
      // Generate unique draft ID or load from arguments
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['draftId'] != null) {
        _draftId = args['draftId'] as String;
        _loadDraftIfExists();
      } else {
        // Generate new draft ID with timestamp for uniqueness
        _draftId = 'ocr_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
  }

  @override
  void dispose() {
    _saveDraftIfNeeded(); // Save before disposing
    _medicoController.dispose();
    _diagnosticoController.dispose();
    super.dispose();
  }
  
  /// Load draft from cache if it exists
  Future<void> _loadDraftIfExists() async {
    final draft = _draftCache.getDraft(_draftId);
    if (draft == null) return;
    
    debugPrint('📄 [OCR Upload] Restoring draft from ${draft.lastModified}');
    
    // Restore text fields
    _medicoController.text = draft.data['medico'] as String? ?? '';
    _diagnosticoController.text = draft.data['diagnostico'] as String? ?? '';
    
    // Restore extracted text
    _extractedText = draft.data['extractedText'] as String?;
    
    // Restore date
    if (draft.data['fecha'] != null) {
      _selectedDate = DateTime.parse(draft.data['fecha'] as String);
    }
    
    // Restore images
    for (String imagePath in draft.imagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        _selectedImages.add(file);
      }
    }
    
    // Restore medications
    if (draft.data['medications'] != null) {
      final meds = draft.data['medications'] as List<dynamic>;
      for (var med in meds) {
        _medications.add({
          'controller_nombre': TextEditingController(text: med['nombre'] ?? ''),
          'controller_dosis': TextEditingController(text: med['dosis']?.toString() ?? ''),
          'controller_frecuencia': TextEditingController(text: med['frecuencia']?.toString() ?? ''),
          'controller_duracion': TextEditingController(text: med['duracion']?.toString() ?? ''),
          'controller_observaciones': TextEditingController(text: med['observaciones'] ?? ''),
          'unidad': med['unidad'] ?? 'mg',
        });
      }
    }
    
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📄 Borrador restaurado'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// Save draft if there's meaningful data
  void _saveDraftIfNeeded() {
    // Only save if user has entered some data
    final hasData = _medicoController.text.trim().isNotEmpty ||
                    _diagnosticoController.text.trim().isNotEmpty ||
                    _selectedImages.isNotEmpty ||
                    _medications.isNotEmpty;
    
    if (!hasData) {
      debugPrint('📄 [OCR Upload] No data to save as draft test');
      return;
    }
    
    // Prepare medications data
    final medsData = _medications.map((med) {
      return {
        'nombre': (med['controller_nombre'] as TextEditingController).text.trim(),
        'dosis': double.tryParse((med['controller_dosis'] as TextEditingController).text.trim()),
        'frecuencia': int.tryParse((med['controller_frecuencia'] as TextEditingController).text.trim()),
        'duracion': int.tryParse((med['controller_duracion'] as TextEditingController).text.trim()),
        'observaciones': (med['controller_observaciones'] as TextEditingController).text.trim(),
        'unidad': med['unidad'] ?? 'mg',
      };
    }).toList();
    
    _draftCache.saveDraft(
      draftId: _draftId,
      data: {
        'type': 'ocr', // Identify draft type
        'medico': _medicoController.text.trim(),
        'diagnostico': _diagnosticoController.text.trim(),
        'fecha': _selectedDate.toIso8601String(),
        'medications': medsData,
        'extractedText': _extractedText, // Save extracted OCR text for reference
        'imageCount': _selectedImages.length, // For display purposes
      },
      imagePaths: _selectedImages.map((f) => f.path).toList(),
    );
    
    debugPrint('💾 [OCR Upload] Draft saved');
  }

  Future<void> _handleCameraCapture() async {
    // Check if we've reached the maximum number of images
    if (_selectedImages.length >= _maxImages) {
      _showErrorSnackBar('Máximo $_maxImages imágenes permitidas. Elimina una imagen para agregar otra.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _ocrService.capturePhoto();
      
      if (image == null) {
        _showInfoSnackBar('Captura cancelada');
        return;
      }

      await _addAndProcessImage(image);
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
    // Check if we've reached the maximum number of images
    if (_selectedImages.length >= _maxImages) {
      _showErrorSnackBar('Máximo $_maxImages imágenes permitidas. Elimina una imagen para agregar otra.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _ocrService.pickImageFromGallery();
      
      if (image == null) {
        _showInfoSnackBar('Selección cancelada');
        return;
      }

      await _addAndProcessImage(image);
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

  Future<void> _addAndProcessImage(File image) async {
    // Add image to list
    setState(() {
      _selectedImages.add(image);
      _isProcessing = true;
    });

    try {
      // Extract text from ALL images and combine
      await _processAllImages();
    } catch (e) {
      debugPrint('Error adding and processing image: $e');
      _showErrorSnackBar('Error al procesar imagen: ${e.toString()}');
      // Remove the image that caused the error
      setState(() {
        if (_selectedImages.isNotEmpty) {
          _selectedImages.removeLast();
        }
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    
    // Auto-save draft after removing image
    _saveDraftIfNeeded();
    
    // Clear extracted data if all images are removed
    if (_selectedImages.isEmpty) {
      setState(() {
        _extractedText = null;
        _medicoController.clear();
        _diagnosticoController.clear();
        _medications.clear();
      });
    } else {
      // Reprocess remaining images
      _processAllImages();
    }
  }

  Future<void> _processAllImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Extract text from all images and combine intelligently
      final StringBuffer combinedText = StringBuffer();
      final List<Map<String, dynamic>> allParsedData = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        debugPrint('📄 Processing image ${i + 1}/${_selectedImages.length}...');
        
        final text = await _ocrService.extractTextFromFile(image);
        
        if (text.isNotEmpty) {
          // Add text to combined buffer
          if (combinedText.isNotEmpty) {
            combinedText.writeln('\n--- Imagen ${i + 1} ---\n');
          }
          combinedText.writeln(text);
          
          // Parse each image individually to extract structured data
          final parsedData = await _ocrService.parsePrescriptionText(text);
          allParsedData.add(parsedData);
          debugPrint('Image ${i + 1} parsed: ${parsedData.keys}');
        }
      }
      
      final extractedText = combinedText.toString().trim();
      
      if (extractedText.isEmpty) {
        _showErrorSnackBar('No se pudo extraer texto de las imágenes');
        return;
      }

      setState(() => _extractedText = extractedText);

      // Merge data from all images intelligently
      String? bestDoctor;
      String? bestDiagnosis;
      DateTime? bestDate;
      final List<Map<String, dynamic>> allMedications = [];
      int totalConfidence = 0;
      
      // Extract best values from all images
      for (final data in allParsedData) {
        // Get doctor name (prefer longest/most complete)
        if (data['doctor'] != null && data['doctor'].toString().isNotEmpty) {
          if (bestDoctor == null || data['doctor'].toString().length > bestDoctor.length) {
            bestDoctor = data['doctor'].toString();
          }
        }
        
        // Get diagnosis (prefer longest/most complete)
        if (data['diagnosis'] != null && data['diagnosis'].toString().isNotEmpty) {
          if (bestDiagnosis == null || data['diagnosis'].toString().length > bestDiagnosis.length) {
            bestDiagnosis = data['diagnosis'].toString();
          }
        }
        
        // Get date (prefer the first valid date found)
        if (data['date'] != null && data['date'] is DateTime) {
          bestDate ??= data['date'] as DateTime;
        }
        
        // Collect all medications from all images (no duplicates)
        if (data['medications'] != null && data['medications'] is List) {
          final medsList = data['medications'] as List;
          for (var med in medsList) {
            // Check if medication already exists (by name)
            final medName = med['name']?.toString().toLowerCase() ?? '';
            final exists = allMedications.any((existing) => 
              existing['name']?.toString().toLowerCase() == medName
            );
            
            if (!exists && medName.isNotEmpty) {
              allMedications.add(med);
            }
          }
        }
        
        // Sum up confidence scores
        totalConfidence += (data['_confidence'] as int? ?? 0);
      }
      
      // Calculate average confidence
      final confidence = allParsedData.isEmpty ? 0 : (totalConfidence / allParsedData.length).round();
      
      // Update UI with merged data
      _medicoController.text = bestDoctor ?? '';
      _diagnosticoController.text = bestDiagnosis ?? '';
      
      if (bestDate != null) {
        _selectedDate = bestDate;
      }

      // Update medications list with all found medications
      setState(() {
        // Dispose old controllers
        for (var med in _medications) {
          med['controller_nombre']?.dispose();
          med['controller_dosis']?.dispose();
          med['controller_frecuencia']?.dispose();
          med['controller_duracion']?.dispose();
          med['controller_observaciones']?.dispose();
        }
        
        _medications.clear();
        
        for (var med in allMedications) {
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

      // If no medications found, add one empty medication
      if (_medications.isEmpty) {
        _addEmptyMedication();
      }

      // Show success with confidence score
      final medicationInfo = allMedications.isEmpty 
          ? ''
          : ' - ${allMedications.length} medicamento(s) encontrado(s)';
      
      if (confidence >= 70) {
        _showSuccessSnackBar('Texto extraído exitosamente (Confianza: $confidence%)$medicationInfo');
      } else if (confidence >= 40) {
        _showInfoSnackBar('Texto extraído con confianza media ($confidence%)$medicationInfo. Por favor revisa los datos.');
      } else {
        _showErrorSnackBar('Confianza baja ($confidence%)$medicationInfo. Por favor revisa y corrige los datos manualmente.');
      }
      
      // Show improved confirmation dialog to review extracted data
      await Future.delayed(const Duration(milliseconds: 500));
      _showExtractedDataReview(
        confidence: confidence, 
        parsedData: {
          'doctor': bestDoctor,
          'diagnosis': bestDiagnosis,
          'date': bestDate,
          'medications': allMedications,
          '_confidence': confidence,
        },
      );
    } catch (e) {
      debugPrint('OCR processing error: $e');
      _showErrorSnackBar('Error al procesar imagen: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Add medication with smart limits and warnings
  Future<void> _addEmptyMedication() async {
    // Hard limit: 50 medicines maximum
    if (_medications.length >= 50) {
      _showValidationErrorDialog(
        'Has alcanzado el límite máximo de 50 medicamentos por prescripción. '
        'Si necesitas agregar más, crea una nueva prescripción.',
      );
      return;
    }
    
    // Warning at 20 medicines: ask for confirmation
    if (_medications.length >= 20) {
      final confirmed = await _showConfirmDialog(
        title: 'Muchos medicamentos',
        message: 'Ya tienes ${_medications.length} medicamentos en esta prescripción. '
            '¿Estás seguro de que deseas agregar otro?\n\n'
            'Consejo: Considera dividir prescripciones muy largas para facilitar su gestión.',
        confirmText: 'Sí, agregar',
      );
      
      if (confirmed != true) return;
    }
    
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
    
    // Auto-save draft after adding medication
    _saveDraftIfNeeded();
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
    
    // Auto-save draft after removing medication
    _saveDraftIfNeeded();
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
      builder: (dialogContext) => AlertDialog(
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
                  color: confidenceColor.withValues(alpha: 0.1),
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes editar todos los campos en el formulario de abajo.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
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
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
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
                color: detected ? Theme.of(context).textTheme.bodyMedium?.color : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    // ========== COMPREHENSIVE VALIDATION ==========
    
    // 1. Validate doctor name
    final medicoText = _medicoController.text.trim();
    if (medicoText.isEmpty) {
      _showValidationErrorDialog('El nombre del médico es obligatorio.\n\nPor favor ingresa el nombre completo del médico.');
      return;
    }
    
    if (medicoText.length < 5) {
      _showValidationErrorDialog('El nombre del médico es demasiado corto.\n\nIngresa el nombre completo (ejemplo: "Dr. Juan Pérez").');
      return;
    }
    
    if (!_isValidDoctorName(medicoText)) {
      _showValidationErrorDialog(
        'El nombre del médico no parece válido.\n\n'
        'Debe contener al menos un nombre y apellido.\n\n'
        'Valor actual: "$medicoText"'
      );
      return;
    }

    // 2. Validate diagnosis
    final diagnosticoText = _diagnosticoController.text.trim();
    if (diagnosticoText.isEmpty) {
      _showValidationErrorDialog('El diagnóstico es obligatorio.\n\nPor favor ingresa el diagnóstico del paciente.');
      return;
    }
    
    if (diagnosticoText.length < 3) {
      _showValidationErrorDialog('El diagnóstico es demasiado corto.\n\nIngresa una descripción más detallada.');
      return;
    }

    // 3. Validate medications exist
    if (_medications.isEmpty) {
      _showValidationErrorDialog(
        'Debes agregar al menos un medicamento.\n\n'
        'Usa el botón "+ Agregar Medicamento" para añadir medicamentos a la prescripción.'
      );
      return;
    }

    // 4. Validate each medication in detail
    List<String> errors = [];
    for (int i = 0; i < _medications.length; i++) {
      final med = _medications[i];
      final medNum = i + 1;
      
      // Get values from controllers
      final nombre = (med['controller_nombre'] as TextEditingController).text.trim();
      final dosisText = (med['controller_dosis'] as TextEditingController).text.trim();
      final frecuenciaText = (med['controller_frecuencia'] as TextEditingController).text.trim();
      final duracionText = (med['controller_duracion'] as TextEditingController).text.trim();
      
      // Validate medication name (MOST IMPORTANT - CANNOT BE EMPTY OR GIBBERISH)
      if (nombre.isEmpty) {
        errors.add('❌ Medicamento #$medNum: El nombre es obligatorio');
      } else if (nombre.length < 3) {
        errors.add('❌ Medicamento #$medNum: El nombre "$nombre" es demasiado corto');
      } else if (!_isValidMedicationName(nombre)) {
        errors.add('❌ Medicamento #$medNum: El nombre "$nombre" no parece válido');
      }
      
      // Validate dosage is a valid number
      final dosis = double.tryParse(dosisText);
      if (dosisText.isEmpty || dosis == null) {
        errors.add('❌ Medicamento #$medNum: La dosis debe ser un número');
      } else if (dosis <= 0) {
        errors.add('❌ Medicamento #$medNum: La dosis debe ser mayor a 0');
      } else if (dosis > 10000) {
        errors.add('⚠️ Medicamento #$medNum: La dosis parece muy alta (${dosis}mg). Verifica si es correcto.');
      }
      
      // Validate frequency is a valid number
      final frecuencia = int.tryParse(frecuenciaText);
      if (frecuenciaText.isEmpty || frecuencia == null) {
        errors.add('❌ Medicamento #$medNum: La frecuencia debe ser un número');
      } else if (frecuencia <= 0) {
        errors.add('❌ Medicamento #$medNum: La frecuencia debe ser mayor a 0');
      } else if (frecuencia < 1) {
        errors.add('❌ Medicamento #$medNum: La frecuencia debe ser al menos 1 hora');
      } else if (frecuencia > 168) {
        errors.add('⚠️ Medicamento #$medNum: La frecuencia parece muy alta (cada $frecuencia horas)');
      }
      
      // Validate duration is a valid number
      final duracion = int.tryParse(duracionText);
      if (duracionText.isEmpty || duracion == null) {
        errors.add('❌ Medicamento #$medNum: La duración debe ser un número');
      } else if (duracion <= 0) {
        errors.add('❌ Medicamento #$medNum: La duración debe ser mayor a 0');
      } else if (duracion > 365) {
        errors.add('⚠️ Medicamento #$medNum: La duración parece muy larga ($duracion días)');
      }
    }
    
    // Show all validation errors if any
    if (errors.isNotEmpty) {
      _showValidationErrorDialog(
        'Se encontraron los siguientes errores:\n\n${errors.join('\n')}\n\n'
        'Por favor corrige estos errores antes de guardar.'
      );
      return;
    }

    // ========== MEDICINE VALIDATION ==========
    // Validate each medicine exists in catalog
    debugPrint('🚀 [OCR] Starting medicine validation for ${_medications.length} medicines');
    setState(() => _isUploading = true);
    
    final List<int> indicesToRemove = [];

    for (int i = 0; i < _medications.length; i++) {
      final med = _medications[i];
      final nombre = (med['controller_nombre'] as TextEditingController).text.trim();
      
      debugPrint('🔍 [OCR] Validating medicine ${i + 1}/${_medications.length}: "$nombre"');
      
      try {
        debugPrint('🔎 [OCR] Calling validateMedicine for: "$nombre"');
        final validationResult = await _medicineValidation.validateMedicine(nombre);
        debugPrint('📊 [OCR] Validation result - found: ${validationResult.found}, confidence: ${validationResult.confidence}');
        
        if (!validationResult.found || validationResult.confidence < 0.75) {
          // Medicine not found or low confidence - show dialog
          debugPrint('⚠️ [OCR] Medicine needs review - showing dialog');
          if (!mounted) return;
          
          debugPrint('🔔 [OCR] Showing UnknownMedicineDialog for: "$nombre"');
          final action = await UnknownMedicineDialog.show(
            context,
            medicineName: nombre,
            suggestions: validationResult.suggestions,
          );
          debugPrint('✅ [OCR] Dialog returned action: ${action?.type}');
          
          if (action == null) {
            // User cancelled - abort upload
            debugPrint('❌ [OCR] User cancelled dialog - aborting upload');
            setState(() => _isUploading = false);
            return;
          }
          
          if (action.type == UnknownMedicineActionType.skip) {
            // Skip this medicine
            indicesToRemove.add(i);
            continue;
          } else if (action.type == UnknownMedicineActionType.useAlternative) {
            // Use alternative medicine
            med['validatedMedicine'] = action.selectedMedicine;
            med['medicineId'] = action.selectedMedicine!.id;
            (med['controller_nombre'] as TextEditingController).text = action.selectedMedicine!.nombre;
          } else if (action.type == UnknownMedicineActionType.saveForReview) {
            // Save to unknownMedicines for admin review
            final userId = UserSession().currentUser.value?.uid;
            if (userId != null) {
              await _medicineValidation.saveUnknownMedicine(
                proposedName: nombre,
                uploadedBy: userId,
                additionalData: {
                  'source': 'ocr',
                  'prescriptionContext': diagnosticoText,
                },
              );
            }
            // Still include in prescription with unknown flag
            med['isUnknown'] = true;
            med['requiresValidation'] = true;
          } else if (action.type == UnknownMedicineActionType.addToGlobal) {
            // Add medicine directly to global catalog
            final newMedicineId = await _medicineValidation.addMedicineToGlobalCatalog(
              nombre: action.newMedicineData!['nombre']!,
              principioActivo: action.newMedicineData!['principioActivo'],
              presentacion: action.newMedicineData!['presentacion'],
              laboratorio: action.newMedicineData!['laboratorio'],
            );
            med['medicineId'] = newMedicineId;
            (med['controller_nombre'] as TextEditingController).text = action.newMedicineData!['nombre']!;
          }
        } else {
          // Medicine found - attach metadata
          med['validatedMedicine'] = validationResult.medicine;
          med['medicineId'] = validationResult.medicine!.id;
          med['confidence'] = validationResult.confidence;
        }
      } catch (e) {
        debugPrint('❌ Error validating medicine $nombre: $e');
        // Continue with original name if validation fails
        med['isUnknown'] = true;
        med['requiresValidation'] = true;
      }
    }

    // Remove skipped medicines
    for (final index in indicesToRemove.reversed) {
      _medications.removeAt(index);
    }

    if (_medications.isEmpty) {
      setState(() => _isUploading = false);
      _showValidationErrorDialog(
        'No hay medicamentos válidos para guardar.\n\n'
        'Todos los medicamentos fueron omitidos.'
      );
      return;
    }

    setState(() => _isUploading = false);

    // ========== CONFIRMATION DIALOG ==========
    
    final confirmed = await _showConfirmDialog(
      title: 'Confirmar Carga',
      message: '¿Deseas guardar esta prescripción en tu cuenta?\n\n'
          'Médico: $medicoText\n'
          'Diagnóstico: $diagnosticoText\n'
          'Medicamentos: ${_medications.length}',
      confirmText: 'Guardar',
    );

    if (confirmed != true) return;

    // ========== SAVE TO FIRESTORE ==========
    
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
        diagnostico: diagnosticoText,
        medico: medicoText,
        activa: true,
      );

      // Create medications (already validated, safe to parse)
      final medications = <Map<String, dynamic>>[];
      for (int i = 0; i < _medications.length; i++) {
        final med = _medications[i];
        final medicationId = 'med_${prescriptionId}_$i';
        
        // Get values from controllers (now guaranteed to be valid)
        final nombre = (med['controller_nombre'] as TextEditingController).text.trim();
        final dosis = double.parse((med['controller_dosis'] as TextEditingController).text.trim());
        final frecuencia = int.parse((med['controller_frecuencia'] as TextEditingController).text.trim());
        final duracion = int.parse((med['controller_duracion'] as TextEditingController).text.trim());
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
          'fechaInicio': Timestamp.fromDate(fechaInicio),
          'fechaFin': Timestamp.fromDate(fechaFin),
          'observaciones': observaciones.isNotEmpty ? observaciones : null,
          'activo': true,
          'userId': userId,
          'prescripcionId': prescriptionId,
        });
      }

      // Upload to Firestore
      // Check connectivity before upload
      final isOnline = await ConnectivityService().checkConnectivity();
      
      if (isOnline) {
        // Online: Upload to Firestore immediately
        await _prescripcionRepo.createWithMedicamentos(
          userId: userId,
          prescripcion: prescription,
          medicamentos: medications,
        );

        // Refresh user session
        await UserSession().refreshPrescripciones();

        if (!mounted) return;
        
        // Clear draft on successful upload
        await _draftCache.removeDraft(_draftId);
        debugPrint('🗑️ [OCR Upload] Draft cleared after successful upload');

        _showSuccessDialog(
          title: 'Prescripción Guardada',
          message: 'La prescripción ha sido guardada exitosamente en tu cuenta.\n\n'
              'ID: $prescriptionId\n'
              'Medicamentos: ${medications.length}',
        );

        // Clear form after successful upload
        setState(() {
          _selectedImages.clear();
          _extractedText = null;
          _medicoController.clear();
          _diagnosticoController.clear();
          _medications.clear();
        });
      } else {
        // Offline: Queue for later upload (will be implemented in task 5)
        if (!mounted) return;
        
        // Keep draft when saving offline
        _saveDraftIfNeeded();
        
        _showInfoSnackBar(
          '📴 Prescripción guardada, será sincronizada una vez tengas conexión.',
        );
        
        _showSuccessDialog(
          title: 'Guardado localmente',
          message: 'La prescripción se guardó en tu dispositivo y se sincronizará automáticamente cuando tengas conexión.\n\n'
              'ID: $prescriptionId\n'
              'Medicamentos: ${medications.length}',
        );
        
        // Clear form after saving locally
        setState(() {
          _selectedImages.clear();
          _extractedText = null;
          _medicoController.clear();
          _diagnosticoController.clear();
          _medications.clear();
        });
      }
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
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showValidationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Expanded(child: Text('Error de Validación')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Por favor corrige los errores para poder guardar la prescripción.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
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
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // Validation helper methods
  
  /// Validates that doctor name is reasonable (at least 2 words, contains letters, not just numbers/symbols)
  bool _isValidDoctorName(String name) {
    if (name.isEmpty) return false;
    
    // Remove common titles
    final cleanName = name.replaceAll(RegExp(r'\b(Dr|Dra|Doctor|Doctora)\.?\s*', caseSensitive: false), '').trim();
    
    // Must have at least 2 characters after removing titles
    if (cleanName.length < 2) return false;
    
    // Split into words
    final words = cleanName.split(RegExp(r'\s+'));
    
    // Must have at least 1 word (preferably 2 for full name)
    if (words.isEmpty) return false;
    
    // At least one word must be longer than 2 characters
    final hasValidWord = words.any((word) => word.length >= 2);
    if (!hasValidWord) return false;
    
    // Must contain letters (not just numbers/symbols)
    if (!RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').hasMatch(cleanName)) return false;
    
    // Should not be mostly numbers (gibberish detection)
    final letterCount = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').allMatches(cleanName).length;
    final numberCount = RegExp(r'\d').allMatches(cleanName).length;
    if (numberCount > letterCount) return false;
    
    return true;
  }
  
  /// Validates that medication name is reasonable (not empty, not gibberish, contains letters)
  bool _isValidMedicationName(String name) {
    if (name.isEmpty) return false;
    
    // Must be at least 3 characters
    if (name.length < 3) return false;
    
    // Must contain letters (not just numbers/symbols)
    if (!RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').hasMatch(name)) return false;
    
    // Should not be common placeholder text
    final lowerName = name.toLowerCase();
    if (lowerName == 'medicamento' || 
        lowerName == 'medicina' ||
        lowerName == 'test' ||
        lowerName == 'ejemplo' ||
        lowerName == 'asdf' ||
        lowerName == 'xxx' ||
        lowerName == 'n/a' ||
        lowerName == 'none' ||
        lowerName == 'null') {
      return false;
    }
    
    // Should not be mostly numbers (gibberish detection)
    final letterCount = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').allMatches(name).length;
    final numberCount = RegExp(r'\d').allMatches(name).length;
    if (letterCount < 2) return false; // Must have at least 2 letters
    if (numberCount > letterCount * 2) return false; // Too many numbers vs letters
    
    // Should not be all the same character repeated
    if (RegExp(r'^(.)\1+$').hasMatch(name)) return false;
    
    return true;
  }

  void _showPermissionDeniedDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los permisos son necesarios para el correcto funcionamiento de la app.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
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
              Navigator.pop(dialogContext);
              // Note: Opening settings requires permission_handler package
              // For now, user needs to manually go to settings
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
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
        backgroundColor: Theme.of(context).colorScheme.primary,
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
        backgroundColor: theme.colorScheme.primary,
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
                    Icon(
                      Icons.camera_alt,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Captura tu Prescripción',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toma una foto o selecciona una imagen de tu galería para extraer automáticamente los datos de la prescripción',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Multi-Image Info Card
            if (_selectedImages.isNotEmpty) ...[
              Card(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.collections, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedImages.length < _maxImages
                              ? 'Puedes agregar ${_maxImages - _selectedImages.length} imagen(es) más'
                              : 'Máximo de imágenes alcanzado',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${_selectedImages.length}/$_maxImages',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons - Show only if we haven't reached max images
            if (_selectedImages.length < _maxImages) ...[
              Text(
                _selectedImages.isEmpty ? 'Seleccionar Imagen' : 'Agregar Más Imágenes',
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
            ],
            
            // Show message when max images reached
            if (_selectedImages.length >= _maxImages) ...[
              Card(
                color: Colors.orange.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Máximo $_maxImages imágenes alcanzado. Elimina una imagen para agregar otra.',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

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

            // Image Preview (Multiple Images)
            if (_selectedImages.isNotEmpty && !_isProcessing) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Imágenes Seleccionadas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_selectedImages.length}/$_maxImages',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < _selectedImages.length - 1 ? 12.0 : 0,
                      ),
                      child: Stack(
                        children: [
                          Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.file(
                              _selectedImages[index],
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _removeImage(index),
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                          hintText: 'Por favor ingresa el nombre del médico',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _diagnosticoController,
                        decoration: const InputDecoration(
                          labelText: 'Diagnóstico *',
                          hintText: 'Por favor añade un diagnóstico',
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
                      backgroundColor: theme.colorScheme.primary,
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
                    backgroundColor: theme.colorScheme.primary,
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Consejos para mejores resultados',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
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
      // Floating Action Button to add more images (shows when scrolled down)
      floatingActionButton: _selectedImages.isNotEmpty && 
                            _selectedImages.length < _maxImages && 
                            !_isProcessing
          ? FloatingActionButton.extended(
              onPressed: () async {
                // Show options to add more images
                final choice = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Agregar Imagen'),
                    content: const Text('¿Cómo deseas agregar la imagen?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, 'camera'),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Cámara'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, 'gallery'),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                );

                if (choice == 'camera') {
                  await _handleCameraCapture();
                } else if (choice == 'gallery') {
                  await _handleGalleryPick();
                }
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Agregar (${_selectedImages.length}/$_maxImages)'),
              backgroundColor: theme.colorScheme.primary,
            )
          : null,
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
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
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
                hintText: 'Notas adicionales (opcional)',
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
