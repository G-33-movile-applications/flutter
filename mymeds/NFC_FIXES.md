# NFC Fixes - October 2025

## Issues Fixed

### 1. ❌ **Timestamp Type Error** 
**Problem:** When writing existing prescriptions to NFC, the app crashed with "Type String is not subtype of Timestamp"

**Root Cause:** 
- Prescriptions loaded from Firestore have `fechaCreacion` as `Timestamp` type
- The `PrescriptionAdapter.toNdefJson()` method tried to call `.toIso8601String()` directly on Timestamp
- Timestamp doesn't have this method, causing a runtime error

**Fix Applied:**
- Added type checking in `prescription_adapter.dart` → `toNdefJson()`
- Now detects if `fechaCreacion` is a Timestamp and converts to DateTime first
- Then safely converts DateTime to ISO8601 string for JSON serialization

**Code Change:**
```dart
// Handle fechaCreacion - could be DateTime or Timestamp from Firestore
DateTime fechaCreacion;
if (prescripcion.fechaCreacion is Timestamp) {
  fechaCreacion = (prescripcion.fechaCreacion as Timestamp).toDate();
} else {
  fechaCreacion = prescripcion.fechaCreacion;
}
```

**Status:** ✅ FIXED

---

### 2. ❌ **"Cannot call method when attached to activity"**
**Problem:** Writing/reading NFC sometimes failed with "Cannot call method when attached to an activity" error

**Root Causes:**
- Multiple NFC sessions running simultaneously
- App reopening during active NFC operations (intent-filter conflicts)
- No cleanup of previous NFC sessions before starting new ones

**Fixes Applied:**

#### A. Session Management (`nfc_service.dart`)
- Improved error handling in `writeNdefJson()` and `clearTag()`
- Added proper try-catch-finally blocks to ensure NFC session closes even on error
- Changed timeout handling to finish session immediately after write/clear

**Code Changes:**
```dart
// Before: Only tried to finish on success
await FlutterNfcKit.finish(iosAlertMessage: 'Success');

// After: Always tries to finish, even on error
try {
  // ... NFC operation
  await FlutterNfcKit.finish(iosAlertMessage: 'Success');
} catch (e) {
  try {
    await FlutterNfcKit.finish(iosErrorMessage: 'Failed');
  } catch (finishError) {
    debugPrint('Error finishing NFC session: $finishError');
  }
  rethrow;
}
```

#### B. UI Session Cleanup (`nfc_upload_page.dart`)
- Added `dispose()` method to cancel NFC session when leaving page
- Added `cancelSession()` calls before starting new NFC operations
- Prevents stale sessions from interfering with new operations

**Code Changes:**
```dart
@override
void dispose() {
  // Cancel any ongoing NFC session when leaving the page
  _nfcService.cancelSession();
  super.dispose();
}

// Before starting any NFC operation:
await _nfcService.cancelSession();
```

#### C. AndroidManifest Intent-Filter Optimization
**Changed from:**
- 3 intent-filters (custom MIME, text/plain, TAG_DISCOVERED)
- `launchMode="singleTop"` - creates new instance if needed

**Changed to:**
- 1 intent-filter (ONLY custom MIME type)
- `launchMode="singleTask"` - reuses existing instance

**Reasoning:**
- Having 3 intent-filters caused the app to reopen for ANY NFC tag
- When writing to a tag, Android would detect it and reopen the app mid-operation
- This interrupted the active NFC session, causing the "attached to activity" error
- Now only opens for tags we've explicitly written (with our MIME type)

**Status:** ✅ FIXED

---

### 3. ⚠️ **App Reopening During NFC Operations**
**Problem:** When phone detects NFC tag, it reopens/focuses the app, interrupting active operations

**Root Cause:**
- Too many intent-filters in AndroidManifest
- Intent-filters for `text/plain` and `TAG_DISCOVERED` triggered on every tag
- System tried to launch/focus app while already performing NFC operation

**Fix Applied:**
- Removed fallback intent-filters (`text/plain` and `TAG_DISCOVERED`)
- Only keep the specific MyMeds MIME type intent-filter
- Changed `launchMode` from `singleTop` to `singleTask`

**Trade-off:**
- ✅ App no longer reopens during active operations
- ✅ More stable NFC experience
- ⚠️ App will ONLY auto-open for tags written by MyMeds (with custom MIME type)
- ⚠️ Random NFC tags won't trigger the app (this is actually good for UX)

**Status:** ✅ FIXED (with intentional limitation)

---

### 4. ⚠️ **Clear NFC Function Not Tested**
**Problem:** User unable to test the clear/delete NFC tag function

**Current Status:**
- Function is implemented in `nfc_service.dart` → `clearTag()`
- Writes an empty `TextRecord` to the tag
- Should work correctly now with improved error handling

**Testing Required:**
1. Go to NFC Upload page
2. Tap "Limpiar Tag NFC" (red button)
3. Confirm the destructive action dialog
4. Hold phone near NFC tag
5. Verify success message appears
6. Try reading the tag - should show "Tag vacío o sin prescripción"

**Status:** ⏳ NEEDS TESTING

---

## Files Modified

1. **lib/adapters/prescription_adapter.dart**
   - Fixed `toNdefJson()` to handle Timestamp type from Firestore
   - Added type checking and conversion logic

