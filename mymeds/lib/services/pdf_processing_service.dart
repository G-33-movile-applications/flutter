import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/medicamento.dart';
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
      final prescripcionInfo = _extractPrescriptionInfo(text);
      
      // Extraer información de medicamentos
      final medicamentos = parseMedicationInfo(text);

      // Crear lista de MedicamentoPrescripcion
      final medicamentosPrescripcion = medicamentos.map((med) {
        if (med is! Pastilla) {
          throw Exception('Tipo de medicamento no soportado: ${med.runtimeType}');
        }
        
        return MedicamentoPrescripcion(
          id: _uuid.v4(),
          medicamentoRef: med.id,
          nombre: med.nombre,
          dosisMg: med.dosisMg,
          frecuenciaHoras: 24, // Valor por defecto
          duracionDias: 30, // Valor por defecto
          fechaInicio: DateTime.now(),
          fechaFin: DateTime.now().add(const Duration(days: 30)),
          observaciones: med.descripcion,
          activo: true,
          userId: '', // Se asignará al guardar
          prescripcionId: prescripcionInfo.id,
        );
      }).toList();

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
  Prescripcion _extractPrescriptionInfo(String text) {
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

  /// Crea un objeto Medicamento con la información extraída
  Medicamento _createMedicamento({
    required String nombre,
    required String descripcion,
    double? dosisMg,
    int? cantidad,
    String? via,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? frecuenciaHoras,
  }) {
    // Como todos los medicamentos en recetas serán pastillas por ahora
    return Pastilla(
      id: _uuid.v4(),
      nombre: nombre,
      descripcion: descripcion,
      esRestringido: false,
      dosisMg: dosisMg ?? 0.0,
      cantidad: cantidad ?? 0,
    );
  }

  /// Parsea información de medicamentos del texto extraído
  List<Medicamento> parseMedicationInfo(String text) {
    debugPrint('🔍 Buscando medicamentos en texto...');
    final medicamentos = <Medicamento>[];
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    String? currentMedName;
    String? currentDosisDesc;
    double? currentDosisMg;
    int? currentCantidad;
    String? currentVia;
    int? currentFrecuenciaHoras;
    DateTime? currentFechaInicio;
    DateTime? currentFechaFin;

    for (final line in lines) {
      // Buscar nombres de medicamentos y su información
      if (RegExp(r'tableta|cápsula|pastilla|comprimido', caseSensitive: false).hasMatch(line)) {
        if (currentMedName != null) {
          // Crear y guardar medicamento anterior
          medicamentos.add(_createMedicamento(
            nombre: currentMedName,
            descripcion: currentDosisDesc ?? '',
            dosisMg: currentDosisMg,
            cantidad: currentCantidad,
          ));
        }
        
        // Comenzar nuevo medicamento
        currentMedName = _extractMedName(line);
        currentDosisDesc = line;
        currentDosisMg = _extractDosage(line);
        currentCantidad = _extractQuantity(line);
        currentVia = _extractVia(line);
        currentFrecuenciaHoras = _extractFrequency(line);
        
        // Intentar extraer fechas
        final dates = _extractDates(line);
        currentFechaInicio = dates.$1;
        currentFechaFin = dates.$2;
      }
      // Buscar información adicional del medicamento actual
      else if (currentMedName != null) {
        currentDosisDesc = '${currentDosisDesc ?? ''}\n$line';
        
        // Intentar extraer más información si está disponible
        final dosisMg = _extractDosage(line);
        if (dosisMg != null && dosisMg > 0) currentDosisMg = dosisMg;
        
        final cantidad = _extractQuantity(line);
        if (cantidad != null && cantidad > 0) currentCantidad = cantidad;
        
        final via = _extractVia(line);
        if (via != null) currentVia = via;
        
        final frecuencia = _extractFrequency(line);
        if (frecuencia != null) currentFrecuenciaHoras = frecuencia;
        
        // Intentar extraer fechas si no se han encontrado
        if (currentFechaInicio == null || currentFechaFin == null) {
          final dates = _extractDates(line);
          if (dates.$1 != null) currentFechaInicio = dates.$1;
          if (dates.$2 != null) currentFechaFin = dates.$2;
        }
      }
    }

    // Agregar el último medicamento si existe
    if (currentMedName != null) {
      medicamentos.add(_createMedicamento(
        nombre: currentMedName,
        descripcion: currentDosisDesc ?? '',
        dosisMg: currentDosisMg,
        cantidad: currentCantidad,
        via: currentVia,
        fechaInicio: currentFechaInicio,
        fechaFin: currentFechaFin,
        frecuenciaHoras: currentFrecuenciaHoras,
      ));
    }

    debugPrint('💊 Se encontraron ${medicamentos.length} medicamentos');
    return medicamentos;
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

  int? _extractQuantity(String line) {
    final match = RegExp(r'(\d+)\s*(?:tableta|cápsula|pastilla|comprimido)', caseSensitive: false).firstMatch(line);
    return int.tryParse(match?.group(1) ?? '0');
  }

  String? _extractVia(String line) {
    if (RegExp(r'oral|sublingual', caseSensitive: false).hasMatch(line)) {
      return 'Oral';
    } else if (RegExp(r'inyectable|intramuscular|intravenosa', caseSensitive: false).hasMatch(line)) {
      return 'Inyectable';
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

  (DateTime?, DateTime?) _extractDates(String line) {
    DateTime? startDate;
    DateTime? endDate;
    
    // Buscar fechas en formato dd/mm/yyyy o dd-mm-yyyy
    final dateMatches = RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}').allMatches(line);
    final dates = dateMatches.map((m) {
      try {
        final dateStr = m.group(0)!.replaceAll(RegExp(r'[-/]'), '-');
        return DateTime.parse(dateStr);
      } catch (e) {
        debugPrint('Error parseando fecha: $e');
        return null;
      }
    }).whereType<DateTime>().toList();

    if (dates.length >= 2) {
      // Si hay dos fechas, asumir que son inicio y fin
      dates.sort();
      startDate = dates.first;
      endDate = dates.last;
    } else if (dates.length == 1) {
      // Si hay una fecha, asumir que es la fecha de inicio
      startDate = dates.first;
      // La fecha de fin será 30 días después por defecto
      endDate = startDate.add(const Duration(days: 30));
    }

    return (startDate, endDate);
  }
}