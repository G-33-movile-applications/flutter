# MyMeds Map Screen Implementation

## Overview
The Map screen shows nearby pharmacies (≤ 5 km) from the user's current location using Google Maps integration. It includes location services, permission handling, and interactive pharmacy markers with detailed information sheets.

## Features Implemented

### 🗺️ Map Integration
- **Google Maps**: Full-screen map with user location
- **Location Services**: Automatic user location detection
- **Permission Handling**: Proper location permission requests with error states
- **Markers**: Custom pharmacy markers with distance filtering

### 📍 Location Features  
- **Current Location**: Shows user location dot on map
- **Recenter Button**: FAB to recenter map to user location
- **Distance Calculation**: Haversine formula for accurate distance calculation
- **Proximity Filter**: Only shows pharmacies within 5km radius

### 🏥 Pharmacy Features
- **Nearby Search**: Shows max 3 nearest pharmacies within 5km
- **Mock Data**: 5 sample pharmacies with realistic Bogotá coordinates
- **Marker Details**: Tap markers to see pharmacy information
- **Bottom Sheet**: Detailed pharmacy information with actions

### 🎛️ User Interface
- **FAB Stack**: Three floating action buttons (layers, recenter, settings)
- **Bottom Sheet**: Pharmacy details with navigation and inventory actions
- **Error States**: Friendly error handling for permissions and location services
- **Loading States**: Progress indicators during location acquisition

## File Structure
```
lib/ui/map/
├── map_screen.dart                 # Main map screen implementation
└── widgets/
    └── pharmacy_marker_sheet.dart  # Bottom sheet for pharmacy details
```

## Dependencies Added
```yaml
google_maps_flutter: ^2.7.0  # Google Maps integration
geolocator: ^12.0.0          # Location services
geocoding: ^3.0.0            # Address geocoding
url_launcher: ^6.3.0         # Open external navigation
```

## Android Permissions
Added to `android/app/src/main/AndroidManifest.xml`:
- `ACCESS_FINE_LOCATION` - Precise location access
- `ACCESS_COARSE_LOCATION` - Approximate location access  
- `INTERNET` - Network access for maps
- `ACCESS_NETWORK_STATE` - Network state monitoring

## Mock Data Structure
```dart
class PuntoFisicoMock {
  final String id;           // Unique identifier
  final String nombre;       // Pharmacy name
  final String cadena;       // Chain name (Cruz Verde, Copidrogas, etc.)
  final String direccion;    // Full address
  final double latitud;      // Latitude coordinate
  final double longitud;     // Longitude coordinate
}
```

## Key Algorithms

### Distance Calculation (Haversine Formula)
```dart
double _haversineKm(LatLng point1, LatLng point2)
```
- Pure function for calculating distance between two geographic points
- Returns distance in kilometers
- Unit-test ready and reusable

### Pharmacy Filtering
1. Filter all pharmacies by distance ≤ 5km
2. Sort by distance (nearest first)
3. Take maximum 3 results
4. Create map markers for filtered results

## User Interface Components

### FAB Stack (Right Side)
1. **Layers** (Top) - Map style options (placeholder)
2. **Recenter** (Middle) - Centers map on user location  
3. **Settings** (Bottom) - Filters and preferences (placeholder)

### Pharmacy Bottom Sheet
- **Title**: Pharmacy name (Poetsen One font)
- **Subtitle**: Chain name and distance
- **Address**: Full address with location icon
- **Actions**: Navigate and View Inventory buttons

## Error Handling

### Location Permission States
- **Denied**: Shows friendly message with retry button
- **Denied Forever**: Explains permanent denial
- **Service Disabled**: GPS/location services are off

### Error UI
- Icon illustration
- Clear error message
- Retry button for recoverable errors
- Follows app theme colors and typography

## Navigation Integration
- **External Navigation**: Opens Google Maps with driving directions
- **Internal Navigation**: Placeholder for inventory screen (/storeInventory)
- **Deep Links**: Proper URL handling for external apps

## TODO Hooks for Future Development
- `// TODO: Replace mocks with Firestore collection 'puntos_fisicos'`
- `// TODO: Wire inventory route '/storeInventory'`
- `// TODO: Add filters (cadena/stock) to settings FAB`
- `// TODO: Export visits to Firestore for BQ-T5 hotspots`

## Accessibility Features
- Semantic labels for all interactive elements
- Minimum 48px touch targets
- Screen reader support
- Clear visual hierarchy

## Performance Optimizations
- `Set<Marker>` for efficient marker management
- Minimal state rebuilding
- Lazy loading of map components
- Efficient distance calculations

## Setup Requirements

### Google Maps API Key
1. Get API key from Google Cloud Console
2. Enable Maps SDK for Android
3. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in AndroidManifest.xml

### Testing Locations (Bogotá, Colombia)
The mock pharmacies are positioned around Bogotá coordinates:
- Center: ~4.65, -74.08
- Radius: Within 5km for testing

## Next Steps
1. Replace mock data with Firestore integration
2. Add pharmacy inventory integration
3. Implement filter functionality
4. Add analytics for pharmacy visits
5. Enhance marker clustering for many pharmacies