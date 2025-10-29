import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_info.dart';
import '../services/pdf_processing_service.dart';

class PdfRepository {
  final FirebaseFirestore _firestore;
  final PdfProcessingService _pdfService;
  final String userId;

  PdfRepository({
    required this.userId,
    FirebaseFirestore? firestore,
    PdfProcessingService? pdfService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _pdfService = pdfService ?? PdfProcessingService();

  /// Procesa archivos PDF y guarda los medicamentos encontrados
  Future<List<MedicationInfo>> processPrescriptionPdfs(List<File> pdfFiles) async {
    try {
      print('🔄 Iniciando procesamiento de ${pdfFiles.length} archivos PDF');
      final allMedications = <MedicationInfo>[];

      for (final file in pdfFiles) {
        try {
          print('📄 Procesando archivo: ${file.path}');
          final fileName = file.path.split(Platform.pathSeparator).last;
          
          // Procesa PDF y extrae medicamentos
          final result = await _pdfService.processPdf(file, fileName);
          
          // Guarda texto extraído para referencia
          await _saveExtractedText(fileName, result.extractedText);
          
          // Guarda medicamentos en Firestore
          for (final med in result.medications) {
            final savedMed = await saveMedication(med);
            allMedications.add(savedMed);
          }

        } catch (e) {
          print('❌ Error procesando archivo: $e');
          // Continúa con el siguiente archivo
          continue;
        }
      }

      print('✅ Procesamiento completado. ${allMedications.length} medicamentos encontrados');
      return allMedications;

    } catch (e) {
      print('❌ Error en procesamiento de PDFs: $e');
      rethrow;
    }
  }

  /// Guarda un medicamento en Firestore
  Future<MedicationInfo> saveMedication(MedicationInfo medication) async {
    try {
      final medicationRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medication.medicationId);

      await medicationRef.set(medication.toMap());
      print('💊 Medicamento guardado: ${medication.name}');

      return medication;
    } catch (e) {
      print('❌ Error guardando medicamento: $e');
      rethrow;
    }
  }

  /// Guarda el texto extraído del PDF para referencia futura
  Future<void> _saveExtractedText(String fileName, String extractedText) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptionTexts')
          .doc(fileName.replaceAll('.pdf', ''));

      await docRef.set({
        'fileName': fileName,
        'text': extractedText,
        'processedAt': FieldValue.serverTimestamp(),
      });

      print('📝 Texto extraído guardado para: $fileName');
    } catch (e) {
      print('⚠️ Error guardando texto extraído: $e');
      // No propaga el error ya que es información secundaria
    }
  }

  /// Obtiene los medicamentos activos de un usuario
  Future<List<MedicationInfo>> getActiveMedications() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('active', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => MedicationInfo.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo medicamentos activos: $e');
      rethrow;
    }
  }

  /// Actualiza el estado activo de un medicamento
  Future<void> updateMedicationStatus(String medicationId, bool active) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .update({'active': active});
    } catch (e) {
      print('❌ Error actualizando estado de medicamento: $e');
      rethrow;
    }
  }
}