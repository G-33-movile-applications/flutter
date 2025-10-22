# OCR Upload Validation - October 2025

## Overview
Added comprehensive validation to prevent gibberish and empty data from being saved to Firestore when uploading prescriptions via OCR.

## Validation Rules

### 1. ✅ **Doctor Name (Required)**
- **Cannot be empty**
- Must be at least 5 characters long
- Must pass intelligent validation:
  - Contains at least letters (not just numbers/symbols)
  - At least one valid word (2+ characters)
  - Not mostly numbers (gibberish detection)
  - Accepts common titles: Dr., Dra., Doctor, Doctora

**Valid Examples:**
- ✅ "Dr. Juan Pérez"
- ✅ "Dra. María González"
- ✅ "Juan Pérez"
- ✅ "Doctor Roberto Silva"

**Invalid Examples:**
- ❌ "" (empty)
- ❌ "Dr" (too short)
- ❌ "123" (only numbers)
- ❌ "Dr. 123" (mostly numbers)
- ❌ "x" (too short)

### 2. ✅ **Diagnosis (Required)**
- **Cannot be empty**
- Must be at least 3 characters long
- Should be a meaningful description

**Valid Examples:**
- ✅ "Gripe común"
- ✅ "Dolor de cabeza"
- ✅ "Hipertensión"

**Invalid Examples:**
- ❌ "" (empty)
- ❌ "x" (too short)
- ❌ "ab" (too short)

### 3. ✅ **Medications (At Least One Required)**
- **Must have at least one medication**
- Each medication must pass validation (see below)

### 4. ✅ **Medication Name (Required for each medication)**
- **Cannot be empty**
- Must be at least 3 characters long
- Must contain letters (not just numbers)
- Must have at least 2 letters minimum
- Cannot be common placeholders:
  - ❌ "Medicamento", "medicina", "test", "ejemplo"
  - ❌ "asdf", "xxx", "n/a", "none", "null"
- Cannot be all same character repeated (e.g., "aaaa")
- Cannot be mostly numbers (max 2x numbers vs letters ratio)

**Valid Examples:**
- ✅ "Paracetamol"
- ✅ "Ibuprofeno 400mg"
- ✅ "Amoxicilina"
- ✅ "Losartán"

**Invalid Examples:**
- ❌ "" (empty)
- ❌ "ab" (too short)
- ❌ "123" (only numbers)
- ❌ "Medicamento" (placeholder)
- ❌ "asdf" (gibberish)
- ❌ "xxx" (placeholder)
- ❌ "aaaa" (repeated character)
- ❌ "12ab34cd56" (too many numbers)

### 5. ✅ **Medication Dosage**
- **Cannot be empty**
- Must be a valid number
- Must be greater than 0 mg
- Warning if > 10,000 mg (unusually high)

**Valid Examples:**
- ✅ 500 (mg)
- ✅ 250.5 (mg)
- ✅ 1000 (mg)

**Invalid Examples:**
- ❌ "" (empty)
- ❌ "abc" (not a number)
- ❌ 0 (must be > 0)
- ❌ -10 (must be positive)
- ⚠️ 15000 (warning: very high)

### 6. ✅ **Frequency (Hours)**
- **Cannot be empty**
- Must be a valid integer
- Must be greater than 0 hours
- Must be at least 1 hour
- Warning if > 168 hours (1 week)

**Valid Examples:**
- ✅ 8 (every 8 hours)
- ✅ 12 (every 12 hours)
- ✅ 24 (every 24 hours)

**Invalid Examples:**
- ❌ "" (empty)
- ❌ "abc" (not a number)
- ❌ 0 (must be > 0)
- ❌ -5 (must be positive)
- ⚠️ 200 (warning: very long interval)

### 7. ✅ **Duration (Days)**
- **Cannot be empty**
- Must be a valid integer
- Must be greater than 0 days
- Warning if > 365 days (1 year)

**Valid Examples:**
- ✅ 7 (days)
- ✅ 10 (days)
- ✅ 30 (days)

**Invalid Examples:**
- ❌ "" (empty)
- ❌ "abc" (not a number)
- ❌ 0 (must be > 0)
- ❌ -3 (must be positive)
- ⚠️ 400 (warning: very long treatment)

## User Experience

### Validation Error Dialog
When validation fails, user sees a clear dialog with:
- 🔴 Red error icon
- **"Error de Validación"** title
- Detailed list of all errors found
- Each error shows:
  - ❌ Critical error (must fix)
  - ⚠️ Warning (should review)
  - Medication number (e.g., "Medicamento #1")
  - Specific problem description
- Red info box: "Por favor corrige los errores para poder guardar la prescripción"
- "Entendido" button to dismiss

### Example Error Message
```
Se encontraron los siguientes errores:

❌ Medicamento #1: El nombre "Medicamento" no parece válido
❌ Medicamento #2: El nombre es obligatorio
❌ Medicamento #3: La dosis debe ser un número mayor a 0
⚠️ Medicamento #4: La dosis parece muy alta (15000mg). Verifica si es correcto.

Por favor corrige estos errores antes de guardar.
```

