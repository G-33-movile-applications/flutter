import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

/// Background Processing Service for heavy operations
/// 
/// Uses Dart isolates to offload CPU-intensive tasks:
/// - OCR text recognition (Google ML Kit)
/// - NFC data parsing
/// - Image processing
/// - Data transformation
/// 
/// Benefits:
/// - Keeps UI thread responsive
/// - Prevents janky animations during processing
/// - Better battery efficiency
/// - Proper error handling with main thread communication
/// 
/// Communication:
/// - Main Thread → Isolate: via SendPort
/// - Isolate → Main Thread: via ReceivePort
/// - Type-safe message passing with sealed result classes
class BackgroundProcessor {
  // Singleton pattern
  static final BackgroundProcessor _instance = BackgroundProcessor._internal();
  factory BackgroundProcessor() => _instance;
  BackgroundProcessor._internal();

  /// Process OCR in background isolate using compute()
  /// 
  /// compute() is Flutter's high-level API for isolates:
  /// - Automatically manages isolate lifecycle
  /// - Handles message passing internally
  /// - Returns Future with result
  /// 
  /// [imagePath] - Path to image file for OCR
  /// Returns: Extracted text or error message
  static Future<OCRResult> processOCRInBackground(String imagePath) async {
    try {
      debugPrint('🔬 Starting OCR processing in background isolate...');
      debugPrint('   Image path: $imagePath');
      
      // Use compute() to run OCR in isolate
      // compute() automatically serializes input/output
      final result = await compute(_performOCR, imagePath);
      
      debugPrint('✅ OCR processing completed successfully');
      return result;
    } catch (e) {
      debugPrint('❌ OCR processing failed: $e');
      return OCRResult.error('Failed to process image: $e');
    }
  }

  /// OCR processing function (runs in isolate)
  /// 
  /// This function must be:
  /// - Static or top-level (no access to instance members)
  /// - Serializable input/output only
  /// 
  /// Google ML Kit Text Recognition:
  /// - Detects text in images
  /// - Supports multiple languages
  /// - Returns structured text blocks
  static Future<OCRResult> _performOCR(String imagePath) async {
    try {
      // Verify file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        return OCRResult.error('Image file not found');
      }

      // Initialize ML Kit text recognizer
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();

      try {
        // Perform text recognition
        final RecognizedText recognizedText = 
            await textRecognizer.processImage(inputImage);

        // Extract all text
        final StringBuffer textBuffer = StringBuffer();
        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            textBuffer.writeln(line.text);
          }
        }

        final extractedText = textBuffer.toString().trim();

        if (extractedText.isEmpty) {
          return OCRResult.error('No text found in image');
        }

        // Parse prescription data from text
        final parsedData = _parsePrescriptionText(extractedText);

