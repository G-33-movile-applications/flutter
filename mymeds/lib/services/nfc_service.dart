import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:flutter/foundation.dart';

/// Service for reading and writing prescription data to NFC tags
/// Uses NDEF records with custom MIME type for prescription JSON
/// Includes compression and partial data upload for size-limited tags
class NfcService {
  static const String mimeType = 'application/vnd.mymeds.prescription+json';
  static const String prescriptionIdentifier = 'MYMEDS_PRESCRIPTION';
  static const int maxTagSize = 800; // bytes - safe limit for most NFC tags

  /// Check if NFC is available on this device
  Future<bool> isAvailable() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      return availability == NFCAvailability.available;
    } catch (e) {
      debugPrint('NFC availability check failed: $e');
      return false;
    }
  }

  /// Read NDEF records from an NFC tag and extract prescription JSON
  /// Returns null if no prescription data found
  /// Throws exception on read errors
  Future<String?> readNdefJson() async {
    try {
      // Poll for NFC tag
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: 'Multiple tags detected, please keep only one near the device',
        iosAlertMessage: 'Hold your iPhone near the tag',
      );

      debugPrint('NFC Tag detected: ${tag.type}');

      // Read NDEF records from the tag
      final ndefRecords = await FlutterNfcKit.readNDEFRecords();
      
      // Finish the NFC session
      await FlutterNfcKit.finish(iosAlertMessage: 'Prescription read successfully');

      // Look for our prescription record
      for (final record in ndefRecords) {
        // Check if record has payload
        if (record.payload != null && record.payload!.isNotEmpty) {
          try {
            String payload;
            
            // Check record type to determine how to decode
            final recordTypeBytes = record.type;
            final String recordType = recordTypeBytes != null 
                ? String.fromCharCodes(recordTypeBytes) 
                : '';
            
            debugPrint('NFC Record type: $recordType');
            
            // Handle MIME records (our custom type)
            if (recordTypeBytes != null && recordTypeBytes.isNotEmpty) {
              final typeString = utf8.decode(recordTypeBytes);
              if (typeString == mimeType || typeString.contains('mymeds')) {
                // Direct MIME record payload
                payload = utf8.decode(record.payload!);
                debugPrint('Found MyMeds MIME record');
              }
              // Handle text records (T = 0x54)
              else if (recordType == 'T' || recordTypeBytes[0] == 0x54) {
                // Text record - skip the first byte (status byte) and language code
                if (record.payload!.length > 3) {
                  final statusByte = record.payload![0];
                  final languageCodeLength = statusByte & 0x3F;
                  final payloadStart = 1 + languageCodeLength;
                  if (payloadStart < record.payload!.length) {
                    payload = utf8.decode(record.payload!.sublist(payloadStart));
                  } else {
                    continue;
                  }
                } else {
                  continue;
                }
              }
              // Try as raw UTF-8
              else {
                try {
                  payload = utf8.decode(record.payload!);
                } catch (e) {
                  debugPrint('Failed to decode as UTF-8: $e');
                  continue;
                }
              }
            } else {
              // No type info, try direct UTF-8 decode
              try {
                payload = utf8.decode(record.payload!);
              } catch (e) {
                continue;
              }
            }
            
            // Check if data is compressed
            String decompressedPayload = payload;
            try {
              final jsonTest = jsonDecode(payload) as Map<String, dynamic>;
              if (jsonTest.containsKey('_compressed') && jsonTest['_compressed'] == true) {
                debugPrint('🔄 Detected compressed data, attempting decompression...');
                // Data was compressed, need to decompress
                // The payload is actually the base64 encoded compressed data
                // But in our write, we compressed the bytes directly, so try to decompress
                try {
                  final compressedBytes = Uint8List.fromList(utf8.encode(payload));
                  final decompressedBytes = gzip.decode(compressedBytes);
                  decompressedPayload = utf8.decode(decompressedBytes);
                  debugPrint('✅ Successfully decompressed data');
                } catch (e) {
                  debugPrint('⚠️ Decompression failed, using original payload: $e');
                  // Continue with original payload - it might not actually be compressed
                }
              }
            } catch (e) {
              // Not valid JSON yet, might need decompression first
              debugPrint('Attempting to decompress non-JSON payload...');
              try {
                final compressedBytes = record.payload!;
                final decompressedBytes = gzip.decode(compressedBytes);
                decompressedPayload = utf8.decode(decompressedBytes);
                debugPrint('✅ Successfully decompressed raw payload');
              } catch (decompressError) {
                debugPrint('Decompression not needed or failed: $decompressError');
                // Use original payload
              }
            }
            
            // Verify it's valid JSON
            if (_isValidJson(decompressedPayload)) {
              // Check if it's a prescription (contains our identifier or expected fields)
              final jsonData = jsonDecode(decompressedPayload) as Map<String, dynamic>;
              
              // Fill in missing medication fields with defaults
              if (jsonData.containsKey('medicamentos') && jsonData['medicamentos'] is List) {
                final meds = jsonData['medicamentos'] as List;
                for (var med in meds) {
                  if (med is Map<String, dynamic>) {
                    // Set defaults for missing fields
                    med.putIfAbsent('nombre', () => 'Medicamento sin nombre');
                    med.putIfAbsent('dosis', () => 0);
                    med.putIfAbsent('cantidad', () => 1);
                    med.putIfAbsent('frecuencia', () => 8);
                    med.putIfAbsent('duracion', () => 7);
                    med.putIfAbsent('notas', () => '');
                  }
                }
              }
              
              // Add warning if data was partial
              if (jsonData.containsKey('_partial') && jsonData['_partial'] == true) {
                debugPrint('⚠️ Warning: This is partial prescription data (reduced for NFC tag size)');
              }
              
              if (jsonData.containsKey('_type') && 
                  jsonData['_type'] == prescriptionIdentifier) {
                debugPrint('Found prescription data with identifier on NFC tag');
                return jsonEncode(jsonData); // Return the cleaned/filled data
              }
              // Also accept if it has prescription-like fields
              if (jsonData.containsKey('diagnostico') || 
                  jsonData.containsKey('medico')) {
                debugPrint('Found prescription-like data on NFC tag');
                return jsonEncode(jsonData); // Return the cleaned/filled data
              }
            }
          } catch (e) {
            debugPrint('Failed to decode record payload: $e');
            continue;
          }
        }
      }

      debugPrint('No prescription data found on tag');
      return null;
    } catch (e) {
      debugPrint('NFC read error: $e');
      await FlutterNfcKit.finish(iosErrorMessage: 'Failed to read tag');
      rethrow;
    }
  }

  /// Check if tag contains existing prescription data
  /// Used to prompt user before overwriting
  Future<bool> hasExistingPrescription() async {
    try {
      final jsonData = await readNdefJson();
      return jsonData != null;
    } catch (e) {
      return false;
    }
  }

  /// Write prescription JSON to an NFC tag as NDEF record
  /// Returns a map with write result: {success: bool, warning: String?, medicationsWritten: int}
  /// Throws exception on critical write errors
  Future<Map<String, dynamic>> writeNdefJson(String jsonPayload, {bool overwrite = false}) async {
    NFCTag? tag;
    try {
      // Validate JSON before writing
      if (!_isValidJson(jsonPayload)) {
        throw Exception('JSON inválido: no se puede escribir datos corruptos');
      }

      // Add type identifier to the JSON
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(jsonPayload) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Error al decodificar JSON: $e');
      }
      
      jsonData['_type'] = prescriptionIdentifier;
      
      String enhancedPayload;
      try {
        enhancedPayload = jsonEncode(jsonData);
      } catch (e) {
        throw Exception('Error al codificar JSON: $e');
      }

      Uint8List payloadBytes = Uint8List.fromList(utf8.encode(enhancedPayload));
      var payloadSize = payloadBytes.length;
      String? warning;
      int originalMedicationCount = 0;
      int writtenMedicationCount = 0;

      // Try compression if too large
      if (payloadSize > maxTagSize) {
        debugPrint('⚠️ Payload too large ($payloadSize bytes), attempting compression...');
        
        try {
          payloadBytes = Uint8List.fromList(gzip.encode(payloadBytes));
          payloadSize = payloadBytes.length;
          jsonData['_compressed'] = true;
          debugPrint('✅ Compressed to $payloadSize bytes');
          
          if (payloadSize <= maxTagSize) {
            warning = 'Datos comprimidos para caber en el tag NFC';
          }
        } catch (e) {
          debugPrint('❌ Compression failed: $e');
        }
      }

      // If still too large, reduce medication data
      if (payloadSize > maxTagSize) {
        debugPrint('⚠️ Still too large after compression, reducing medication data...');
        
        // Store original count
        if (jsonData.containsKey('medicamentos') && jsonData['medicamentos'] is List) {
          originalMedicationCount = (jsonData['medicamentos'] as List).length;
        }
        
        // Try to fit essential data only
        final reducedData = _reduceDataForNfc(jsonData);
        enhancedPayload = jsonEncode(reducedData);
        payloadBytes = utf8.encode(enhancedPayload);
        payloadSize = payloadBytes.length;
        
        if (reducedData.containsKey('medicamentos') && reducedData['medicamentos'] is List) {
          writtenMedicationCount = (reducedData['medicamentos'] as List).length;
        }
        
        if (payloadSize > maxTagSize) {
          throw Exception(
            'Tag NFC muy pequeño. Necesitas $payloadSize bytes pero el límite es $maxTagSize bytes.\n\n'
            'Sugerencias:\n'
            '• Usa un tag NFC de mayor capacidad (NTAG216 o superior)\n'
            '• Reduce el número de medicamentos en la prescripción\n'
            '• Divide la prescripción en múltiples tags'
          );
        }
        
        warning = originalMedicationCount > 0
            ? 'Tag NFC pequeño: solo se guardaron $writtenMedicationCount de $originalMedicationCount medicamentos (datos esenciales)'
            : 'Algunos datos fueron reducidos para caber en el tag NFC';
      }

      // Check size limits (most NFC tags support 888 bytes for NTAG216)
      if (payloadSize > maxTagSize) {
        throw Exception('Datos muy grandes ($payloadSize bytes). Máximo: $maxTagSize bytes');
      }

      // Poll for NFC tag with longer timeout
      tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosMultipleTagMessage: 'Multiple tags detected, please keep only one near the device',
        iosAlertMessage: 'Hold your iPhone near the tag to write',
      );

      // Check if writable
      if (tag.ndefWritable == false) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Tag is not writable');
        throw Exception('Tag de solo lectura. Usa un tag NFC escribible');
      }

      // Check tag capacity if available
      if (tag.ndefCapacity != null && tag.ndefCapacity! > 0) {
        if (payloadSize > tag.ndefCapacity!) {
          await FlutterNfcKit.finish(iosErrorMessage: 'Data too large for tag');
          throw Exception('Tag muy pequeño. Necesitas ${payloadSize} bytes pero el tag tiene ${tag.ndefCapacity} bytes');
        }
      }

      // Create NDEF MIME record
      final mimeRecord = ndef.MimeRecord(
        decodedType: mimeType,
        payload: payloadBytes,
      );
      
      // Write to tag with proper error handling
      try {
        await FlutterNfcKit.writeNDEFRecords([mimeRecord]);
      } catch (e) {
        throw Exception('Error al escribir en el tag: ${e.toString()}');
      }
      
      // Finish session with success message
      await FlutterNfcKit.finish(iosAlertMessage: 'Prescription written successfully');
      
      // Return write result
      return {
        'success': true,
        'warning': warning,
        'medicationsWritten': writtenMedicationCount > 0 ? writtenMedicationCount : originalMedicationCount,
        'originalMedicationCount': originalMedicationCount,
      };
      
    } catch (e) {
      debugPrint('NFC write error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      // Always try to finish session on error
      try {
        await FlutterNfcKit.finish(iosErrorMessage: 'Failed to write to tag');
      } catch (finishError) {
        debugPrint('Error finishing NFC session after write error: $finishError');
      }
      
      // Provide more specific error messages
      if (e.toString().contains('Tag connection lost') || 
          e.toString().contains('IOException')) {
        throw Exception('Tag connection lost. Please keep the tag close to the device during writing.');
      } else if (e.toString().contains('read-only') || 
                 e.toString().contains('not writable')) {
        throw Exception('This NFC tag is read-only and cannot be written to.');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Operation timed out. Please try again and keep the tag close.');
      }
      
      rethrow;
    }
  }

  /// Reduce prescription data to fit in NFC tag by keeping only essential fields
  Map<String, dynamic> _reduceDataForNfc(Map<String, dynamic> data) {
    final reduced = <String, dynamic>{};
    
    // Keep type identifier
    if (data.containsKey('_type')) {
      reduced['_type'] = data['_type'];
    }
    if (data.containsKey('_compressed')) {
      reduced['_compressed'] = data['_compressed'];
    }
    
    // Keep essential prescription fields
    if (data.containsKey('id')) reduced['id'] = data['id'];
    if (data.containsKey('fechaEmision')) reduced['fechaEmision'] = data['fechaEmision'];
    if (data.containsKey('fechaVencimiento')) reduced['fechaVencimiento'] = data['fechaVencimiento'];
    if (data.containsKey('activa')) reduced['activa'] = data['activa'];
    
    // Reduce medication list to essential fields
    if (data.containsKey('medicamentos') && data['medicamentos'] is List) {
      final medications = data['medicamentos'] as List;
      final reducedMeds = <Map<String, dynamic>>[];
      
      for (var med in medications) {
        if (med is Map<String, dynamic>) {
          // Only keep the most essential fields per medication
          final reducedMed = <String, dynamic>{};
          if (med.containsKey('nombre')) reducedMed['nombre'] = med['nombre'];
          if (med.containsKey('dosis')) reducedMed['dosis'] = med['dosis'];
          if (med.containsKey('cantidad')) reducedMed['cantidad'] = med['cantidad'];
          
          reducedMeds.add(reducedMed);
        }
        
        // Limit to first 10 medications to ensure fit
        if (reducedMeds.length >= 10) {
          break;
        }
      }
      
      reduced['medicamentos'] = reducedMeds;
      reduced['_partial'] = true; // Mark as partial data
    }
    
    return reduced;
  }
  /// Delete/format the NFC tag by writing empty NDEF
  Future<void> clearTag() async {
    NFCTag? tag;
    try {
      // Poll for tag with longer timeout
      tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Hold your iPhone near the tag to clear',
      );

      // Check if writable
      if (tag.ndefWritable == false) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Tag is not writable');
        throw Exception('Tag de solo lectura. No se puede limpiar');
      }

      // Write an empty text record to clear the tag
      final emptyRecord = ndef.TextRecord(text: '');
      
      try {
        await FlutterNfcKit.writeNDEFRecords([emptyRecord]);
      } catch (e) {
        throw Exception('Error al limpiar el tag: ${e.toString()}');
      }
      
      // Finish session with success message
      await FlutterNfcKit.finish(iosAlertMessage: 'Tag cleared successfully');
      
    } catch (e) {
      // Always try to finish session on error
      try {
        await FlutterNfcKit.finish(iosErrorMessage: 'Failed to clear tag');
      } catch (finishError) {
        debugPrint('Error finishing NFC session after clear error: $finishError');
      }
      
      // Provide more specific error messages
      if (e.toString().contains('connection') || e.toString().contains('IOException')) {
        throw Exception('Conexión perdida. Mantén el tag cerca durante toda la operación');
      } else if (e.toString().contains('read-only') || e.toString().contains('not writable')) {
        throw Exception('Tag de solo lectura. Usa un tag NFC escribible');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Tiempo agotado. Intenta de nuevo manteniendo el tag más cerca');
      }
      
      rethrow;
    }
  }

  /// Helper to validate JSON string
  bool _isValidJson(String str) {
    try {
      jsonDecode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel any ongoing NFC session
  Future<void> cancelSession() async {
    try {
      await FlutterNfcKit.finish();
    } catch (e) {
      debugPrint('Failed to cancel NFC session: $e');
    }
  }
}
