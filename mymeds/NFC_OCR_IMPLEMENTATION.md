# NFC and OCR Prescription Upload Features

## Overview

This implementation adds two new methods for uploading medical prescriptions to the MyMeds app:

1. **NFC (Near Field Communication)** - Read from and write prescriptions to NFC tags
2. **OCR (Optical Character Recognition)** - Extract prescription data from images using ML Kit

Both features integrate seamlessly with the existing PDF upload functionality and use the same `Prescripcion` model and `PrescriptionFacade` for data persistence.

---

## Features

### 📱 NFC Support

#### Read NFC Tags
- Scan NFC tags containing prescription data
- Parse NDEF records with custom MIME type `application/vnd.mymeds.prescription+json`
- Validate and preview prescription data before upload
- Error handling for empty or invalid tags

#### Write NFC Tags
- Write mock prescriptions to NFC tags for testing
- Select existing prescriptions to write (TODO: implement selection UI)
- Confirm before overwriting existing tag data
- Secure JSON format with type identifier

#### Features
- ✅ Device NFC availability detection
- ✅ iOS and Android support
- ✅ Clear user prompts and error messages
- ✅ Progress indicators during NFC operations
- ✅ Graceful degradation on devices without NFC

### 📷 OCR Support

#### Image Capture
- Take photos directly with the camera
- Select images from the photo gallery
- On-device text recognition using Google ML Kit
- No cloud processing required (privacy-friendly)

#### Text Extraction
- Automatic detection of prescription fields:
  - Patient name
  - Doctor name
  - Diagnosis
  - Medications with dosage
  - Prescription date
  - Observations/notes
  
#### Smart Parsing
- Heuristic-based field extraction
- Date format recognition (DD/MM/YYYY, YYYY-MM-DD)
- Medication pattern detection (mg, ml, dosage instructions)
- Frequency and duration extraction

#### Validation
- Identifies missing required fields
- Shows warnings for incomplete data
- Editable form for manual corrections
- Prevents upload of invalid prescriptions

---

## Architecture

### Services Layer

#### `NfcService` (`lib/services/nfc_service.dart`)
- **Purpose**: Handle NFC tag read/write operations
- **Dependencies**: `flutter_nfc_kit`
- **Key Methods**:
  - `isAvailable()` - Check NFC support
  - `readNdefJson()` - Read prescription JSON from tag
  - `writeNdefJson()` - Write prescription JSON to tag
  - `hasExistingPrescription()` - Check if tag contains data
  - `clearTag()` - Erase tag contents
  - `cancelSession()` - Cancel ongoing NFC operation

#### `OcrService` (`lib/services/ocr_service.dart`)
- **Purpose**: Extract text from images and parse prescription data
- **Dependencies**: `google_mlkit_text_recognition`, `image_picker`
- **Key Methods**:
  - `capturePhoto()` - Take photo with camera
  - `pickImageFromGallery()` - Select image from gallery
  - `extractTextFromFile()` - Run OCR on image
  - `parsePrescriptionText()` - Parse extracted text into structured data

### Adapter Layer

#### `PrescriptionAdapter` (`lib/adapters/prescription_adapter.dart`)
- **Purpose**: Convert between `Prescripcion` model and NFC/OCR formats
- **Key Methods**:
  - `toNdefJson()` - Convert Prescripcion to NFC JSON
  - `fromNdefJson()` - Parse NFC JSON to Prescripcion
  - `fromOcrData()` - Create Prescripcion from OCR parsed data
  - `validate()` - Validate prescription data
  - `validateOcrData()` - Check OCR data completeness
  - `getMissingFields()` - List missing required fields
  - `createMockPrescription()` - Generate test prescription
  - `formatForDisplay()` - Format prescription for preview

### UI Layer

#### Updated `UploadPrescriptionPage` (`lib/ui/upload/upload_prescription.dart`)
- **Preserved**: Existing PDF upload functionality
- **Added**: NFC and OCR upload sections
- **Features**:
  - Three distinct card sections (PDF, NFC, Image/OCR)
  - Disabled buttons when operations in progress
  - Warning message when NFC unavailable
  - Consistent Material Design styling
  - Integrated with driving mode detection

---

## User Flows

### NFC Read Flow

```
1. User taps "Leer Tag" button
2. App checks NFC availability
   ├─ If unavailable: Show error message
   └─ If available: Continue
3. System shows "Acerca el tag NFC" prompt
4. User brings device near NFC tag
5. App reads NDEF records
6. App parses prescription JSON
7. App shows preview dialog with prescription details
8. User reviews and confirms
9. App uploads prescription to Firestore
10. Success message displayed
```

