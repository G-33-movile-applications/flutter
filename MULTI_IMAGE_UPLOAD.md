# Multi-Image Upload Feature

## Overview
Enhanced OCR upload page to support multiple images (up to 3) of the same prescription. This improves OCR accuracy by allowing users to capture different angles, lighting conditions, or multiple pages of a prescription.

## Implementation Date
Date: 2025-01-XX

## Features

### 1. Multiple Image Support
- **Maximum**: 3 images per prescription
- **Add images**: Via camera or gallery
- **Counter**: Shows "X/3" images selected
- **Limit enforcement**: Camera/gallery buttons disabled when limit reached

### 2. Image Management
- **Delete**: Individual delete button (X) on each image thumbnail
- **Reprocessing**: Automatically reprocesses remaining images after deletion
- **Clear all**: Clears all images when form is reset after successful upload

### 3. Text Processing
- **Combined extraction**: Extracts text from all images
- **Separator**: Adds "--- Imagen X ---" separator between images
- **Merged parsing**: Combines all text before parsing prescription data
- **Better accuracy**: Multiple angles provide more complete text extraction

## Code Changes

### State Variables
```dart
// OLD (single image):
File? _selectedImage;

// NEW (multiple images):
final List<File> _selectedImages = [];
final int _maxImages = 3;
```

### Image Handling

#### Adding Images
```dart
Future<void> _handleCameraCapture() async {
  // Check if we've reached the maximum
  if (_selectedImages.length >= _maxImages) {
    _showErrorSnackBar('Máximo $_maxImages imágenes permitidas...');
    return;
  }
  
  final image = await _ocrService.capturePhoto();
  await _addAndProcessImage(image);
}
```

#### Removing Images
```dart
void _removeImage(int index) {
  setState(() {
    _selectedImages.removeAt(index);
    
    // Clear data if all images removed
    if (_selectedImages.isEmpty) {
      _extractedText = null;
      _medicoController.clear();
      _diagnosticoController.clear();
      _medications.clear();
    } else {
      // Reprocess remaining images
      _processAllImages();
    }
  });
}
```

#### Processing All Images
```dart
Future<void> _processAllImages() async {
  if (_selectedImages.isEmpty) return;

  final StringBuffer combinedText = StringBuffer();
  
  for (int i = 0; i < _selectedImages.length; i++) {
    final text = await _ocrService.extractTextFromFile(_selectedImages[i]);
    
    if (text.isNotEmpty) {
      if (combinedText.isNotEmpty) {
        combinedText.writeln('\n--- Imagen ${i + 1} ---\n');
      }
      combinedText.writeln(text);
    }
  }
  
  final extractedText = combinedText.toString().trim();
  // Parse combined text...
}
```

### UI Updates

#### Image Counter
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('Imágenes Seleccionadas'),
    Text('${_selectedImages.length}/$_maxImages'),
  ],
)
```

#### Horizontal Image List with Delete Buttons
```dart
SizedBox(
  height: 150,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: _selectedImages.length,
    itemBuilder: (context, index) {
      return Stack(
        children: [
          // Image thumbnail
          Card(
            child: Image.file(
              _selectedImages[index],
              width: 150,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          // Delete button
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _removeImage(index),
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    },
  ),
)
```

## User Workflow

### Standard Flow
1. **Tap camera/gallery** → Select first image
2. **Image processed** → Text extracted and parsed
3. **Tap camera/gallery again** → Add second image (optional)
4. **All images processed** → Combined text re-parsed
5. **Review data** → Edit if needed
6. **Upload** → Save to Firestore

### Delete Flow
1. **Tap X button** on any image
2. **Image removed** from list
3. **Remaining images reprocessed** → Updated data
4. **Can add more images** if under limit

### Maximum Reached Flow
1. **3 images selected**
2. **Camera/gallery buttons disabled** → Shows error message
3. **Must delete image** to add new one

## Benefits

### For Users
- ✅ **Better OCR accuracy**: Multiple angles capture more text
- ✅ **Flexibility**: Can capture different pages or sections
- ✅ **Error recovery**: Bad shots can be deleted and retried
- ✅ **Visual feedback**: See all selected images at once

### For Colombian Prescriptions
- ✅ **Multi-page support**: Some prescriptions span multiple pages
- ✅ **Poor lighting recovery**: Can take additional shots with better lighting
- ✅ **Partial captures**: Can focus on specific sections (medications, doctor info)
- ✅ **Handwriting variations**: Multiple angles help with unclear handwriting

## Performance Considerations

### Text Extraction
- **Sequential processing**: Images processed one at a time
- **Loading indicator**: Shows "Procesando imagen X/Y"
- **Combined text**: All text merged before parsing (single parse operation)

### Memory Management
- **Maximum 3 images**: Prevents excessive memory usage
- **Cleared after upload**: Images cleared when prescription saved
- **Temporary storage**: Images kept in memory only during upload process

## Testing Checklist

- [x] Add 3 images via camera → All stored correctly
- [x] Add 3 images via gallery → All stored correctly
- [x] Delete middle image → List updates correctly
- [x] Delete all images → Form cleared
- [x] Delete one of three → Can add new image
- [x] Reach limit (3) → Camera/gallery disabled
- [x] Process 3 images → Text from all extracted
- [x] Upload prescription → Images cleared after success
- [x] Colombian prescription (3 images) → Better recognition
- [x] Mixed sources (camera + gallery) → Works correctly

## Known Limitations

1. **No image order control**: Images processed in order added
2. **No preview before processing**: Image immediately processed when added
3. **No image quality validation**: Accepts any image quality
4. **No duplicate detection**: Same image can be added multiple times

## Future Enhancements

### Potential Improvements
- **Reorder images**: Drag-and-drop to change processing order
- **Image preview mode**: View full-size before processing
- **Quality indicators**: Show confidence scores per image
- **Smart duplicate detection**: Prevent adding same image twice
- **Batch upload**: Process multiple prescriptions in one session
- **Image preprocessing**: Auto-enhance, crop, rotate before OCR

## Related Documentation
- `OCR_VALIDATION.md` - Validation rules for extracted data
- `OCR_COLOMBIAN_ENHANCEMENTS.md` - Colombian prescription format support
- `NFC_FIXES.md` - NFC-related improvements

## File Modified
- `lib/ui/upload/ocr_upload_page.dart` - Complete rewrite of image handling logic
