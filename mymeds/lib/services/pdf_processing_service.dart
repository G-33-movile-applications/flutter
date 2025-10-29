import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/medication_info.dart';

class PdfProcessingService {
  /// Procesa un archivo PDF completo
  Future<PdfProcessingResult> processPdf(File pdfFile, String fileName) async {
    try {
      print('🔄 Procesando PDF: $fileName');
      
      // Abre el documento PDF
      final document = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      
      // Extrae todo el texto del documento
      final allText = extractor.extractText();
      print('✅ Extracción de texto completada');

      // Parsea medicamentos del texto extraído
      final medications = await _parseMedicationsFromText(allText, fileName);
      print('💊 Se encontraron ${medications.length} medicamentos');

      return PdfProcessingResult(
        medications: medications,
        extractedText: allText,
      );
    } catch (e) {
      print('❌ Error procesando PDF: $e');
      throw Exception('Error procesando PDF: $e');
    }
  }

  /// Detecta y parsea información de medicamentos desde el texto
  Future<List<MedicationInfo>> _parseMedicationsFromText(
    String text,
    String sourceFile,
  ) async {
    try {
      print('🔍 Buscando medicamentos en texto...');
      final medications = <MedicationInfo>[];
      final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      // Busca ID de prescripción
      var prescriptionId = 'RX-${DateTime.now().millisecondsSinceEpoch % 10000}';
      for (final line in lines) {
        final rxMatch = RegExp(r'RX[- ]?\d+', caseSensitive: false).firstMatch(line);
        if (rxMatch != null) {
          prescriptionId = rxMatch.group(0)!.toUpperCase();
          print('📋 ID Prescripción encontrado: $prescriptionId');
          break;
        }
      }

      // ESTRATEGIA 1: Buscar formato con "Medicamento:" explícito
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        if (line.startsWith('medicamento:') || line.trim() == 'medicamento:') {
          final medBlock = await _extractMedicationBlock(lines, i);
          if (medBlock != null) {
            medications.add(
              medBlock.toMedicationInfo(
                prescriptionId: prescriptionId,
                sourceFile: sourceFile,
              ),
            );
            i = medBlock.lastLineIndex;
          }
        }
      }

      // ESTRATEGIA 2: Buscar patrones directos de medicamento + dosis
      if (medications.isEmpty) {
        print('🔄 Intentando estrategia alternativa...');
        final foundMeds = <String>{};

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          
          // Lista de palabras que NO son medicamentos
          final irrelevantWords = [
            'cantidad', 'duración', 'dosis', 'instrucciones',
            'fecha', 'paciente', 'diagnóstico', 'médico',
            'registro', 'tableta', 'tabletas', 'firma',
            'sello', 'tratante', 'clínica', 'hospital'
          ];

          // Busca patrones como "Losartán 50mg"
          final medMatch = RegExp(r'([A-Za-záéíóúÁÉÍÓÚñÑ]{4,})\s+(\d+)\s*mg', caseSensitive: false)
              .firstMatch(line);

          if (medMatch != null) {
            final medName = medMatch.group(1)!.trim();
            final dose = int.tryParse(medMatch.group(2)!) ?? 0;
            final fullName = '$medName ${dose}mg';

            final isIrrelevant = irrelevantWords.any((word) => 
              medName.toLowerCase().contains(word) || 
              line.toLowerCase().startsWith(word)
            );

            final isLabelOnly = line.toLowerCase().startsWith('cantidad:') ||
                              line.toLowerCase().startsWith('duración:') ||
                              line.toLowerCase().startsWith('dosis:');

            if (!isIrrelevant && !isLabelOnly && dose > 0 && !foundMeds.contains(fullName)) {
              foundMeds.add(fullName);
              print('🎯 Medicamento encontrado: $fullName');

              final medInfo = await _extractMedicationFromAlternateFormat(
                lines,
                i,
                medName,
                dose,
                prescriptionId,
                sourceFile,
              );
              medications.add(medInfo);
            }
          }
        }
      }