        return OCRResult.success(
          extractedText: extractedText,
          parsedData: parsedData,
        );
      } finally {
        // Clean up resources
        await textRecognizer.close();
      }
    } catch (e) {
      return OCRResult.error('OCR processing error: $e');
    }
  }

  /// Parse prescription text to extract structured data
  /// 
  /// Looks for common patterns in prescriptions:
  /// - Medication names
  /// - Dosage information
  /// - Doctor information
  /// - Date information
  /// 
  /// Note: This is a simplified parser. Production code should use
  /// more sophisticated NLP or trained models
  static Map<String, dynamic> _parsePrescriptionText(String text) {
    final Map<String, dynamic> parsed = {};

    // Convert to lowercase for pattern matching
    final lowerText = text.toLowerCase();

    // Extract date patterns (dd/mm/yyyy or dd-mm-yyyy)
    final datePattern = RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}');
    final dateMatches = datePattern.allMatches(text);
    if (dateMatches.isNotEmpty) {
      parsed['dates'] = dateMatches.map((m) => m.group(0)).toList();
    }

    // Extract medication-related keywords
    final medicationKeywords = [
      'mg', 'ml', 'comprimido', 'tableta', 'capsula',
      'jarabe', 'suspension', 'cada', 'horas', 'dias'
    ];
    
    final foundKeywords = <String>[];
    for (final keyword in medicationKeywords) {
      if (lowerText.contains(keyword)) {
        foundKeywords.add(keyword);
      }
    }
    
    if (foundKeywords.isNotEmpty) {
      parsed['medicationKeywords'] = foundKeywords;
    }

    // Extract numbers (potential dosages)
    final numberPattern = RegExp(r'\d+\.?\d*');
    final numbers = numberPattern.allMatches(text)
        .map((m) => m.group(0))
        .toList();
    if (numbers.isNotEmpty) {
      parsed['numbers'] = numbers;
    }

    // Line count (complexity indicator)
    parsed['lineCount'] = text.split('\n').length;

    return parsed;
  }

  /// Process NFC data in background isolate using Isolate.spawn()
  /// 
  /// Isolate.spawn() is lower-level than compute():
  /// - More control over isolate lifecycle
  /// - Manual message passing with SendPort/ReceivePort
  /// - Better for long-running isolates
  /// 
  /// [nfcData] - Raw NFC data to parse
  /// Returns: Parsed prescription data or error
  static Future<NFCResult> processNFCInBackground(
    Map<String, dynamic> nfcData,
  ) async {
    try {
      debugPrint('🔬 Starting NFC processing in background isolate...');

      // Create a ReceivePort to get messages from isolate
      final receivePort = ReceivePort();

      // Spawn isolate with entry point function
      await Isolate.spawn(
        _nfcProcessingIsolate,
        _NFCIsolateMessage(
          sendPort: receivePort.sendPort,
          nfcData: nfcData,
        ),
      );

      // Wait for result from isolate
      final result = await receivePort.first as NFCResult;
      
      debugPrint('✅ NFC processing completed successfully');
      return result;
    } catch (e) {
      debugPrint('❌ NFC processing failed: $e');
      return NFCResult.error('Failed to process NFC data: $e');
    }
  }

  /// NFC processing isolate entry point
  /// 
  /// This function runs in a separate isolate:
  /// - Receives data via message parameter
  /// - Sends result back via SendPort
  /// - Must be top-level or static
  static void _nfcProcessingIsolate(_NFCIsolateMessage message) {
    try {
      // Parse NFC data
      final nfcData = message.nfcData;
      
      // Extract prescription information from NFC payload
      // This is a simplified parser - actual NFC data structure depends on your format
      final Map<String, dynamic> parsed = {};

      if (nfcData.containsKey('text')) {
        parsed['text'] = nfcData['text'];
      }

      if (nfcData.containsKey('id')) {
        parsed['prescriptionId'] = nfcData['id'];
      }

      if (nfcData.containsKey('payload')) {
        // Parse custom payload format
        final payload = nfcData['payload'] as String;
        final parts = payload.split('|');
        
        if (parts.length >= 3) {
          parsed['medicationName'] = parts[0];
          parsed['dosage'] = parts[1];
          parsed['frequency'] = parts[2];
        }
      }

      // Send result back to main isolate
      message.sendPort.send(NFCResult.success(parsedData: parsed));
    } catch (e) {
      // Send error back to main isolate
      message.sendPort.send(NFCResult.error('NFC parsing error: $e'));
    }
  }

  /// Process multiple images in batch (parallel isolates)
  /// 
  /// Processes multiple prescription images concurrently
  /// Uses multiple isolates for maximum parallelism
  static Future<List<OCRResult>> processMultipleImagesInBackground(
    List<String> imagePaths,
  ) async {
    try {
      debugPrint('🔬 Processing ${imagePaths.length} images in parallel...');

      // Process all images concurrently using compute()
      final futures = imagePaths
          .map((path) => processOCRInBackground(path))
          .toList();

      final results = await Future.wait(futures);

      final successCount = results.where((r) => r.isSuccess).length;
      debugPrint('✅ Processed ${imagePaths.length} images: $successCount succeeded');

      return results;
    } catch (e) {
      debugPrint('❌ Batch image processing failed: $e');
      return [];
    }
  }

  /// Heavy data transformation in background
  /// 
  /// Example: Convert large prescription dataset
  /// Useful for batch operations
  static Future<T> transformDataInBackground<T>(
    T Function() transformation,
  ) async {
    try {
      return await compute(_runTransformation, transformation);
    } catch (e) {
      debugPrint('❌ Data transformation failed: $e');
      rethrow;
    }
  }

  static T _runTransformation<T>(T Function() transformation) {
    return transformation();
  }
}

// ==================== RESULT CLASSES ====================

/// OCR processing result
class OCRResult {
  final bool isSuccess;
  final String? extractedText;
  final Map<String, dynamic>? parsedData;
  final String? errorMessage;

  OCRResult._({
    required this.isSuccess,
    this.extractedText,
    this.parsedData,
    this.errorMessage,
  });

  factory OCRResult.success({
    required String extractedText,
    required Map<String, dynamic> parsedData,
  }) {
    return OCRResult._(
      isSuccess: true,
      extractedText: extractedText,
      parsedData: parsedData,
    );
  }

  factory OCRResult.error(String message) {
    return OCRResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// NFC processing result
class NFCResult {
  final bool isSuccess;
  final Map<String, dynamic>? parsedData;
  final String? errorMessage;

  NFCResult._({
    required this.isSuccess,
    this.parsedData,
    this.errorMessage,
  });

  factory NFCResult.success({
    required Map<String, dynamic> parsedData,
  }) {
    return NFCResult._(
      isSuccess: true,
      parsedData: parsedData,
    );
  }

  factory NFCResult.error(String message) {
    return NFCResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Message class for NFC isolate communication
class _NFCIsolateMessage {
  final SendPort sendPort;
  final Map<String, dynamic> nfcData;

  _NFCIsolateMessage({
    required this.sendPort,
    required this.nfcData,
  });
}