### NFC Write Flow

```
1. User taps "Escribir Tag" button
2. App shows dialog: "¿Usar prescripción de prueba?"
   ├─ User selects "Prueba": Use mock prescription
   └─ User selects "Existente": Select from user's prescriptions
3. App checks if tag already has data
   ├─ If has data: Ask "¿Deseas sobrescribirla?"
   │   ├─ User confirms: Continue
   │   └─ User cancels: Abort
   └─ If empty: Continue
4. System shows "Acerca el tag NFC" prompt
5. User brings device near NFC tag
6. App writes prescription JSON to tag
7. Success message displayed
```

### OCR Capture Flow

```
1. User taps "Tomar Foto" or "Galería"
2. Camera opens or gallery appears
3. User captures/selects image
4. App shows "Extrayendo texto..." progress
5. ML Kit processes image and extracts text
6. App parses text into prescription fields
7. App checks for missing fields
   ├─ If incomplete: Show warning with missing fields
   └─ If complete: Continue
8. App shows edit form with:
   - Preview of original image
   - Detected field values
   - Editable text fields
9. User reviews and edits fields
10. User taps "Subir"
11. App validates required fields
12. App uploads prescription to Firestore
13. Success message displayed
```

---

## Data Formats

### NFC JSON Format

```json
{
  "id": "pres_1729360823456_abc123",
  "fechaCreacion": "2024-10-19T14:30:00.000Z",
  "diagnostico": "Hipertensión arterial",
  "medico": "Dr. Juan Pérez",
  "activa": true,
  "_type": "MYMEDS_PRESCRIPTION",
  "_version": "1.0",
  "_timestamp": "2024-10-19T14:35:00.000Z"
}
```

**Fields**:
- `_type`: Identifier to distinguish prescription NFC tags
- `_version`: Format version for future compatibility
- `_timestamp`: When the NFC tag was written

### OCR Parsed Data Format

```dart
{
  'medico': 'Dr. María González',
  'diagnostico': 'Diabetes tipo 2',
  'fechaCreacion': '15/03/2024',
  'paciente': 'Juan Pérez',
  'observaciones': 'Tomar antes de las comidas',
  'medicamentos': [
    {
      'nombre': 'Metformina',
      'dosis': '850 mg',
      'frecuenciaHoras': '12',
      'duracionDias': '30'
    }
  ],
  'activa': true
}
```

---

## Platform Setup

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<!-- NFC permissions -->
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />

<!-- Camera permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />

<!-- Storage permissions -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

**Notes**:
- `android:required="false"` allows installation on devices without NFC/camera
- Graceful feature degradation in app
- Storage permissions handle both legacy and new Android versions

### iOS (`ios/Runner/Info.plist`)

```xml
<!-- NFC permissions -->
<key>NFCReaderUsageDescription</key>
<string>Esta aplicación necesita acceso a NFC para leer y escribir prescripciones médicas</string>

<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>

<!-- Camera permissions -->
<key>NSCameraUsageDescription</key>
<string>Esta aplicación necesita acceso a la cámara para capturar fotos de prescripciones</string>

<!-- Photo library permissions -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Esta aplicación necesita acceso a tu galería para seleccionar imágenes</string>
```

**Additional iOS Setup** (for NFC):
1. Enable "Near Field Communication Tag Reading" capability in Xcode
2. Add entitlement in `ios/Runner/Runner.entitlements`

---

## Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  # NFC support
  flutter_nfc_kit: ^3.3.1
  
  # OCR and image processing
  google_mlkit_text_recognition: ^0.14.0
  image_picker: ^1.1.2
