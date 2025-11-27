import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../models/prescripcion.dart';
import '../../models/prescripcion_with_medications.dart';
import '../../models/medicamento_prescripcion.dart';
import '../../services/nfc_service.dart';
import '../../services/user_session.dart';
import '../../services/connectivity_service.dart';
import '../../services/prescription_draft_cache.dart';
import '../../adapters/prescription_adapter.dart';
import '../../repositories/prescripcion_repository.dart';
import 'widgets/prescription_preview_widget.dart';

class NfcUploadPage extends StatefulWidget {
  const NfcUploadPage({super.key});

  @override
  State<NfcUploadPage> createState() => _NfcUploadPageState();
}

class _NfcUploadPageState extends State<NfcUploadPage> {
  final NfcService _nfcService = NfcService();
  final PrescripcionRepository _prescripcionRepo = PrescripcionRepository();
  final PrescriptionDraftCache _draftCache = PrescriptionDraftCache();
  
  // Generate unique draft ID for each NFC session
  late final String _draftId;
  
  bool _isNfcAvailable = false;
  bool _isNfcEnabled = false;
  bool _isProcessing = false;
  bool _isUploading = false;
  bool _hasJustRead = false; // Flag to prevent multiple reads
  
  PrescripcionWithMedications? _readPrescription;
  Prescripcion? _mockPrescription;
  
  @override
  void initState() {
    super.initState();
    
    // Generate unique draft ID or load from arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['draftId'] != null) {
      _draftId = args['draftId'] as String;
      _loadDraftIfExists();
    } else {
      // Generate new draft ID with timestamp for uniqueness
      _draftId = 'nfc_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    // Save draft if there's unuploaded prescription
    if (_readPrescription != null) {
      _saveDraftIfNeeded();
    }
    // Cancel any ongoing NFC session when leaving the page
    _nfcService.cancelSession();
    super.dispose();
  }
  
