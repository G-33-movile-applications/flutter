# Multi-Image OCR Upload Improvements

## Issues Fixed

### 1. Unable to Add More Than One Image
**Problem**: After uploading the first image, users couldn't add additional images even though the UI said "max 3 images".

**Root Cause**: 
- The UI logic was correct but not visually prominent
- Users didn't realize they could add more images because the buttons weren't clearly visible after scrolling down to review extracted data
- No clear indicator showing how many more images could be added

**Solution**:
1. **Enhanced Visual Indicators**: Added a prominent info card showing remaining image slots
2. **Floating Action Button**: Added a FAB that stays visible when scrolling, allowing quick access to add more images
3. **Better Layout**: Improved the button placement to be more visible
4. **Clear Counter**: Shows "X/3" in multiple places to indicate progress

### 2. New Images Overwriting Previous Data
**Problem**: When adding additional images, the concern was that new data might overwrite existing extracted data instead of merging/appending.

**Root Cause**: 
- The `_processAllImages()` method needed to intelligently merge data from multiple images
- Need to avoid duplicate medications
- Need to select the best/most complete information from multiple sources

**Solution**:
The `_processAllImages()` method now:
1. **Merges Doctor/Diagnosis**: Selects the longest/most complete text from all images
2. **Accumulates Medications**: Collects all unique medications from all images (no duplicates by name)
3. **Preserves Dates**: Uses the first valid date found
4. **Calculates Confidence**: Averages confidence scores from all images
5. **Reprocesses on Removal**: When an image is removed, automatically reprocesses remaining images

## UI/UX Improvements

### New Info Card
```dart
// Shows prominently at the top when images are added
Card(
  color: AppTheme.primaryColor.withOpacity(0.1),
  child: Row(
    Icon(Icons.collections),
    Text('Puedes agregar X imagen(es) más'),
    Text('X/3'), // Counter
  ),
)
```

### Floating Action Button
```dart
// Appears when:
// - At least 1 image exists
// - Less than 3 images (not at max)
// - Not currently processing
FloatingActionButton.extended(
  icon: Icon(Icons.add_photo_alternate),
  label: Text('Agregar (X/3)'),
  onPressed: () => showDialog(...), // Choose camera or gallery
)
```

### Button Visibility
The camera/gallery buttons now:
- Always show when `_selectedImages.length < _maxImages`
- Have clear title: "Seleccionar Imagen" or "Agregar Más Imágenes"
- Display prominently above the image preview

## Data Merging Logic

### Doctor Name
- Compares all extracted doctor names
- Selects the **longest** one (most complete)
- Falls back to empty string if none found

### Diagnosis
- Compares all extracted diagnoses
- Selects the **longest** one (most complete)
- Falls back to empty string if none found

### Medications
- Collects medications from all images
- **Prevents duplicates** by checking medication name (case-insensitive)
- Preserves all unique medications
- If no medications found in any image, adds one empty medication template

### Date
- Uses the **first valid date** found across all images
- Falls back to current date if none found

### Confidence Score
- Calculates **average** confidence from all images
- Shows appropriate message based on confidence level:
  - ≥70%: Success message (green)
  - 40-69%: Warning message (orange) - "Please review"
  - <40%: Error message (red) - "Low confidence, review carefully"

## Code Changes

### File: `lib/ui/upload/ocr_upload_page.dart`

#### Enhanced UI (lines ~1020-1090):
```dart
// NEW: Info card showing remaining slots
if (_selectedImages.isNotEmpty) ...[
  Card(
    color: AppTheme.primaryColor.withOpacity(0.1),
    child: Row(
      Icon(Icons.collections),
      Text('Puedes agregar ${_maxImages - _selectedImages.length} imagen(es) más'),
      Text('${_selectedImages.length}/$_maxImages'),
    ),
  ),
]

// Camera/Gallery buttons - always visible when under max
if (_selectedImages.length < _maxImages) ...[
  Text(_selectedImages.isEmpty ? 'Seleccionar Imagen' : 'Agregar Más Imágenes'),
  Row([Camera Button, Gallery Button]),
]
```

#### Floating Action Button (lines ~1403-1445):
```dart
floatingActionButton: _selectedImages.isNotEmpty && 
                      _selectedImages.length < _maxImages && 
                      !_isProcessing
    ? FloatingActionButton.extended(
        onPressed: () async {
          final choice = await showDialog<String>(...);
          if (choice == 'camera') await _handleCameraCapture();
          else if (choice == 'gallery') await _handleGalleryPick();
        },
        icon: Icon(Icons.add_photo_alternate),
        label: Text('Agregar (${_selectedImages.length}/$_maxImages)'),
      )
    : null,
```

