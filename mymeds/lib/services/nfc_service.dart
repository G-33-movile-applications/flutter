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
            // Try to decode the payload as UTF-8 text
            String payload;
            
            // Check record type - if it's a text record, skip language code
            if (record.type != null && 
                String.fromCharCodes(record.type!) == 'T') {
              // Text record - skip the first 3 bytes (language code)
              if (record.payload!.length > 3) {
                payload = utf8.decode(record.payload!.sublist(3));
              } else {
                continue;
              }
            } else {
              // Try to decode as regular UTF-8
              payload = utf8.decode(record.payload!);
            }
            
            // Verify it's valid JSON
            if (_isValidJson(payload)) {
              // Check if it's a prescription (contains our identifier or expected fields)
              final jsonData = jsonDecode(payload) as Map<String, dynamic>;
              if (jsonData.containsKey('_type') && 
                  jsonData['_type'] == prescriptionIdentifier) {
                debugPrint('Found prescription data on NFC tag');
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
    try {
      // Validate JSON before writing
      if (!_isValidJson(jsonPayload)) {
        throw ArgumentError('Invalid JSON payload');
      }

      // Add type identifier to the JSON
      final jsonData = jsonDecode(jsonPayload) as Map<String, dynamic>;
      jsonData['_type'] = prescriptionIdentifier;
      final enhancedPayload = jsonEncode(jsonData);

      // Poll for NFC tag
      final tag = await FlutterNfcKit.poll(
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

      // Create NDEF text record with JSON data
      final textRecord = ndef.TextRecord(
        text: enhancedPayload,
        encoding: ndef.TextEncoding.UTF8,
        language: 'en',
      );

      // Write to tag using ndef.NDEFRecord
      await FlutterNfcKit.writeNDEFRecords([textRecord]);
      
      debugPrint('Prescription written to NFC tag successfully');
      
      // Finish the NFC session
      await FlutterNfcKit.finish(iosAlertMessage: 'Prescription written successfully');
    } catch (e) {
      debugPrint('NFC write error: $e');
      await FlutterNfcKit.finish(iosErrorMessage: 'Failed to write to tag');
      rethrow;
    }
  }

  /// Delete/format the NFC tag by writing empty NDEF
  Future<void> clearTag() async {
    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
      );

      final emptyRecord = ndef.TextRecord(text: '');
      await FlutterNfcKit.writeNDEFRecords([emptyRecord]);
      
      await FlutterNfcKit.finish(iosAlertMessage: 'Tag cleared');
    } catch (e) {
      debugPrint('Failed to clear tag: $e');
      await FlutterNfcKit.finish(iosErrorMessage: 'Failed to clear tag');
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