## Implementation Details

### Validation Flow
1. User fills OCR form with extracted/edited data
2. User clicks "Guardar Prescripción" button
3. `_handleUpload()` method runs comprehensive validation:
   - Validates doctor name
   - Validates diagnosis
   - Validates at least one medication exists
   - Validates each medication's fields
4. If **any** validation fails:
   - Show validation error dialog with all errors
   - Stop upload process
   - Keep form data intact for user to fix
5. If **all** validation passes:
   - Show confirmation dialog
   - Upload to Firestore
   - Show success message
   - Clear form

### Helper Methods

#### `_isValidDoctorName(String name)`
Intelligent validation for doctor names:
- Removes common titles (Dr., Dra.)
- Checks for minimum length
- Ensures contains letters
- Detects gibberish (too many numbers)
- Returns `bool`

#### `_isValidMedicationName(String name)`
Intelligent validation for medication names:
- Checks minimum length (3 chars)
- Ensures contains letters (not just numbers)
- Blocks common placeholders
- Detects gibberish patterns
- Returns `bool`

#### `_showValidationErrorDialog(String message)`
User-friendly error display:
- Red error icon and title
- Scrollable content for long error lists
- Red info box with guidance
- Single "Entendido" button

## Testing Checklist

### ✅ Test Valid Data
- [ ] Complete form with valid data → Should save successfully
- [ ] "Dr. Juan Pérez" as doctor → Should accept
- [ ] "Paracetamol" as medication → Should accept
- [ ] All numeric fields with valid numbers → Should accept

### ❌ Test Invalid Doctor
- [ ] Empty doctor name → Should show error
- [ ] "Dr" only → Should show error (too short)
- [ ] "123" as doctor → Should show error (only numbers)
- [ ] "x" as doctor → Should show error (too short)

### ❌ Test Invalid Diagnosis
- [ ] Empty diagnosis → Should show error
- [ ] "ab" as diagnosis → Should show error (too short)

### ❌ Test No Medications
- [ ] Try to save without medications → Should show error
- [ ] Add medication then remove it → Should show error

### ❌ Test Invalid Medication Names
- [ ] Empty medication name → Should show error
- [ ] "ab" as name → Should show error (too short)
- [ ] "Medicamento" → Should show error (placeholder)
- [ ] "asdf" → Should show error (gibberish)
- [ ] "xxx" → Should show error (placeholder)
- [ ] "123" → Should show error (only numbers)

### ❌ Test Invalid Medication Numbers
- [ ] Empty dosage → Should show error
- [ ] "abc" as dosage → Should show error
- [ ] 0 as dosage → Should show error
- [ ] -10 as dosage → Should show error
- [ ] Empty frequency → Should show error
- [ ] 0 as frequency → Should show error
- [ ] Empty duration → Should show error
- [ ] 0 as duration → Should show error

### ⚠️ Test Warnings
- [ ] 15000mg dosage → Should show warning but allow
- [ ] 200 hours frequency → Should show warning
- [ ] 400 days duration → Should show warning

## Files Modified

**lib/ui/upload/ocr_upload_page.dart**
- Modified `_handleUpload()` method
  - Added comprehensive validation before saving
  - Collects all errors before showing dialog
  - Uses `double.parse()` and `int.parse()` (safe because validated)
- Added `_showValidationErrorDialog()` method
  - User-friendly error display
  - Scrollable content
  - Red theme for errors
- Added `_isValidDoctorName()` method
  - Intelligent doctor name validation
  - Handles common titles
  - Gibberish detection
- Added `_isValidMedicationName()` method
  - Intelligent medication name validation
  - Placeholder detection
  - Gibberish patterns

## Benefits

### 1. **Data Quality** 🎯
- No more empty medications in database
- No more gibberish names like "asdf" or "xxx"
- Valid numeric values for dosage/frequency/duration

### 2. **User Experience** 👤
- Clear error messages explaining what's wrong
- All errors shown at once (not one-by-one)
- Form data preserved for easy fixing
- Warnings for unusual but valid values

### 3. **Database Integrity** 💾
- Firestore only receives validated data
- No null/empty required fields
- Consistent data format
- Easier querying and reporting

### 4. **Error Prevention** 🛡️
- Catches typos before saving
- Prevents accidental submissions
- Validates OCR mistakes
- Guides user to correct data

## Future Enhancements

Possible improvements:
- [ ] Add medication name autocomplete from database
- [ ] Suggest corrections for common typos
- [ ] Add dosage unit validation (mg/ml/g)
- [ ] Validate frequency against common patterns
- [ ] Check for duplicate medication names
- [ ] Add spell-checking for doctor names
- [ ] Validate date is not in future
- [ ] Add diagnosis suggestions/categories

---

**Created:** October 21, 2025  
**Status:** ✅ Implemented & Ready for Testing  
**Impact:** High - Prevents bad data from entering Firestore