```

### Installation

```bash
cd mymeds
flutter pub get
```

---

## Testing

### Unit Tests (`test/prescription_adapter_test.dart`)

**Coverage**:
- ✅ NFC JSON conversion (to/from)
- ✅ OCR data parsing
- ✅ Validation logic
- ✅ Date format parsing
- ✅ Roundtrip data integrity
- ✅ Error handling
- ✅ Missing field detection

**Run tests**:
```bash
flutter test test/prescription_adapter_test.dart
```

### Manual Testing Checklist

#### NFC Testing
- [ ] Test on device with NFC enabled
- [ ] Test on device with NFC disabled
- [ ] Test on device without NFC hardware
- [ ] Write prescription to tag
- [ ] Read prescription from tag
- [ ] Attempt to overwrite existing tag (confirm dialog)
- [ ] Cancel NFC operation mid-scan
- [ ] Test with non-prescription NFC tags

#### OCR Testing
- [ ] Capture photo with camera
- [ ] Select image from gallery
- [ ] Test with clear prescription image
- [ ] Test with blurry image
- [ ] Test with image containing no text
- [ ] Test with handwritten prescription
- [ ] Edit detected fields manually
- [ ] Cancel before uploading
- [ ] Upload with missing required fields

---

## Security Considerations

### NFC Security
- **Data Integrity**: JSON format with type identifier prevents accidental reads
- **Privacy**: Prescription data stored on tag is unencrypted (consider encryption for production)
- **Recommendation**: For sensitive deployments, implement:
  - JSON payload encryption using AES
  - HMAC signature for tamper detection
  - User PIN before reading/writing tags

### OCR Security
- **Privacy**: All processing done on-device (no cloud uploads)
- **Data Validation**: Extracted data requires user confirmation before upload
- **Firestore Security**: Relies on existing Firestore security rules

---

## Troubleshooting

### NFC Issues

**"NFC no disponible"**
- Check device supports NFC
- Enable NFC in device settings
- On Android: Settings → Connected devices → Connection preferences → NFC
- On iOS: NFC always enabled (iPhone 7+)

**"Failed to read tag"**
- Ensure tag is NDEF-formatted
- Hold device steady near tag (1-2 seconds)
- Remove phone case if thick
- Try different tag position

**"Tag is not writable"**
- Tag may be locked/read-only
- Use different NFC tag (recommend NTAG213/215/216)

### OCR Issues

**"No se detectó texto"**
- Ensure image is well-lit
- Text should be clear and in focus
- Try capturing at different angles
- Avoid shadows and glare

**"Campos incompletos"**
- Manual review and editing required
- Some handwritten prescriptions may not OCR well
- Printed prescriptions work best

**Camera not opening**
- Check camera permissions granted
- Restart app
- Check camera not in use by another app

### General Issues

**Dependencies not found**
- Run `flutter pub get`
- Run `flutter clean` then `flutter pub get`
- Check Flutter SDK version compatibility

**Build errors**
- For Android: Update `compileSdkVersion` to 33+
- For iOS: Update deployment target to 12.0+

---

## Future Enhancements

### Planned Features
- [ ] Prescription selection UI for NFC write
- [ ] Encrypted NFC payloads
- [ ] Batch image processing
- [ ] Prescription OCR accuracy improvement with custom ML model
- [ ] QR code support as alternative to NFC
- [ ] Voice input for prescription data
- [ ] Integration with healthcare provider APIs
- [ ] Multi-language OCR support

### Performance Optimizations
- [ ] Image compression before OCR
- [ ] Caching of parsed prescriptions
- [ ] Background processing for large images
- [ ] Parallel processing of multiple prescriptions

---

## API Reference

### NfcService

```dart
class NfcService {
  Future<bool> isAvailable();
  Future<String?> readNdefJson();
  Future<void> writeNdefJson(String jsonPayload, {bool overwrite = false});
  Future<bool> hasExistingPrescription();
  Future<void> clearTag();
  Future<void> cancelSession();
}
```

### OcrService

```dart
class OcrService {
  Future<File?> capturePhoto();
  Future<File?> pickImageFromGallery();
  Future<String> extractTextFromFile(File imageFile);
  Map<String, dynamic> parsePrescriptionText(String rawText);
  void dispose();
}
```

### PrescriptionAdapter

```dart
class PrescriptionAdapter {
  static String toNdefJson(Prescripcion prescripcion);
  static Prescripcion fromNdefJson(String jsonString);
  static Prescripcion fromOcrData(Map<String, dynamic> parsedData);
  static bool validate(Prescripcion prescripcion);
  static bool validateOcrData(Map<String, dynamic> ocrData);
  static List<String> getMissingFields(Map<String, dynamic> ocrData);
  static Prescripcion createMockPrescription();
  static Map<String, String> formatForDisplay(Prescripcion prescripcion);
}
```

---

## Contributing

When adding new features or fixing bugs:

1. Follow existing code style and patterns
2. Add unit tests for new adapter logic
3. Update this README with any API changes
4. Test on both Android and iOS devices
5. Consider backwards compatibility
6. Add logging for debugging (use `debugPrint`)

---

## License

This code is part of the MyMeds application. See main project LICENSE file.

---

## Support

For issues or questions:
- Check the Troubleshooting section above
- Review existing issues in the project repository
- Create a new issue with:
  - Device model and OS version
  - Flutter version
  - Steps to reproduce
  - Expected vs actual behavior
  - Screenshots if applicable

---

**Version**: 1.0.0  
**Last Updated**: October 2024  
**Maintainer**: MyMeds Development Team
