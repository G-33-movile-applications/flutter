import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/address_validator.dart';
import 'connectivity_service.dart';

/// Service class that handles location-related operations
/// Provides methods to get current location and convert coordinates to addresses
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  final ConnectivityService _connectivityService = ConnectivityService();

  /// Checks if location permissions are granted and location services are enabled
  /// Returns a tuple of (permission granted, service enabled, error message)
  Future<LocationPermissionResult> checkLocationPermissions() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult(
          permissionGranted: false,
          serviceEnabled: false,
          errorMessage: 'Los servicios de ubicación están deshabilitados.',
        );
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationPermissionResult(
            permissionGranted: false,
            serviceEnabled: true,
            errorMessage: 'Necesitamos acceso a tu ubicación para sugerir direcciones.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionResult(
          permissionGranted: false,
          serviceEnabled: true,
          errorMessage: 'Los permisos de ubicación están deshabilitados permanentemente. Por favor habilítalos en configuración.',
        );
      }

      return LocationPermissionResult(
        permissionGranted: true,
        serviceEnabled: true,
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('LocationService: Error checking permissions: $e');
      return LocationPermissionResult(
        permissionGranted: false,
        serviceEnabled: false,
        errorMessage: 'Error verificando permisos de ubicación: $e',
      );
    }
  }

  /// Gets the current position of the device using the same settings as MapScreen
  /// Returns null if location cannot be obtained
  Future<Position?> getCurrentPosition() async {
    try {
      final permissionResult = await checkLocationPermissions();
      if (!permissionResult.permissionGranted) {
        debugPrint('LocationService: Cannot get position - ${permissionResult.errorMessage}');
        return null;
      }

      // Use the same method as MapScreen for consistency
      final position = await Geolocator.getCurrentPosition();

      debugPrint('LocationService: Current position obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('LocationService: Error getting current position: $e');
      return null;
    }
  }

  /// Converts coordinates to a human-readable address
  /// Returns a formatted address string or null if geocoding fails
  /// Throws exception with user-friendly message if offline
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    // Check connectivity before attempting geocoding (requires network)
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      throw Exception('No tienes conexión a internet. Necesitas conexión para obtener tu ubicación actual.');
    }
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Build address string with available components
        List<String> addressComponents = [];
        
        if (placemark.street?.isNotEmpty == true) {
          addressComponents.add(placemark.street!);
        }
        if (placemark.subThoroughfare?.isNotEmpty == true) {
          addressComponents.add(placemark.subThoroughfare!);
        }
        if (placemark.locality?.isNotEmpty == true) {
          addressComponents.add(placemark.locality!);
        }
        if (placemark.administrativeArea?.isNotEmpty == true) {
          addressComponents.add(placemark.administrativeArea!);
        }
        
        final address = addressComponents.join(', ');
        final cleanedAddress = AddressValidator.cleanAddress(address);
        debugPrint('LocationService: Address resolved: $cleanedAddress');
        return cleanedAddress.isNotEmpty ? cleanedAddress : null;
      }
      
      debugPrint('LocationService: No placemarks found for coordinates');
      throw Exception('No se pudo convertir las coordenadas a una dirección');
    } catch (e) {
      // Re-throw connectivity errors as-is
      if (e.toString().contains('conexión')) {
        rethrow;
      }
      debugPrint('LocationService: Error getting address from coordinates: $e');
      throw Exception('No se pudo obtener la dirección: ${e.toString()}');
    }
  }

  /// Gets the current location as a formatted address string
  /// Returns null if location cannot be obtained or geocoded
  Future<String?> getCurrentLocationAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return null;
      }

      return await getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('LocationService: Error getting current location address: $e');
      return null;
    }
  }

  /// Formats an address for display
  /// Truncates long addresses and ensures consistent formatting
  String formatAddressForDisplay(String address) {
    if (address.length <= 50) {
      return address;
    }
    
    // Try to truncate at a comma
    final commaIndex = address.indexOf(',', 40);
    if (commaIndex != -1) {
      return '${address.substring(0, commaIndex)}...';
    }
    
    // Otherwise truncate at 47 characters and add ellipsis
    return '${address.substring(0, 47)}...';
  }
}

/// Result class for location permission checks
class LocationPermissionResult {
  final bool permissionGranted;
  final bool serviceEnabled;
  final String? errorMessage;

  LocationPermissionResult({
    required this.permissionGranted,
    required this.serviceEnabled,
    this.errorMessage,
  });

  bool get isValid => permissionGranted && serviceEnabled;
}