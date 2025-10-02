# Google Maps API Key Setup

## Required for Map Screen Functionality

The Map screen requires a Google Maps API key to function properly. Follow these steps to set it up:

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS (if building for iOS)
   - Geocoding API (optional, for address lookup)

4. Create credentials:
   - Go to "Credentials" in the sidebar
   - Click "+ CREATE CREDENTIALS" > "API key"
   - Copy the generated API key

### 2. Configure Android

Replace the placeholder in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

### 3. Configure iOS (When needed)

Add to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 4. Security Recommendations

- **Restrict your API key** in Google Cloud Console:
  - Set application restrictions (Android package name)
  - Set API restrictions (only enable needed APIs)
- **Never commit API keys** to version control
- Consider using environment variables or build configurations

### 5. Testing Without API Key

The app will show a "For development purposes only" watermark on the map if no valid API key is provided, but basic functionality will still work for testing.

## Current Mock Data Locations

The app includes 5 mock pharmacies positioned around Bogotá, Colombia:
- **Center coordinates**: ~4.65° N, 74.08° W
- **Radius**: All within 5km for testing
- **Chains**: Cruz Verde, Copidrogas, Locatel, Farmatodo

This allows for testing the distance filtering and marker functionality even without real pharmacy data.