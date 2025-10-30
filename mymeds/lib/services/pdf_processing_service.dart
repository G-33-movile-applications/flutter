import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/prescripcion.dart';
import '../models/prescripcion_with_medications.dart';
import '../models/medicamento_prescripcion.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
/// Servicio para procesar archivos PDF y extraer información de prescripciones
class PdfProcessingService {
  final _uuid = Uuid();

  /// Extrae el texto del PDF
  Future<String> extractText(File pdfFile) async {
    try {
      debugPrint('🔄 Extrayendo texto del PDF: ${path.basename(pdfFile.path)}');
      
      // Abre el documento PDF
      final document = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      
      // Extrae todo el texto del documento
      final allText = extractor.extractText();
      debugPrint('✅ Extracción de texto completada');

      // Cierra el documento para liberar recursos
      document.dispose();
      return allText;
    } catch (e) {
      debugPrint('❌ Error extrayendo texto del PDF: $e');
      throw Exception('Error extrayendo texto del PDF: $e');
    }
  }

  /// Procesa un archivo PDF y devuelve una prescripción con sus medicamentos
  Future<PrescripcionWithMedications> processPrescription(File pdfFile) async {
    try {
      debugPrint('🔄 Procesando prescripción del PDF: ${path.basename(pdfFile.path)}');
      
      // Extraer texto del PDF
      final text = await extractText(pdfFile);
      
      // Extraer información general de la prescripción
      final prescripcionId = 'pres_${_uuid.v4()}';
      final prescripcionInfo = _extractPrescriptionInfo(text, prescripcionId);
      
      // Extraer y procesar la información de medicamentos
      final List<MedicamentoPrescripcion> medicamentosPrescripcion = [];
      
      final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      String? currentMedName;
      double? currentDosisMg;
      String? currentDescription;
      int? currentFrecuenciaHoras;
      
      for (final line in lines) {
        if (RegExp(r'tableta|cápsula|pastilla|comprimido', caseSensitive: false).hasMatch(line)) {
          // Si tenemos un medicamento anterior, lo agregamos a la lista
          if (currentMedName != null) {
            final medId = 'med_${_uuid.v4().substring(0, 8)}';
            medicamentosPrescripcion.add(
              MedicamentoPrescripcion(
                id: medId,
                medicamentoRef: '/usuarios/${prescripcionInfo.id}/medicamentosUsuario/$medId',
                nombre: currentMedName,
                dosisMg: currentDosisMg ?? 0.0,
                frecuenciaHoras: currentFrecuenciaHoras ?? 24,
                duracionDias: 30,
                fechaInicio: DateTime.now(),
                fechaFin: DateTime.now().add(const Duration(days: 30)),
                observaciones: currentDescription,
                activo: true,
                userId: '',
                prescripcionId: prescripcionId,
              ),
            );
          }
          
          // Comenzar nuevo medicamento
          currentMedName = _extractMedName(line);
          currentDosisMg = _extractDosage(line);
          currentDescription = line;
          currentFrecuenciaHoras = _extractFrequency(line);
        } else if (currentMedName != null) {
          // Agregar línea a la descripción del medicamento actual
          currentDescription = '${currentDescription ?? ''}\n$line';
          
          // Intentar extraer más información
          final dosisMg = _extractDosage(line);
          if (dosisMg != null) currentDosisMg = dosisMg;
          
          final frecuencia = _extractFrequency(line);
          if (frecuencia != null) currentFrecuenciaHoras = frecuencia;
        }
      }
      
      // Agregar el último medicamento si existe
      if (currentMedName != null) {
        final medId = 'med_${_uuid.v4().substring(0, 8)}';
        medicamentosPrescripcion.add(
          MedicamentoPrescripcion(
            id: medId,
            medicamentoRef: '/usuarios/${prescripcionInfo.id}/medicamentosUsuario/$medId',
            nombre: currentMedName,
            dosisMg: currentDosisMg ?? 0.0,
            frecuenciaHoras: currentFrecuenciaHoras ?? 24,
            duracionDias: 30,
            fechaInicio: DateTime.now(),
            fechaFin: DateTime.now().add(const Duration(days: 30)),
            observaciones: currentDescription,
            activo: true,
            userId: '',
            prescripcionId: prescripcionId,
          ),
        );
      }

      return PrescripcionWithMedications(
        prescripcion: prescripcionInfo,
        medicamentos: medicamentosPrescripcion,
      );
    } catch (e) {
      debugPrint('❌ Error procesando prescripción: $e');
      throw Exception('Error procesando prescripción: $e');
    }
  }

  /// Extrae información general de la prescripción del texto
  Prescripcion _extractPrescriptionInfo(String text, [String? prescripcionId]) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    String? medico;
    String? diagnostico;
    DateTime fecha = DateTime.now();
    
    for (final line in lines) {
      // Buscar nombre del médico
      if (RegExp(r'Dr\.|Doctor|Dra\.', caseSensitive: false).hasMatch(line)) {
        medico = line.trim();
      }
      
      // Buscar diagnóstico
      if (RegExp(r'diagnóstico|diagnostico|padecimiento', caseSensitive: false).hasMatch(line)) {
        diagnostico = line.replaceAll(RegExp(r'diagnóstico|diagnostico|padecimiento', caseSensitive: false), '').trim();
      }
      
      // Buscar fecha
      final dateMatch = RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}').firstMatch(line);
      if (dateMatch != null) {
        try {
          final dateStr = dateMatch.group(0)!;
          fecha = DateTime.parse(dateStr.replaceAll(RegExp(r'[-/]'), '-'));
        } catch (e) {
          debugPrint('Error parseando fecha: $e');
        }
      }
    }

    return Prescripcion(
      id: _uuid.v4(),
      fechaCreacion: fecha,
      diagnostico: diagnostico ?? 'Diagnóstico no especificado',
      medico: medico ?? 'Médico no especificado',
      activa: true,
    );
  }

  // Funciones auxiliares para extraer información
  String? _extractMedName(String line) {
    final match = RegExp(r'([A-Za-z]+(?:\s+[A-Za-z]+)*)\s+\d+', caseSensitive: false).firstMatch(line);
    return match?.group(1)?.trim();
  }

  double? _extractDosage(String line) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:mg|g)', caseSensitive: false).firstMatch(line);
    if (match != null) {
      final value = double.tryParse(match.group(1) ?? '0') ?? 0;
      // Si la unidad es g, convertir a mg
      if (match.group(0)?.toLowerCase().endsWith('g') ?? false) {
        return value * 1000;
      }
      return value;
    }
    return null;
  }

  int? _extractFrequency(String line) {
    // Patrones comunes de frecuencia
    if (RegExp(r'cada\s+(\d+)\s*horas?', caseSensitive: false).hasMatch(line)) {
      final match = RegExp(r'cada\s+(\d+)\s*horas?', caseSensitive: false).firstMatch(line);
      return int.tryParse(match?.group(1) ?? '24');
    }
    // Convertir expresiones comunes a horas
    if (line.toLowerCase().contains('una vez al día') || 
        line.toLowerCase().contains('daily') || 
        line.toLowerCase().contains('cada 24 horas')) {
      return 24;
    }
    if (line.toLowerCase().contains('dos veces al día') || 
        line.toLowerCase().contains('cada 12 horas')) {
      return 12;
    }
    if (line.toLowerCase().contains('tres veces al día') || 
        line.toLowerCase().contains('cada 8 horas')) {
      return 8;
    }
    if (line.toLowerCase().contains('cuatro veces al día') || 
        line.toLowerCase().contains('cada 6 horas')) {
      return 6;
    }
    return null;
  }

}