2. **lib/services/nfc_service.dart**
   - Improved error handling in `writeNdefJson()`
   - Improved error handling in `clearTag()`
   - Better session cleanup in all methods

3. **lib/ui/upload/nfc_upload_page.dart**
   - Added `dispose()` method with session cleanup
   - Added `cancelSession()` calls before all NFC operations
   - Prevents session conflicts

4. **android/app/src/main/AndroidManifest.xml**
   - Removed 2 fallback intent-filters
   - Changed `launchMode` from `singleTop` to `singleTask`
   - Now only responds to MyMeds prescription tags

---

## Testing Guide

### Build and Install
```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

Install the APK on your physical device (emulator doesn't support NFC).

### Test Scenarios

#### ✅ Test 1: Write Mock Prescription
1. Open app → Upload → NFC Upload
2. Tap "Escribir Prescripción en NFC" (blue button)
3. Select "Crear Prescripción de Prueba"
4. Fill in doctor name and diagnosis
5. Tap "Crear"
6. Hold phone near NFC tag
7. **Expected:** Success message, no errors

#### ✅ Test 2: Write Existing Prescription (Previously Broken)
1. Make sure you have at least one prescription in your account
2. Open app → Upload → NFC Upload
3. Tap "Escribir Prescripción en NFC" (blue button)
4. Select "Prescripción Existente"
5. Choose a prescription from the list
6. Hold phone near NFC tag
7. **Expected:** Success message, NO "Timestamp" error

#### ✅ Test 3: Read Prescription (App Should NOT Reopen)
1. Open app → Upload → NFC Upload
2. Tap "Leer Prescripción desde NFC" (green button)
3. Hold phone near NFC tag (with MyMeds prescription)
4. **Expected:** 
   - Prescription data appears
   - App does NOT close/reopen/restart
   - No "attached to activity" error

#### ✅ Test 4: Clear NFC Tag
1. Open app → Upload → NFC Upload
2. Tap "Limpiar Tag NFC" (red button)
3. Confirm the warning dialog
4. Hold phone near NFC tag
5. **Expected:** Success message
6. Try reading the tag → should say "Tag vacío"

#### ⚠️ Test 5: Auto-Open on Tag Approach (External Tag Detection)
1. **Close the MyMeds app completely** (swipe away from recent apps)
2. Hold phone near NFC tag that has MyMeds prescription
3. **Expected:** 
   - App should open automatically
   - Should show the prescription data
   - This proves intent-filter works correctly

---

## Known Limitations

### 1. Won't Auto-Open for Random NFC Tags
**Behavior:** App only auto-opens for tags written by MyMeds (custom MIME type)

**Reason:** We removed fallback intent-filters to prevent reopening conflicts

**Impact:** If you have a generic text-based NFC tag, the app won't automatically open. This is **intentional** and **good for UX** - prevents the app from popping up for every random NFC tag.

**Workaround:** Manually open the app and use "Leer Prescripción desde NFC" button

### 2. OCR is Working but Not Perfect
**Status:** User confirmed "Image is done for now, it isn't perfect but it works just fine"

**Decision:** No further OCR improvements in this fix session

### 3. iOS NFC Capabilities
**Status:** Not configured yet

**Required:** 
- Open project in Xcode
- Enable "Near Field Communication Tag Reading" capability
- Add NFC usage description to Info.plist

---

## Commit Message

```
fix(nfc): resolve timestamp error, session conflicts, and app reopening

FIXED ISSUES:
1. Timestamp type error when writing existing prescriptions to NFC
   - Added type checking in PrescriptionAdapter.toNdefJson()
   - Now handles both DateTime and Firestore Timestamp types
   
2. "Cannot call method when attached to activity" error
   - Improved NFC session cleanup and error handling
   - Added dispose() method to cancel sessions on page exit
   - Always cancel previous session before starting new operation
   
3. App reopening during active NFC operations
   - Removed fallback intent-filters (text/plain, TAG_DISCOVERED)
   - Changed launchMode from singleTop to singleTask
   - Now only auto-opens for MyMeds prescription tags (custom MIME)

TECHNICAL CHANGES:
- lib/adapters/prescription_adapter.dart: Handle Timestamp conversion
- lib/services/nfc_service.dart: Better error handling, session cleanup
- lib/ui/upload/nfc_upload_page.dart: Session management, dispose()
- android/app/src/main/AndroidManifest.xml: Optimized intent-filters

TESTING REQUIRED:
- Write existing prescription to NFC (should not crash)
- Read prescription without app reopening
- Clear NFC tag function (not yet tested by user)

KNOWN LIMITATIONS:
- App only auto-opens for MyMeds tags (by design, prevents conflicts)
- OCR working but not perfect (user confirmed acceptable)
```

---

## Next Steps

1. **Immediate:** Test all 5 scenarios above on physical device
2. **Report:** Any remaining issues with specific error messages
3. **Optional:** Configure iOS NFC capabilities if testing on iPhone
4. **Future:** Consider adding NFC tag history/management feature

---

**Last Updated:** October 21, 2025  
**Fixes By:** GitHub Copilot  
**Status:** ✅ Ready for Testing
