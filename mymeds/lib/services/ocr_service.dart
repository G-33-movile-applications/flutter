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
  /// Uses higher resolution and quality for better OCR accuracy
  Future<File?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2400,  // Increased resolution for better text recognition
        maxHeight: 2400,
        imageQuality: 95, // Higher quality for clearer text
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (photo == null) {
        debugPrint('User cancelled photo capture');
        return null;
      }
      
      debugPrint('Photo captured: ${photo.path}, size: ${await File(photo.path).length()} bytes');
      return File(photo.path);
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      rethrow;
    }
  }

  /// Pick an image from gallery
  /// Uses higher resolution for better OCR
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,  // Increased resolution
        maxHeight: 2400,
        imageQuality: 95, // Higher quality
      );
      
      if (image == null) {
        debugPrint('User cancelled image selection');
        return null;
      }
      
      debugPrint('Image selected: ${image.path}, size: ${await File(image.path).length()} bytes');
      return File(image.path);
    } catch (e) {
      debugPrint('Error picking image: $e');
      rethrow;
    }
  }

  /// Extract text from an image file using ML Kit
  /// Returns structured text with confidence filtering
  Future<String> extractTextFromFile(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
      
      final buffer = StringBuffer();
      int blockCount = 0;
      int lineCount = 0;
      int lowConfidenceCount = 0;
      
      for (final block in recognizedText.blocks) {
        blockCount++;
        for (final line in block.lines) {
          lineCount++;
          
          // Note: ML Kit doesn't always expose confidence scores
          // We filter by text quality instead (length, special characters, etc.)
          
          // Filter out very short lines that are likely noise
          if (line.text.trim().length < 2) {
            lowConfidenceCount++;
            continue;
          }
          
          // Add line with proper spacing
          buffer.writeln(line.text.trim());
        }
        // Add spacing between blocks for better parsing
        buffer.writeln();
      }
      
      final extractedText = buffer.toString().trim();
      debugPrint('OCR Statistics: $blockCount blocks, $lineCount lines, $lowConfidenceCount filtered');
      debugPrint('Extracted text length: ${extractedText.length} chars');
      
      if (extractedText.isEmpty) {
        debugPrint('WARNING: No text extracted from image');
      }
      
      return extractedText;
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      rethrow;
    }
  }

  /// Parse extracted text into prescription fields
  /// Returns a Map with detected fields that can be mapped to Prescripcion model
  /// IMPROVED: Better pattern matching for real prescriptions
  Future<Map<String, dynamic>> parsePrescriptionText(String rawText) async {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final Map<String, dynamic> parsed = {};
    final List<Map<String, dynamic>> medicamentos = [];
    
    debugPrint('🔍 Parsing ${lines.length} lines of prescription text');

    // Multi-pass parsing for better accuracy
    
    // Pass 1: Look for explicit labels (most reliable)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowered = line.toLowerCase();

      // Doctor name (multiple patterns)
      if (!parsed.containsKey('doctor') && 
          (lowered.contains('doctor') || lowered.contains('médico') || 
           lowered.contains('dr.') || lowered.contains('dra.'))) {
        String? value = _extractValueAfterColon(line);
        if (value == null || value.isEmpty) {
          value = _cleanDoctorName(line);
        }
        if (value == null || value.isEmpty) {
          value = _extractNextLine(lines, i);
        }
        if (value != null && value.isNotEmpty && value.length > 3) {
          parsed['doctor'] = value;
          debugPrint('✅ Found doctor: $value');
        }
      }
      
      // Diagnosis (multiple patterns)
      if (!parsed.containsKey('diagnosis') &&
          (lowered.contains('diagnóstico') || lowered.contains('diagnostico') || 
           lowered.contains('diagnosis') || lowered.contains('padecimiento'))) {
        String? value = _extractValueAfterColon(line);
        if (value == null || value.isEmpty) {
          value = _extractNextLine(lines, i);
        }
        if (value != null && value.isNotEmpty && value.length > 3) {
          parsed['diagnosis'] = value;
          debugPrint('✅ Found diagnosis: $value');
        }
      }
      
      // Date patterns
      if (!parsed.containsKey('date') && _containsDate(line)) {
        final dateStr = _extractDate(line);
        if (dateStr != null) {
          parsed['date'] = _parseDateString(dateStr);
          debugPrint('✅ Found date: $dateStr');
        }
      }
    }

    // Pass 2: Look for medications (more complex)
    int medicationCount = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (_isMedicationLine(line)) {
        final medication = _parseMedicationLine(line, lines, i);
        if (medication != null && medication['name'] != null) {
          medicamentos.add(medication);
          medicationCount++;
          debugPrint('✅ Found medication $medicationCount: ${medication['name']}');
        }
      }
    }

    // Pass 3: Heuristic fallbacks if nothing found
    if (!parsed.containsKey('doctor')) {
      // Look for lines that look like names (capitalized words)
      for (final line in lines) {
        if (_looksLikeDoctorName(line)) {
          parsed['doctor'] = line;
          debugPrint('⚠️ Guessed doctor (heuristic): $line');
          break;
        }
      }
    }

    // Build final result
    final result = {
      'doctor': parsed['doctor'] ?? 'No detectado - Por favor ingresa manualmente',
      'diagnosis': parsed['diagnosis'] ?? 'No detectado - Por favor ingresa manualmente',
      'date': parsed['date'],
      'medications': medicamentos,
      'activa': true,
      '_confidence': _calculateConfidence(parsed, medicamentos),
      '_rawText': rawText, // Keep original for reference
    };

    debugPrint('📊 Parse confidence: ${result['_confidence']}%');
    debugPrint('📦 Final parsed data: ${result.keys.join(', ')}');
    
    return result;
  }

  /// Calculate parsing confidence score (0-100)
  int _calculateConfidence(Map<String, dynamic> parsed, List<Map<String, dynamic>> meds) {
    int score = 0;
    
    if (parsed.containsKey('doctor') && parsed['doctor'] != 'No detectado') score += 30;
    if (parsed.containsKey('diagnosis') && parsed['diagnosis'] != 'No detectado') score += 30;
    if (parsed.containsKey('date')) score += 20;
    if (meds.isNotEmpty) score += 20;
    
    return score;
  }

  /// Check if a line looks like a doctor's name
  bool _looksLikeDoctorName(String line) {
    // Must be 2-4 words, mostly capitalized, no numbers
    if (line.contains(RegExp(r'\d'))) return false;
    
    final words = line.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 4) return false;
    
    // Check if most words start with capital letter
    int capitalCount = words.where((w) => w[0] == w[0].toUpperCase()).length;
    return capitalCount >= words.length - 1;
  }

  /// Parse date string to DateTime
  DateTime? _parseDateString(String dateStr) {
    try {
      // Try DD/MM/YYYY
      final parts = dateStr.split(RegExp(r'[/-]'));
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint('Failed to parse date: $dateStr');
    }
    return null;
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
  /// IMPROVED: Better pattern matching for real prescriptions
  bool _isMedicationLine(String line) {
    final lowered = line.toLowerCase();
    
    // Skip if it's a header or label
    if (lowered.startsWith('medicamento') || 
        lowered.startsWith('prescripción') ||
        lowered.startsWith('indicaciones')) {
      return false;
    }
    
    // Strong indicators (dosage with units)
    if (RegExp(r'\d+\s*(mg|ml|g|mcg|gr|cc)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    
    // Common medication forms
    if (lowered.contains('comprimido') || lowered.contains('cápsula') ||
        lowered.contains('tableta') || lowered.contains('jarabe') ||
        lowered.contains('gotas') || lowered.contains('ampolla')) {
      return true;
    }
    
    // Frequency patterns
    if (RegExp(r'cada\s+\d+\s+(hora|horas)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    
    // "Take X times per day" patterns
    if (RegExp(r'\d+\s*(veces?|tomas?)\s+(al|por)\s+día', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    
    return false;
  }

  /// Parse a medication line into structured data
  /// IMPROVED: Better extraction of name, dosage, frequency, duration
  Map<String, dynamic>? _parseMedicationLine(String line, List<String> allLines, int index) {
    Map<String, dynamic> medication = {};
    
    debugPrint('  🔍 Parsing medication line: $line');
    
    // Extract dosage (mg, ml, etc.)
    final doseMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mg|ml|g|mcg|gr|cc)',
      caseSensitive: false
    ).firstMatch(line);
    
    if (doseMatch != null) {
      final dosageValue = double.tryParse(doseMatch.group(1)!) ?? 0.0;
      final dosageUnit = doseMatch.group(2)!.toLowerCase();
      
      // Convert to mg for consistency
      double dosageInMg = dosageValue;
      if (dosageUnit == 'g' || dosageUnit == 'gr') {
        dosageInMg = dosageValue * 1000;
      } else if (dosageUnit == 'mcg') {
        dosageInMg = dosageValue / 1000;
      }
      
      medication['dosage'] = dosageInMg;
      
      // Extract name (text before dosage)
      final nameEndIndex = doseMatch.start;
      final name = line.substring(0, nameEndIndex).trim();
      if (name.isNotEmpty) {
        medication['name'] = name;
      }
    } else {
      // No dosage found, use whole line as name
      medication['name'] = line.trim();
      medication['dosage'] = 500.0; // Default dosage
    }
    
    // Extract frequency (every X hours)
    final freqMatch = RegExp(
      r'cada\s+(\d+)\s+(hora|horas)',
      caseSensitive: false
    ).firstMatch(line);
    if (freqMatch != null) {
      medication['frequency'] = int.tryParse(freqMatch.group(1)!) ?? 8;
    } else {
      // Look for "X times per day"
      final timesMatch = RegExp(
        r'(\d+)\s*(veces?|tomas?)\s+(al|por)\s+día',
        caseSensitive: false
      ).firstMatch(line);
      if (timesMatch != null) {
        final times = int.tryParse(timesMatch.group(1)!) ?? 2;
        medication['frequency'] = (24 / times).round(); // Convert to hours
      }
    }
    
    // Extract duration (X days)
    final durationMatch = RegExp(
      r'(\d+)\s+(día|días|dia|dias)',
      caseSensitive: false
    ).firstMatch(line);
    if (durationMatch != null) {
      medication['duration'] = int.tryParse(durationMatch.group(1)!) ?? 7;
    }
    
    // Check next line for additional info (frequency/duration often on next line)
    if (index + 1 < allLines.length) {
      final nextLine = allLines[index + 1];
      final nextLowered = nextLine.toLowerCase();
      
      // Look for frequency on next line
      if (!medication.containsKey('frequency')) {
        final nextFreqMatch = RegExp(
          r'cada\s+(\d+)\s+(hora|horas)',
          caseSensitive: false
        ).firstMatch(nextLine);
        if (nextFreqMatch != null) {
          medication['frequency'] = int.tryParse(nextFreqMatch.group(1)!) ?? 8;
        }
      }
      
      // Look for duration on next line
      if (!medication.containsKey('duration')) {
        final nextDurationMatch = RegExp(
          r'(\d+)\s+(día|días)',
          caseSensitive: false
        ).firstMatch(nextLine);
        if (nextDurationMatch != null) {
          medication['duration'] = int.tryParse(nextDurationMatch.group(1)!) ?? 7;
        }
      }
      
      // Look for notes/instructions
      if (nextLowered.contains('antes') || nextLowered.contains('después') ||
          nextLowered.contains('comida') || nextLowered.contains('ayunas')) {
        medication['notes'] = nextLine.trim();
      }
    }
    
    // Set defaults for missing fields
    medication.putIfAbsent('frequency', () => 8);
    medication.putIfAbsent('duration', () => 7);
    medication.putIfAbsent('notes', () => '');
    
    // Validate: must have at least a name
    if (!medication.containsKey('name') || medication['name'].toString().isEmpty) {
      debugPrint('  ❌ Rejected: No medication name found');
      return null;
    }
    
    debugPrint('  ✅ Parsed: ${medication['name']}, ${medication['dosage']}mg, every ${medication['frequency']}h, for ${medication['duration']} days');
    
    return medication;
  }

  /// Dispose resources
  void dispose() {
    _recognizer.close();
  }
}