  /// Load draft from cache if it exists
  Future<void> _loadDraftIfExists() async {
    final draft = _draftCache.getDraft(_draftId);
    if (draft == null) return;
    
    debugPrint('📄 [NFC Upload] Restoring draft from ${draft.lastModified}');
    
    try {
      // Restore prescription from draft data
      final prescData = draft.data['prescription'] as Map<String, dynamic>?;
      if (prescData != null) {
        final prescripcion = Prescripcion.fromMap(prescData);
        
        // Restore medications if available
        List<MedicamentoPrescripcion> medications = [];
        if (draft.data['medications'] != null) {
          final medsData = draft.data['medications'] as List<dynamic>;
          medications = medsData
              .map((m) => MedicamentoPrescripcion.fromMap(m as Map<String, dynamic>))
              .toList();
        }
        
        setState(() {
          _readPrescription = PrescripcionWithMedications(
            prescripcion: prescripcion,
            medicamentos: medications,
          );
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📄 Borrador de prescripción NFC restaurado'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [NFC Upload] Error restoring draft: $e');
    }
  }
  
  /// Save draft if there's unuploaded prescription
  void _saveDraftIfNeeded() {
    if (_readPrescription == null) {
      debugPrint('📄 [NFC Upload] No prescription to save as draft');
      return;
    }
    
    try {
      _draftCache.saveDraft(
        draftId: _draftId,
        data: {
          'type': 'nfc', // Identify draft type
          'prescription': _readPrescription!.prescripcion.toMap(),
          'medications': _readPrescription!.medicamentos.map((m) => m.toMap()).toList(),
          'medicationCount': _readPrescription!.medicamentos.length, // For display
        },
        imagePaths: [], // NFC doesn't have images
      );
      
      debugPrint('💾 [NFC Upload] Draft saved');
    } catch (e) {
      debugPrint('❌ [NFC Upload] Error saving draft: $e');
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final available = await _nfcService.isAvailable();
      
      setState(() {
        _isNfcAvailable = available;
        _isNfcEnabled = available; // If available, assume enabled
      });

      if (!available) {
        _showNfcNotAvailableDialog();
      }
    } catch (e) {
      debugPrint('Error checking NFC: $e');
    }
  }

  void _showNfcNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.nfc, color: Theme.of(context).disabledColor),
            const SizedBox(width: 12),
            const Text('NFC No Disponible'),
          ],
        ),
        content: const Text(
          'Tu dispositivo no soporta NFC o está desactivado. Por favor, verifica la configuración de tu dispositivo.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showNfcDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.nfc, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('NFC Desactivado'),
          ],
        ),
        content: const Text(
          'NFC podría estar desactivado en tu dispositivo. Por favor, actívalo en Configuración para usar esta función.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNfcRead() async {
    if (!_isNfcAvailable) {
      _showErrorSnackBar('NFC no disponible en este dispositivo');
      return;
    }

    if (!_isNfcEnabled) {
      _showNfcDisabledDialog();
      return;
    }

    // Prevent multiple reads if we just read a tag
    if (_hasJustRead) {
      _showInfoSnackBar('Ya se ha leído una prescripción. Aleja el tag y vuelve a acercarlo para leer de nuevo.');
      return;
    }

    // Clear any previous results before starting new action
    setState(() {
      _isProcessing = true;
      _readPrescription = null;
      _mockPrescription = null;
    });

    // Cancel any previous NFC session before starting new one
    await _nfcService.cancelSession();

    try {
      _showInfoSnackBar('Acerca tu dispositivo al tag NFC...');
      
      final jsonString = await _nfcService.readNdefJson();

      if (jsonString == null || jsonString.isEmpty) {
        _showErrorSnackBar('Tag vacío o sin prescripción');
        return;
      }

      // Parse JSON string to Map
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Convert from NFC JSON to Prescripcion
      final prescripcion = PrescriptionAdapter.fromNdefJson(jsonString);
      
      // Create medications from the adapter data
      final medicamentos = <MedicamentoPrescripcion>[];
      if (jsonData.containsKey('medicamentos') && jsonData['medicamentos'] != null) {
        final medsList = jsonData['medicamentos'] as List;
        for (var medData in medsList) {
          medicamentos.add(MedicamentoPrescripcion(
            id: medData['id'] ?? 'med_${DateTime.now().millisecondsSinceEpoch}',
            medicamentoRef: medData['medicamentoRef'] ?? '',
            nombre: medData['nombre'] ?? 'Medicamento sin nombre',
            dosisMg: (medData['dosisMg'] ?? 0).toDouble(),
            frecuenciaHoras: medData['frecuenciaHoras'] ?? 8,
            duracionDias: medData['duracionDias'] ?? 7,
            fechaInicio: DateTime.tryParse(medData['fechaInicio'] ?? '') ?? DateTime.now(),
            fechaFin: DateTime.tryParse(medData['fechaFin'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
            observaciones: medData['observaciones'],
            activo: medData['activo'] ?? true,
            userId: UserSession().currentUser.value?.uid ?? '',
            prescripcionId: prescripcion.id,
          ));
        }
      }

      setState(() {
        _readPrescription = PrescripcionWithMedications(
          prescripcion: prescripcion,
          medicamentos: medicamentos,
        );
        _hasJustRead = true; // Set flag to prevent re-reading
      });
      
      // Save draft after reading prescription
      _saveDraftIfNeeded();

      _showSuccessSnackBar('Prescripción leída exitosamente');
      
      // Reset the flag after 3 seconds to allow reading again
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _hasJustRead = false);
        }
      });
    } on PlatformException catch (e) {
      debugPrint('NFC platform error: $e');
      if (e.code == 'NFCUserCanceled' || e.code == 'userCanceled') {
        _showInfoSnackBar('Lectura NFC cancelada');
      } else if (e.code == 'NFCPermissionDenied' || 
                 e.message?.toLowerCase().contains('permission') == true) {
        _showPermissionDeniedDialog(
          'Permisos NFC Denegados',
          'La aplicación necesita permiso para usar NFC y leer tags.\n\n'
          'Por favor, ve a Configuración > Aplicaciones > MyMeds > Permisos y activa el permiso de NFC.',
        );
      } else if (e.code == 'NFCNotEnabled' || e.message?.toLowerCase().contains('disabled') == true) {
        _showNfcDisabledDialog();
      } else {
        _showErrorSnackBar('Error NFC: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('NFC read error: $e');
      _showErrorSnackBar('Error al leer NFC: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleNfcWrite() async {
    if (!_isNfcAvailable) {
      _showErrorSnackBar('NFC no disponible en este dispositivo');
      return;
    }

    if (!_isNfcEnabled) {
      _showNfcDisabledDialog();
      return;
    }

    // Clear any previous results before starting new action
    setState(() {
      _readPrescription = null;
      _mockPrescription = null;
    });

    // Cancel any previous NFC session
    await _nfcService.cancelSession();

    // Show selection dialog: existing prescription or create mock
    final choice = await _showWriteOptionsDialog();
    
    if (choice == null) return;

    if (choice == 'existing') {
      await _writeExistingPrescription();
    } else if (choice == 'mock') {
      await _createAndWriteMockPrescription();
    }
  }

  Future<String?> _showWriteOptionsDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escribir en NFC'),
        content: const Text('¿Qué deseas escribir en el tag NFC?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'mock'),
            child: const Text('Crear Prescripción de Prueba'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'existing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Prescripción Existente'),
          ),
        ],
      ),
    );
  }

  Future<void> _writeExistingPrescription() async {
    setState(() => _isProcessing = true);

    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        _showErrorSnackBar('Usuario no autenticado');
        return;
      }

      // Load user prescriptions with medications
      final prescriptions = await _prescripcionRepo.getPrescripcionesWithMedicationsByUser(userId);

      if (prescriptions.isEmpty) {
        if (!mounted) return;
        _showErrorSnackBar('No tienes prescripciones guardadas');
        return;
      }

      // Show selection dialog
      final selected = await _showPrescriptionSelectionDialog(prescriptions);
      
      if (selected == null) return;

      // Convert to NFC format (returns JSON string)
      final jsonString = PrescriptionAdapter.toNdefJson(selected.prescripcion);
      
      // Parse to Map to add medications
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        _showErrorSnackBar('Error al procesar prescripción: formato JSON inválido');
        return;
      }
      
      // Add medications to JSON (convert all DateTime to ISO strings for NFC compatibility)
      try {
        jsonData['medicamentos'] = selected.medicamentos.map((med) {
          // Ensure all fields are JSON-serializable
          return {
            'id': med.id,
            'medicamentoRef': med.medicamentoRef,
            'nombre': med.nombre,
            'dosisMg': med.dosisMg.toDouble(),
            'frecuenciaHoras': med.frecuenciaHoras,
            'duracionDias': med.duracionDias,
            'fechaInicio': med.fechaInicio.toIso8601String(),
            'fechaFin': med.fechaFin.toIso8601String(),
            'observaciones': med.observaciones ?? '',
            'activo': med.activo,
          };
        }).toList();
      } catch (e) {
        _showErrorSnackBar('Error al procesar medicamentos: ${e.toString()}');
        return;
      }

      // Convert back to JSON string and validate
      String completeJsonString;
      try {
        completeJsonString = jsonEncode(jsonData);
      } catch (e) {
        _showErrorSnackBar('Error al generar JSON: ${e.toString()}');
        return;
      }

      // Check payload size (NFC tags have limited capacity, typically 888 bytes for NTAG216)
      final payloadSize = utf8.encode(completeJsonString).length;
      if (payloadSize > 800) {
        _showInfoSnackBar('Datos muy grandes ($payloadSize bytes). Se intentará comprimir...');
      }

      _showInfoSnackBar('Acerca tu dispositivo al tag NFC...');
      
      try {
        final writeResult = await _nfcService.writeNdefJson(completeJsonString);
        
        if (!mounted) return;
        
        // Show appropriate message based on result
        if (writeResult['warning'] != null) {
          _showInfoSnackBar('NFC: ${writeResult['warning']}');
        } else {
          _showSuccessSnackBar('Prescripción escrita en NFC exitosamente');
        }
      } catch (e) {
        // Re-throw to be caught by outer catch
        rethrow;
      }
    } on PlatformException catch (e) {
      debugPrint('NFC write platform error: $e');
      if (e.code == 'NFCUserCanceled' || e.code == 'userCanceled') {
        _showInfoSnackBar('Escritura NFC cancelada');
      } else if (e.code == 'NFCPermissionDenied' || 
                 e.message?.toLowerCase().contains('permission') == true) {
        _showPermissionDeniedDialog(
          'Permisos NFC Denegados',
          'La aplicación necesita permiso para usar NFC y escribir en tags.\n\n'
          'Por favor, ve a Configuración > Aplicaciones > MyMeds > Permisos y activa el permiso de NFC.',
        );
      } else if (e.code == 'NFCNotEnabled' || e.message?.toLowerCase().contains('disabled') == true) {
        _showNfcDisabledDialog();
      } else if (e.code == 'NFCTagNotWritable' || e.message?.toLowerCase().contains('read-only') == true) {
        _showErrorSnackBar('Este tag NFC es de solo lectura');
      } else {
        _showErrorSnackBar('Error NFC: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('NFC write error: $e');
      _showErrorSnackBar('Error al escribir NFC: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _createAndWriteMockPrescription() async {
    final prescription = await _showMockPrescriptionDialog();
    
    if (prescription == null) return;

    setState(() {
      _isProcessing = true;
      _mockPrescription = prescription;
    });

    try {
      final jsonData = PrescriptionAdapter.toNdefJson(prescription);

      _showInfoSnackBar('Acerca tu dispositivo al tag NFC...');
      final writeResult = await _nfcService.writeNdefJson(jsonData);

      if (!mounted) return;
      
      // Show appropriate message based on result
      if (writeResult['warning'] != null) {
        _showInfoSnackBar('NFC: ${writeResult['warning']}');
      } else {
        _showSuccessSnackBar('Prescripción de prueba escrita en NFC');
      }
    } on PlatformException catch (e) {
      debugPrint('NFC write platform error: $e');
      if (e.code == 'NFCUserCanceled' || e.code == 'userCanceled') {
        _showInfoSnackBar('Escritura NFC cancelada');
      } else if (e.code == 'NFCPermissionDenied' || 
                 e.message?.toLowerCase().contains('permission') == true) {
        _showPermissionDeniedDialog(
          'Permisos NFC Denegados',
          'La aplicación necesita permiso para usar NFC y escribir en tags.\n\n'
          'Por favor, ve a Configuración > Aplicaciones > MyMeds > Permisos y activa el permiso de NFC.',
        );
      } else if (e.code == 'NFCNotEnabled' || e.message?.toLowerCase().contains('disabled') == true) {
        _showNfcDisabledDialog();
      } else if (e.code == 'NFCTagNotWritable' || e.message?.toLowerCase().contains('read-only') == true) {
        _showErrorSnackBar('Este tag NFC es de solo lectura');
      } else {
        _showErrorSnackBar('Error NFC: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('NFC write error: $e');
      _showErrorSnackBar('Error al escribir NFC: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<Prescripcion?> _showMockPrescriptionDialog() async {
    final medicoController = TextEditingController(text: 'Dr. Juan Pérez');
    final diagnosticoController = TextEditingController(text: 'Gripe común');
    
    return showDialog<Prescripcion>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Prescripción de Prueba'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medicoController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Médico',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: diagnosticoController,
                decoration: const InputDecoration(
                  labelText: 'Diagnóstico',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final prescription = Prescripcion(
                id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
                fechaCreacion: DateTime.now(),
                diagnostico: diagnosticoController.text,
                medico: medicoController.text,
                activa: true,
              );
              Navigator.pop(context, prescription);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<PrescripcionWithMedications?> _showPrescriptionSelectionDialog(
    List<PrescripcionWithMedications> prescriptions,
  ) async {
    return showDialog<PrescripcionWithMedications>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Prescripción'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final prescription = prescriptions[index];
              final dateFormatter = DateFormat('dd/MM/yyyy');
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: prescription.activa 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey,
                    child: Icon(
                      prescription.activa ? Icons.check : Icons.close,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    prescription.medico,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prescription.diagnostico),
                      Text(
                        '${dateFormatter.format(prescription.fechaCreacion)} • ${prescription.medicationCount} medicamentos',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, prescription),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearNfc() async {
    if (!_isNfcAvailable) {
      _showErrorSnackBar('NFC no disponible en este dispositivo');
      return;
    }

    if (!_isNfcEnabled) {
      _showNfcDisabledDialog();
      return;
    }

    // Clear any previous results before starting new action
    setState(() {
      _readPrescription = null;
      _mockPrescription = null;
    });

    final confirmed = await _showConfirmDialog(
      title: 'Limpiar Tag NFC',
      message: '¿Estás seguro de que deseas borrar todo el contenido del tag NFC?',
      confirmText: 'Limpiar',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    // Cancel any previous NFC session
    await _nfcService.cancelSession();

    try {
      _showInfoSnackBar('Acerca tu dispositivo al tag NFC...');
      await _nfcService.clearTag();
      
      if (!mounted) return;
      _showSuccessSnackBar('Tag NFC limpiado exitosamente');
    } on PlatformException catch (e) {
      debugPrint('NFC clear platform error: $e');
      if (e.code == 'NFCUserCanceled' || e.code == 'userCanceled') {
        _showInfoSnackBar('Limpieza NFC cancelada');
      } else if (e.code == 'NFCPermissionDenied' || 
                 e.message?.toLowerCase().contains('permission') == true) {
        _showPermissionDeniedDialog(
          'Permisos NFC Denegados',
          'La aplicación necesita permiso para usar NFC y modificar tags.\n\n'
          'Por favor, ve a Configuración > Aplicaciones > MyMeds > Permisos y activa el permiso de NFC.',
        );
      } else if (e.code == 'NFCNotEnabled' || e.message?.toLowerCase().contains('disabled') == true) {
        _showNfcDisabledDialog();
      } else if (e.code == 'NFCTagNotWritable' || e.message?.toLowerCase().contains('read-only') == true) {
        _showErrorSnackBar('Este tag NFC es de solo lectura');
      } else {
        _showErrorSnackBar('Error NFC: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('NFC clear error: $e');
      _showErrorSnackBar('Error al limpiar NFC: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUploadPrescription() async {
    if (_readPrescription == null) return;

    final confirmed = await _showConfirmDialog(
      title: 'Subir Prescripción',
      message: '¿Deseas guardar esta prescripción en tu cuenta de MyMeds?',
      confirmText: 'Subir',
    );

    if (confirmed != true) return;

    setState(() => _isUploading = true);

    try {
      final userId = UserSession().currentUser.value?.uid;
      if (userId == null) {
        _showErrorSnackBar('Usuario no autenticado');
        return;
      }

      // Generate new ID for the prescription
      final newId = 'presc_${DateTime.now().millisecondsSinceEpoch}';
      final updatedPrescription = _readPrescription!.prescripcion.copyWith(id: newId);

      // Update medication prescription IDs and user IDs
      final updatedMedications = _readPrescription!.medicamentos.map((med) {
        return {
          'id': med.id,
          'medicamentoRef': med.medicamentoRef,
          'nombre': med.nombre,
          'dosisMg': med.dosisMg,
          'frecuenciaHoras': med.frecuenciaHoras,
          'duracionDias': med.duracionDias,
          'fechaInicio': Timestamp.fromDate(med.fechaInicio), // Convert to Timestamp
          'fechaFin': Timestamp.fromDate(med.fechaFin), // Convert to Timestamp
          'observaciones': med.observaciones,
          'activo': med.activo,
          'userId': userId,
          'prescripcionId': newId,
        };
      }).toList();

      // Upload to Firestore
      // Check connectivity before upload
      final isOnline = await ConnectivityService().checkConnectivity();
      
      if (isOnline) {
        // Online: Upload to Firestore immediately
        await _prescripcionRepo.createWithMedicamentos(
          userId: userId,
          prescripcion: updatedPrescription,
          medicamentos: updatedMedications,
        );

        // Refresh user session
        await UserSession().refreshPrescripciones();

        if (!mounted) return;
        
        // Clear draft on successful upload
        await _draftCache.removeDraft(_draftId);
        debugPrint('🗑️ [NFC Upload] Draft cleared after successful upload');
        
        _showSuccessDialog(
          title: 'Prescripción Guardada',
          message: 'La prescripción ha sido guardada exitosamente en tu cuenta.\n\nID: $newId',
        );
      } else {
        // Offline: Queue for later upload (will be implemented in task 5)
        // Keep draft when saving offline
        _saveDraftIfNeeded();
        
        if (!mounted) return;
        
        _showInfoSnackBar(
          '📴 Prescripción guardada, será sincronizada una vez tengas conexión.',
        );
        
        _showSuccessDialog(
          title: 'Guardado localmente',
          message: 'La prescripción se guardó en tu dispositivo y se sincronizará automáticamente cuando tengas conexión.\n\nID: $newId',
        );
      }

      // Clear the read prescription after successful upload
      setState(() => _readPrescription = null);
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
    bool isDestructive = false,
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
              backgroundColor: isDestructive ? Colors.red : Theme.of(context).colorScheme.primary,
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
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            overflow: TextOverflow.visible,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('OK'),
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
        duration: const Duration(seconds: 3),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargar Prescripción por NFC'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NFC Status Card
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
                      Icons.nfc,
                      size: 64,
                      color: _isNfcAvailable && _isNfcEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isNfcAvailable
                          ? (_isNfcEnabled ? 'NFC Activo' : 'NFC Desactivado')
                          : 'NFC No Disponible',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isNfcAvailable && _isNfcEnabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isNfcAvailable
                          ? (_isNfcEnabled
                              ? 'Tu dispositivo está listo para usar NFC'
                              : 'Por favor activa NFC en configuración')
                          : 'Este dispositivo no soporta NFC',
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

            // Action Buttons
            Text(
              'Acciones NFC',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Read NFC Button
            _buildActionButton(
              icon: Icons.nfc,
              label: 'Leer Prescripción desde NFC',
              description: 'Escanea un tag NFC para cargar una prescripción',
              onPressed: _isProcessing ? null : _handleNfcRead,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 12),

            // Write NFC Button
            _buildActionButton(
              icon: Icons.upload,
              label: 'Escribir Prescripción en NFC',
              description: 'Guarda una prescripción en un tag NFC',
              onPressed: _isProcessing ? null : _handleNfcWrite,
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            // Clear NFC Button
            _buildActionButton(
              icon: Icons.clear,
              label: 'Limpiar Tag NFC',
              description: 'Borra todo el contenido de un tag NFC',
              onPressed: _isProcessing ? null : _handleClearNfc,
              color: Colors.red,
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
                        'Procesando...\nAcerca tu dispositivo al tag NFC',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Preview Section
            if (_readPrescription != null) ...[
              const SizedBox(height: 24),
              Text(
                'Prescripción Leída',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              PrescriptionPreviewWidget(
                prescription: _readPrescription!,
                onUpload: _handleUploadPrescription,
                isLoading: _isUploading,
                showActions: true,
              ),
            ],

            if (_mockPrescription != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 12),
                          Text(
                            'Prescripción de Prueba Creada',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Médico: ${_mockPrescription!.medico}'),
                      Text('Diagnóstico: ${_mockPrescription!.diagnostico}'),
                      const SizedBox(height: 8),
                      Text(
                        'Esta prescripción de prueba ha sido escrita en el tag NFC.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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
                        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Cómo usar NFC',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem('1. Asegúrate de que NFC esté activado 1'),
                    _buildHelpItem('2. Mantén el teléfono cerca del tag NFC'),
                    _buildHelpItem('3. Espera la confirmación'),
                    _buildHelpItem('4. No muevas el teléfono hasta que termine'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback? onPressed,
    required Color color,
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
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
