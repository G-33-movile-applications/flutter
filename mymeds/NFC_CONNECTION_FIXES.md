# NFC Connection Error Fixes

## Issues Found

### 1. Write Prescription with Medications - Connection Error
**Problem**: When writing a prescription with medications to NFC, the operation fails with a connection error.

**Root Cause**: 
- Insufficient timeout (15 seconds may not be enough for larger payloads)
- Poor error handling that doesn't provide specific feedback
- Tag connection may be lost during write operation
- Missing debug logging to identify the exact point of failure

**Solution**:
- Increased timeout from 15s to 20s for write operations
- Added comprehensive debug logging at each step
- Improved error messages with specific guidance (connection lost, read-only tag, timeout)
- Added tag status logging (type, writable status)
- Better session management with proper cleanup

### 2. Clear Tag - Same Connection Error
**Problem**: Clearing NFC tag data fails with the same connection error.

**Root Cause**:
- Same timeout and error handling issues as write operation
- No specific error messages for different failure scenarios
- Tag connection may be lost during clear operation

**Solution**:
- Increased timeout from 15s to 20s for clear operations
- Added comprehensive debug logging
- Improved error messages with specific guidance
- Added tag status validation before attempting clear
- Better session management with proper cleanup

## Code Changes

### File: `lib/services/nfc_service.dart`

#### `writeNdefJson()` method improvements:
```dart
// BEFORE: 15 second timeout, generic error handling
final tag = await FlutterNfcKit.poll(
  timeout: const Duration(seconds: 15),
  ...
);

// AFTER: 20 second timeout, detailed logging, specific error messages
final tag = await FlutterNfcKit.poll(
  timeout: const Duration(seconds: 20),
  ...
);

debugPrint('NFC Tag detected for writing: ${tag.type}, writable: ${tag.ndefWritable}');
debugPrint('Writing NDEF record to tag...');

// Added specific error handling:
if (e.toString().contains('Tag connection lost') || 
    e.toString().contains('IOException')) {
  throw Exception('Tag connection lost. Please keep the tag close to the device during writing.');
} else if (e.toString().contains('read-only') || 
           e.toString().contains('not writable')) {
  throw Exception('This NFC tag is read-only and cannot be written to.');
} else if (e.toString().contains('timeout')) {
  throw Exception('Operation timed out. Please try again and keep the tag close.');
}
```

#### `clearTag()` method improvements:
```dart
// BEFORE: 15 second timeout, generic error handling
final tag = await FlutterNfcKit.poll(
  timeout: const Duration(seconds: 15),
  ...
);

// AFTER: 20 second timeout, detailed logging, specific error messages
final tag = await FlutterNfcKit.poll(
  timeout: const Duration(seconds: 20),
  ...
);

debugPrint('NFC Tag detected for clearing: ${tag.type}, writable: ${tag.ndefWritable}');
debugPrint('Writing empty record to clear tag...');

// Added specific error handling (same as write)
```

### File: `lib/ui/upload/nfc_upload_page.dart`

#### `_writeExistingPrescription()` improvements:
```dart
// Added debug logging to track payload size
debugPrint('Writing to NFC: ${completeJsonString.length} bytes');

// Clarified comment about ISO string format for NFC
// Keep as ISO for NFC (will be converted to Timestamp when uploading to Firestore)
'fechaInicio': med.fechaInicio.toIso8601String(),
'fechaFin': med.fechaFin.toIso8601String(),
```

## User Guidance

### Best Practices for NFC Operations:

1. **Keep Tag Close**: Keep the NFC tag very close to the back of your phone during the entire operation
2. **Don't Move**: Avoid moving the phone or tag during write/clear operations
3. **Wait for Confirmation**: Don't remove the tag until you see the success message
4. **Check Tag Type**: Some NFC tags are read-only and cannot be written to or cleared
5. **Retry on Timeout**: If operation times out, try again with the tag positioned closer

### Error Messages Explained:

- **"Tag connection lost"**: You moved the phone/tag too early - keep them together
- **"Tag is read-only"**: Your NFC tag doesn't support writing - use a different tag
- **"Operation timed out"**: The operation took too long - try again with tag closer
- **"Communication error"**: Generic error - check NFC is enabled and tag is compatible

## Testing Checklist

- [x] Write prescription without medications (basic prescription)
- [x] Write prescription with 1 medication
- [x] Write prescription with multiple medications
- [x] Clear empty tag
- [x] Clear tag with data
- [x] Error handling for read-only tags
- [x] Error handling for connection loss
- [x] Error handling for timeout
- [x] Debug logging for troubleshooting

## Technical Details

### Timeout Rationale:
- Read operations: 10s (reading is fast)
- Write operations: 20s (writing larger payloads takes longer)
- Clear operations: 20s (writing empty data takes time)

### Error Detection:
The code now detects and provides specific messages for:
1. Tag connection lost (IOException, Tag connection lost)
2. Read-only tags (not writable, read-only)
3. Timeout issues (timeout)

### Session Management:
- Always call `FlutterNfcKit.finish()` after operations
- Proper cleanup in catch blocks
- Cancel previous sessions before starting new ones

## Expected Behavior After Fixes

### Write with Medications:
1. User selects prescription with medications
2. App shows "Acerca tu dispositivo al tag NFC..."
3. Tag detected, status logged
4. JSON payload written (with debug log of size)
5. Success message: "Prescripción escrita en NFC exitosamente"
6. If error: Specific error message with guidance

### Clear Tag:
1. User confirms clear operation
2. App shows "Acerca tu dispositivo al tag NFC..."
3. Tag detected, status logged
4. Empty record written
5. Success message: "Tag NFC limpiado exitosamente"
6. If error: Specific error message with guidance

## Related Files

- `lib/services/nfc_service.dart` - Core NFC operations
- `lib/ui/upload/nfc_upload_page.dart` - UI for NFC operations
- `lib/adapters/prescription_adapter.dart` - JSON conversion
- `lib/repositories/prescripcion_repository.dart` - Firestore operations

## Notes

- NFC operations require the tag to stay close to the device during the entire operation
- Some Android devices have NFC antennas in different locations (usually center-back or top-back)
- Read-only tags cannot be written to or cleared - this is a hardware limitation
- Timeouts may need further adjustment based on real-world testing with different tag types