#### Data Merging in `_processAllImages()` (lines ~167-315):
```dart
// For each parsed image:
for (final data in allParsedData) {
  // Get best doctor (longest)
  if (data['doctor'] != null) {
    if (bestDoctor == null || data['doctor'].length > bestDoctor.length) {
      bestDoctor = data['doctor'];
    }
  }
  
  // Get best diagnosis (longest)
  if (data['diagnosis'] != null) {
    if (bestDiagnosis == null || data['diagnosis'].length > bestDiagnosis.length) {
      bestDiagnosis = data['diagnosis'];
    }
  }
  
  // Collect unique medications (no duplicates by name)
  if (data['medications'] != null) {
    for (var med in data['medications']) {
      final medName = med['name']?.toLowerCase() ?? '';
      final exists = allMedications.any((existing) => 
        existing['name']?.toLowerCase() == medName
      );
      if (!exists && medName.isNotEmpty) {
        allMedications.add(med);
      }
    }
  }
}
```

#### Image Removal with Reprocessing (lines ~145-165):
```dart
void _removeImage(int index) {
  setState(() {
    _selectedImages.removeAt(index);
  });
  
  if (_selectedImages.isEmpty) {
    // Clear all data
    setState(() {
      _extractedText = null;
      _medicoController.clear();
      _diagnosticoController.clear();
      _medications.clear();
    });
  } else {
    // Reprocess remaining images to update extracted data
    _processAllImages();
  }
}
```

## User Experience Flow

### Adding Multiple Images:

1. **First Image**:
   - User taps Camera or Gallery button
   - Image is processed with OCR
   - Data is extracted and displayed
   - Info card appears: "Puedes agregar 2 imagen(es) más (1/3)"
   - Camera/Gallery buttons remain visible
   - Floating action button appears

2. **Second Image**:
   - User taps "Agregar Más Imágenes" buttons OR FAB
   - Second image is processed
   - Data is **merged** with first image:
     - Doctor/diagnosis: Best (longest) value kept
     - Medications: All unique medications combined
   - Counter updates: "2/3"
   - Buttons still visible

3. **Third Image**:
   - User adds third image
   - Data merged again
   - Counter shows: "3/3"
   - Buttons **disappear** (max reached)
   - FAB **disappears**
   - Orange message: "Máximo 3 imágenes alcanzado"

4. **Removing Images**:
   - User taps X on any image
   - Image removed from list
   - **Automatic reprocessing**: Remaining images are re-analyzed
   - Data updates to reflect remaining images only
   - Buttons **reappear** if under max
   - FAB **reappears**

## Benefits

### For Users:
✅ **Clear Visual Feedback**: Always know how many images can be added
✅ **Easy Access**: FAB makes adding images quick even after scrolling
✅ **No Data Loss**: All medications from all images are preserved
✅ **Smart Merging**: Best information is automatically selected
✅ **Flexible**: Can remove and re-add images dynamically

### For Data Quality:
✅ **No Duplicates**: Medications are deduplicated by name
✅ **Best Information**: Longest/most complete doctor and diagnosis names
✅ **Comprehensive**: All medications from all prescriptions captured
✅ **Accurate**: Reprocessing ensures data matches current image set

## Testing Checklist

- [x] Add 1 image → Verify buttons remain visible
- [x] Add 2 images → Verify medications from both images are merged
- [x] Add 3 images → Verify buttons disappear at max
- [x] Remove 1 image → Verify data reprocesses correctly
- [x] Remove all images → Verify UI resets completely
- [x] Add image with doctor name → Add image with diagnosis → Verify both appear
- [x] Add 2 images with same medication → Verify only 1 medication appears (no duplicate)
- [x] Scroll down to form → Verify FAB is visible and functional
- [x] Tap FAB → Verify dialog shows camera/gallery options
- [x] Add 3 images → Remove 1 → Verify can add another

## Related Files

- `lib/ui/upload/ocr_upload_page.dart` - Main OCR upload UI and logic
- `lib/services/ocr_service.dart` - OCR text extraction and parsing
- `lib/ui/upload/widgets/prescription_preview_widget.dart` - Prescription preview
- `lib/repositories/prescripcion_repository.dart` - Firestore save operations

## Notes

- Maximum images is configurable via `_maxImages` constant (currently 3)
- Each image is processed independently for best accuracy
- Merging logic prioritizes completeness over recency
- Duplicate detection is case-insensitive for medication names
- FAB only appears when at least 1 image exists (prevents clutter on empty screen)
- All image processing maintains the existing OCR confidence scoring system
