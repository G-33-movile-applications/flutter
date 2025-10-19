import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Service for extracting prescription data from images using OCR
/// Uses Google ML Kit for on-device text recognition
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _picker = ImagePicker();

  /// Capture a photo using device camera
  Future<File?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (photo == null) {
        debugPrint('User cancelled photo capture');
        return null;
      }
      
      return File(photo.path);
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      rethrow;
    }
  }

  /// Pick an image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image == null) {
        debugPrint('User cancelled image selection');
        return null;
      }
      
      return File(image.path);
    } catch (e) {
      debugPrint('Error picking image: $e');
      rethrow;
    }
  }

  /// Extract text from an image file using ML Kit
  Future<String> extractTextFromFile(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
      
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }
      
      final extractedText = buffer.toString();
      debugPrint('Extracted text: $extractedText');
      
      return extractedText;
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      rethrow;
    }
  }

  /// Parse extracted text into prescription fields
  /// Returns a Map with detected fields that can be mapped to Prescripcion model
  Map<String, dynamic> parsePrescriptionText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final Map<String, dynamic> parsed = {};
    final List<Map<String, String>> medicamentos = [];
    
    debugPrint('Parsing ${lines.length} lines of text');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowered = line.toLowerCase();

      // Patient name
      if ((lowered.contains('paciente') || lowered.contains('patient') || 
           lowered.contains('nombre')) && !parsed.containsKey('paciente')) {
        parsed['paciente'] = _extractValueAfterColon(line) ?? _extractNextLine(lines, i);
      }
      
      // Doctor name
      else if ((lowered.contains('doctor') || lowered.contains('médico') || 
                lowered.contains('dr.') || lowered.contains('dra.')) && 
               !parsed.containsKey('medico')) {
        parsed['medico'] = _extractValueAfterColon(line) ?? 
                          _cleanDoctorName(line) ?? 
                          _extractNextLine(lines, i);
      }
      
      // Diagnosis
      else if ((lowered.contains('diagnóstico') || lowered.contains('diagnostico') || 
                lowered.contains('diagnosis')) && !parsed.containsKey('diagnostico')) {
        parsed['diagnostico'] = _extractValueAfterColon(line) ?? _extractNextLine(lines, i);
      }
      
      // Date patterns
      else if (_containsDate(line) && !parsed.containsKey('fechaCreacion')) {
        final dateStr = _extractDate(line);
        if (dateStr != null) {
          parsed['fechaCreacion'] = dateStr;
        }
      }
      
      // Medication patterns
      else if (_isMedicationLine(line)) {
        final medication = _parseMedicationLine(line, lines, i);
        if (medication != null) {
          medicamentos.add(medication);
        }
      }
      
      // Notes/observations
      else if (lowered.contains('observaciones') || lowered.contains('notas') || 
               lowered.contains('indicaciones')) {
        parsed['observaciones'] = _extractValueAfterColon(line) ?? _extractNextLine(lines, i);
      }
    }

    // If no specific fields found, put all text in notes
    if (parsed.isEmpty) {
      parsed['observaciones'] = rawText;
    }

    // Add medications list
    if (medicamentos.isNotEmpty) {
      parsed['medicamentos'] = medicamentos;
    }

    // Set defaults for required fields if not found
    parsed.putIfAbsent('medico', () => 'No detectado');
    parsed.putIfAbsent('diagnostico', () => 'No detectado');
    parsed.putIfAbsent('activa', () => true);

    debugPrint('Parsed prescription fields: $parsed');
    
    return parsed;
  }

  /// Extract value after colon in a line (e.g., "Doctor: Juan Pérez" -> "Juan Pérez")
  String? _extractValueAfterColon(String line) {
    if (line.contains(':')) {
      final parts = line.split(':');
      if (parts.length > 1) {
        final value = parts.sublist(1).join(':').trim();
        return value.isNotEmpty ? value : null;
      }
    }
    return null;
  }

  /// Get next line if available
  String? _extractNextLine(List<String> lines, int currentIndex) {
    if (currentIndex + 1 < lines.length) {
      return lines[currentIndex + 1].trim();
    }
    return null;
  }

  /// Clean doctor name by removing "Dr." prefix
  String? _cleanDoctorName(String line) {
    final cleaned = line
        .replaceAll(RegExp(r'dr\.?|dra\.?|doctor|doctora', caseSensitive: false), '')
        .replaceAll(':', '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : null;
  }

  /// Check if line contains a date pattern
  bool _containsDate(String line) {
    // Patterns: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, etc.
    return RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').hasMatch(line) ||
           RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b').hasMatch(line);
  }

  /// Extract date from line
  String? _extractDate(String line) {
    final dateMatch = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').firstMatch(line);
    if (dateMatch != null) {
      return dateMatch.group(0);
    }
    
    final isoMatch = RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b').firstMatch(line);
    if (isoMatch != null) {
      return isoMatch.group(0);
    }
    
    return null;
  }

  /// Check if line looks like a medication entry
  bool _isMedicationLine(String line) {
    final lowered = line.toLowerCase();
    
    // Common medication indicators
    if (lowered.contains('mg') || lowered.contains('ml') || 
        lowered.contains('comprimido') || lowered.contains('cápsula') ||
        lowered.contains('tableta') || lowered.contains('jarabe')) {
      return true;
    }
    
    // Dosage patterns
    if (RegExp(r'\d+\s*(mg|ml|g|mcg)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    
    // Frequency indicators
    if (lowered.contains('cada') || lowered.contains('horas') || 
        lowered.contains('diario') || lowered.contains('veces')) {
      return true;
    }
    
    return false;
  }

  /// Parse a medication line into structured data
  Map<String, String>? _parseMedicationLine(String line, List<String> allLines, int index) {
    Map<String, String> medication = {};
    
    // Extract medication name (usually the first part or before dosage)
    final doseMatch = RegExp(r'(\d+)\s*(mg|ml|g|mcg)', caseSensitive: false).firstMatch(line);
    if (doseMatch != null) {
      final nameEndIndex = doseMatch.start;
      medication['nombre'] = line.substring(0, nameEndIndex).trim();
      medication['dosis'] = '${doseMatch.group(1)} ${doseMatch.group(2)}';
    } else {
      // Take the whole line as name if no dosage found
      medication['nombre'] = line.trim();
    }
    
    // Extract frequency
    final freqMatch = RegExp(r'cada\s+(\d+)\s+hora', caseSensitive: false).firstMatch(line);
    if (freqMatch != null) {
      medication['frecuenciaHoras'] = freqMatch.group(1)!;
    }
    
    // Extract duration
    final durationMatch = RegExp(r'(\d+)\s+día', caseSensitive: false).firstMatch(line);
    if (durationMatch != null) {
      medication['duracionDias'] = durationMatch.group(1)!;
    }
    
    // Check next line for additional info
    if (index + 1 < allLines.length) {
      final nextLine = allLines[index + 1].toLowerCase();
      if (nextLine.contains('cada') || nextLine.contains('hora')) {
        final nextFreqMatch = RegExp(r'cada\s+(\d+)\s+hora', caseSensitive: false).firstMatch(nextLine);
        if (nextFreqMatch != null && !medication.containsKey('frecuenciaHoras')) {
          medication['frecuenciaHoras'] = nextFreqMatch.group(1)!;
        }
      }
    }
    
    return medication.isNotEmpty ? medication : null;
  }

  /// Dispose resources
  void dispose() {
    _recognizer.close();
  }
}
