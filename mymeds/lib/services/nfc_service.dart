import 'dart:convert';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:flutter/foundation.dart';

/// Service for reading and writing prescription data to NFC tags
/// Uses NDEF records with custom MIME type for prescription JSON
class NfcService {
  static const String mimeType = 'application/vnd.mymeds.prescription+json';
  static const String prescriptionIdentifier = 'MYMEDS_PRESCRIPTION';

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
            
            // Verify it's valid JSON
            if (_isValidJson(payload)) {
              // Check if it's a prescription (contains our identifier or expected fields)
              final jsonData = jsonDecode(payload) as Map<String, dynamic>;
              if (jsonData.containsKey('_type') && 
                  jsonData['_type'] == prescriptionIdentifier) {
                debugPrint('Found prescription data with identifier on NFC tag');
                return payload;
              }
              // Also accept if it has prescription-like fields
              if (jsonData.containsKey('diagnostico') || 
                  jsonData.containsKey('medico')) {
                debugPrint('Found prescription-like data on NFC tag');
                return payload;
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
  /// Throws exception on write errors
  Future<void> writeNdefJson(String jsonPayload, {bool overwrite = false}) async {
    NFCTag? tag;
    
    try {
      // Validate JSON before writing
      if (!_isValidJson(jsonPayload)) {
        throw ArgumentError('Invalid JSON payload');
      }

      // Add type identifier to the JSON
      final jsonData = jsonDecode(jsonPayload) as Map<String, dynamic>;
      jsonData['_type'] = prescriptionIdentifier;
      final enhancedPayload = jsonEncode(jsonData);

      // Poll for NFC tag - use shorter timeout to avoid conflicts
      tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: 'Multiple tags detected, please keep only one near the device',
        iosAlertMessage: 'Hold your iPhone near the tag to write',
      );

      debugPrint('NFC Tag detected for writing: ${tag.type}');

      // Check if writable
      if (tag.ndefWritable == false) {
        await FlutterNfcKit.finish(iosErrorMessage: 'Tag is not writable');
        throw Exception('NFC tag is not writable');
      }

      // Create NDEF MIME record with custom MIME type for MyMeds prescriptions
      // This ensures Android opens the tag directly in MyMeds app
      final mimeRecord = ndef.MimeRecord(
        decodedType: mimeType,
        payload: utf8.encode(enhancedPayload),
      );

      // Write to tag using MIME record (not text record)
      await FlutterNfcKit.writeNDEFRecords([mimeRecord]);
      
      debugPrint('Prescription written to NFC tag successfully');
      
      // Finish the NFC session immediately to prevent reopen conflicts
      await FlutterNfcKit.finish(iosAlertMessage: 'Prescription written successfully');
    } catch (e) {
      debugPrint('NFC write error: $e');
      // Try to finish session even on error
      try {
        await FlutterNfcKit.finish(iosErrorMessage: 'Failed to write to tag');
      } catch (finishError) {
        debugPrint('Error finishing NFC session: $finishError');
      }
      rethrow;
    }
  }

  /// Delete/format the NFC tag by writing empty NDEF
  Future<void> clearTag() async {
    try {
      // Poll for tag
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosAlertMessage: 'Hold your iPhone near the tag to clear',
      );

      // Write an empty text record to clear the tag
      final emptyRecord = ndef.TextRecord(text: '');
      await FlutterNfcKit.writeNDEFRecords([emptyRecord]);
      
      debugPrint('NFC tag cleared successfully');
      
      // Finish session immediately
      await FlutterNfcKit.finish(iosAlertMessage: 'Tag cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear tag: $e');
      // Try to finish session even on error
      try {
        await FlutterNfcKit.finish(iosErrorMessage: 'Failed to clear tag');
      } catch (finishError) {
        debugPrint('Error finishing NFC session: $finishError');
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