      // Si no se encontró nada, agregar placeholder
      if (medications.isEmpty) {
        medications.add(_createDefaultMedication(
          name: 'Medicamento no identificado',
          prescriptionId: prescriptionId,
          sourceFile: sourceFile,
        ));
      }

      return medications;
    } catch (e) {
      print('❌ Error parseando medicamentos: $e');
      return [
        _createDefaultMedication(
          name: 'Error al procesar',
          prescriptionId: 'RX-ERROR',
          sourceFile: sourceFile,
        ),
      ];
    }
  }

  /// Extrae información detallada de un bloque de texto que contiene información de medicamento
  Future<MedicationBlock?> _extractMedicationBlock(List<String> lines, int startIndex) async {
    try {
      var medName = '';
      var doseMg = 0;
      var frequencyHours = 24;
      var durationDays = 30;
      var currentIndex = startIndex;

      // EXTRAE NOMBRE DEL MEDICAMENTO
      final currentLine = lines[startIndex];
      final medLine = currentLine.replaceFirst(RegExp('medicamento:', caseSensitive: false), '').trim();

      if (medLine.isNotEmpty) {
        medName = medLine;
        final doseMatch = RegExp(r'(\d+)\s*mg', caseSensitive: false).firstMatch(medLine);
        if (doseMatch != null) {
          doseMg = int.tryParse(doseMatch.group(1)!) ?? 0;
        }
      } else if (startIndex + 1 < lines.length) {
        currentIndex++;
        medName = lines[currentIndex].trim();
        final doseMatch = RegExp(r'(\d+)\s*mg', caseSensitive: false).firstMatch(medName);
        if (doseMatch != null) {
          doseMg = int.tryParse(doseMatch.group(1)!) ?? 0;
        }
      }

      // Valida que no sea palabra irrelevante
      final irrelevantWords = [
        'cantidad', 'duración', 'dosis', 'instrucciones',
        'fecha', 'paciente', 'diagnóstico', 'médico',
        'registro', 'tableta', 'tabletas'
      ];

      if (irrelevantWords.contains(medName.toLowerCase().split(':').first.trim())) {
        return null;
      }

      // BUSCA INFORMACIÓN ADICIONAL
      final endSearchIndex = (currentIndex + 15).clamp(0, lines.length);
      for (var i = currentIndex + 1; i < endSearchIndex; i++) {
        final line = lines[i].toLowerCase();

        if (line.startsWith('medicamento:')) {
          currentIndex = i - 1;
          break;
        }

        // Busca frecuencia
        final freqMatch = RegExp(r'cada\s+(\d+)\s+hora', caseSensitive: false).firstMatch(line);
        if (freqMatch != null) {
          frequencyHours = int.tryParse(freqMatch.group(1)!) ?? 24;
        }

        // Busca duración
        if (line.contains('duración:')) {
          final durMatch = RegExp(r'(\d+)\s*día', caseSensitive: false).firstMatch(line);
          if (durMatch != null) {
            durationDays = int.tryParse(durMatch.group(1)!) ?? 30;
          }
        }

        // Busca cantidad para calcular duración
        if (line.contains('cantidad:')) {
          final qtyMatch = RegExp(r'(\d+)\s*tableta', caseSensitive: false).firstMatch(line);
          if (qtyMatch != null && durationDays == 30) {
            final quantity = int.tryParse(qtyMatch.group(1)!) ?? 30;
            final dosesPerDay = 24 ~/ frequencyHours;
            durationDays = dosesPerDay > 0 ? quantity ~/ dosesPerDay : 30;
          }
        }

        currentIndex = i;
      }

      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: durationDays));

      return MedicationBlock(
        name: medName,
        doseMg: doseMg,
        frequencyHours: frequencyHours,
        startDate: startDate,
        endDate: endDate,
        lastLineIndex: currentIndex,
      );
    } catch (e) {
      print('❌ Error extrayendo bloque de medicamento: $e');
      return null;
    }
  }

  /// Extrae información de medicamento en formato alternativo
  Future<MedicationInfo> _extractMedicationFromAlternateFormat(
    List<String> lines,
    int startIndex,
    String medName,
    int doseMg,
    String prescriptionId,
    String sourceFile,
  ) async {
    var frequencyHours = 24;
    var durationDays = 30;

    // Busca en las siguientes líneas
    final endIndex = (startIndex + 10).clamp(0, lines.length);
    for (var i = startIndex + 1; i < endIndex; i++) {
      final line = lines[i].toLowerCase();

      // Busca frecuencia
      final freqMatch = RegExp(r'cada\s+(\d+)\s+hora', caseSensitive: false).firstMatch(line);
      if (freqMatch != null) {
        frequencyHours = int.tryParse(freqMatch.group(1)!) ?? 24;
      }

      // Busca duración
      if (line.contains('duración')) {
        final durMatch = RegExp(r'(\d+)\s*día', caseSensitive: false).firstMatch(line);
        if (durMatch != null) {
          durationDays = int.tryParse(durMatch.group(1)!) ?? 30;
        }
      }

      // Busca cantidad para calcular duración
      if (line.contains('cantidad:')) {
        final qtyMatch = RegExp(r'(\d+)\s*tableta', caseSensitive: false).firstMatch(line);
        if (qtyMatch != null && durationDays == 30) {
          final quantity = int.tryParse(qtyMatch.group(1)!) ?? 30;
          final dosesPerDay = 24 ~/ frequencyHours;
          durationDays = dosesPerDay > 0 ? quantity ~/ dosesPerDay : 30;
        }
      }
    }

    final startDate = DateTime.now();
    final endDate = startDate.add(Duration(days: durationDays));

    return MedicationInfo(
      medicationId: 'med_${DateTime.now().millisecondsSinceEpoch}_${(1000 + startIndex) % 9999}',
      name: '$medName ${doseMg}mg',
      medicationRef: '/medicamentosGlobales/med_${medName.hashCode.toString().replaceAll('-', '')}',
      doseMg: doseMg,
      frequencyHours: frequencyHours,
      startDate: startDate,
      endDate: endDate,
      active: true,
      prescriptionId: prescriptionId,
      sourceFile: sourceFile,
    );
  }

  MedicationInfo _createDefaultMedication({
    required String name,
    String prescriptionId = '',
    String sourceFile = '',
  }) {
    final startDate = DateTime.now();
    final endDate = startDate.add(const Duration(days: 30));

    return MedicationInfo(
      medicationId: 'med_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000).toString()}',
      name: name,
      medicationRef: '/medicamentosGlobales/med_${name.hashCode.toString().replaceAll('-', '')}',
      doseMg: 0,
      frequencyHours: 24,
      startDate: startDate,
      endDate: endDate,
      active: true,
      prescriptionId: prescriptionId,
      sourceFile: sourceFile,
    );
  }
}

class MedicationBlock {
  final String name;
  final int doseMg;
  final int frequencyHours;
  final DateTime startDate;
  final DateTime endDate;
  final int lastLineIndex;

  MedicationBlock({
    required this.name,
    required this.doseMg,
    required this.frequencyHours,
    required this.startDate,
    required this.endDate,
    required this.lastLineIndex,
  });

  MedicationInfo toMedicationInfo({
    required String prescriptionId,
    required String sourceFile,
  }) {
    return MedicationInfo(
      medicationId: 'med_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000).toString()}',
      name: name,
      medicationRef: '/medicamentosGlobales/med_${name.hashCode.toString().replaceAll('-', '')}',
      doseMg: doseMg,
      frequencyHours: frequencyHours,
      startDate: startDate,
      endDate: endDate,
      active: true,
      prescriptionId: prescriptionId,
      sourceFile: sourceFile,
    );
  }
}

class PdfProcessingResult {
  final List<MedicationInfo> medications;
  final String extractedText;

  PdfProcessingResult({
    required this.medications,
    required this.extractedText,
  });
}