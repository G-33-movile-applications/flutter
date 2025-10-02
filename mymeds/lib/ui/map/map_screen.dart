import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'widgets/pharmacy_marker_sheet.dart';

// Mock data model - TODO: Replace with real PuntoFisico from Firestore
class PuntoFisicoMock {
  final String id;
  final String nombre;
  final String cadena;
  final String direccion;
  final double latitud;
  final double longitud;

  const PuntoFisicoMock({
    required this.id,
    required this.nombre,
    required this.cadena,
    required this.direccion,
    required this.latitud,
    required this.longitud,
  });

  LatLng get location => LatLng(latitud, longitud);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;
  List<PuntoFisicoMock> _nearbyPharmacies = [];

  // Mock pharmacy data - TODO: Replace mocks with Firestore collection 'puntos_fisicos'
  static const List<PuntoFisicoMock> _mockPharmacies = [
    PuntoFisicoMock(
      id: 'farm_1',
      nombre: 'Farmacia San Rafael',
      cadena: 'Cruz Verde',
      direccion: 'Calle 72 #10-34, Bogotá',
      latitud: 4.6500,
      longitud: -74.0800,
    ),
    PuntoFisicoMock(
      id: 'farm_2',
      nombre: 'Droguería La Salud',
      cadena: 'Copidrogas',
      direccion: 'Carrera 15 #85-20, Bogotá',
      latitud: 4.6600,
      longitud: -74.0750,
    ),
    PuntoFisicoMock(
      id: 'farm_3',
      nombre: 'Farmacia Central',
      cadena: 'Locatel',
      direccion: 'Avenida 68 #75-50, Bogotá',
      latitud: 4.6550,
      longitud: -74.0850,
    ),
    PuntoFisicoMock(
      id: 'farm_4',
      nombre: 'Droguería El Descuento',
      cadena: 'Cruz Verde',
      direccion: 'Calle 80 #12-15, Bogotá',
      latitud: 4.6620,
      longitud: -74.0780,
    ),
    PuntoFisicoMock(
      id: 'farm_5',
      nombre: 'Farmacia Norte',
      cadena: 'Farmatodo',
      direccion: 'Calle 90 #20-10, Bogotá',
      latitud: 4.6700,
      longitud: -74.0720,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Necesitamos acceso a tu ubicación para encontrar farmacias cercanas.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Los permisos de ubicación están deshabilitados permanentemente.';
          _isLoading = false;
        });
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Los servicios de ubicación están deshabilitados.';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition();
      
      // Filter nearby pharmacies
      _filterNearbyPharmacies();
      
      // Create markers
      await _createMarkers();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No pudimos obtener tu ubicación. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  void _filterNearbyPharmacies() {
    if (_currentPosition == null) return;

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    _nearbyPharmacies = _mockPharmacies
        .where((pharmacy) {
          final distance = _haversineKm(userLocation, pharmacy.location);
          return distance <= 5.0; // Only pharmacies within 5km
        })
        .toList()
      ..sort((a, b) {
        final distanceA = _haversineKm(userLocation, a.location);
        final distanceB = _haversineKm(userLocation, b.location);
        return distanceA.compareTo(distanceB);
      });

    // Take only the 3 nearest pharmacies
    if (_nearbyPharmacies.length > 3) {
      _nearbyPharmacies = _nearbyPharmacies.take(3).toList();
    }
  }

  Future<void> _createMarkers() async {
    if (_currentPosition == null) return;

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final Set<Marker> markers = {};

    for (final pharmacy in _nearbyPharmacies) {
      final distance = _haversineKm(userLocation, pharmacy.location);
      
      markers.add(
        Marker(
          markerId: MarkerId(pharmacy.id),
          position: pharmacy.location,
          infoWindow: InfoWindow(
            title: pharmacy.nombre,
            snippet: '${pharmacy.cadena} • ${distance.toStringAsFixed(1)} km',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _showPharmacyDetails(pharmacy, distance),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showPharmacyDetails(PuntoFisicoMock pharmacy, double distance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PharmacyMarkerSheet(
        pharmacy: pharmacy,
        distance: distance,
        onNavigate: () => _navigateToPharmacy(pharmacy),
        onViewInventory: () => _viewInventory(pharmacy),
      ),
    );
  }

  Future<void> _navigateToPharmacy(PuntoFisicoMock pharmacy) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${pharmacy.latitud},${pharmacy.longitud}'
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewInventory(PuntoFisicoMock pharmacy) {
    Navigator.pop(context); // Close bottom sheet
    // TODO: Wire inventory route '/storeInventory'
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inventario de ${pharmacy.nombre} - Próximamente'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _recenterToUser() async {
    if (_currentPosition == null || _mapController == null) return;

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(userLocation, 15.0),
    );
  }

  void _showLayersOptions() {
    // TODO: Add filters (cadena/stock) to settings FAB
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Opciones del Mapa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text('Próximamente: Filtros por cadena y stock disponible'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsOptions() {
    // TODO: Add filters (cadena/stock) to settings FAB
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Configuración',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text('Próximamente: Configuración de filtros y preferencias'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MAPA'),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFABStack(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Obteniendo tu ubicación...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeLocation,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return const Center(
        child: Text('No se pudo obtener la ubicación'),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15.0,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
    );
  }

  Widget _buildFABStack() {
    if (_isLoading || _errorMessage != null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layers FAB
        Semantics(
          label: 'Opciones de capas del mapa',
          child: FloatingActionButton(
            heroTag: 'layers',
            onPressed: _showLayersOptions,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.layers_rounded),
          ),
        ),
        const SizedBox(height: 12),
        
        // Recenter FAB
        Semantics(
          label: 'Centrar mapa en mi ubicación',
          child: FloatingActionButton(
            heroTag: 'recenter',
            onPressed: _recenterToUser,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
        const SizedBox(height: 12),
        
        // Settings FAB
        Semantics(
          label: 'Configuración y filtros',
          child: FloatingActionButton(
            heroTag: 'settings',
            onPressed: _showSettingsOptions,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textSecondary,
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }
}

/// Pure function to calculate distance between two points using Haversine formula
/// Unit-tested-ready, pure and reusable
double _haversineKm(LatLng point1, LatLng point2) {
  const double earthRadiusKm = 6371.0;
  
  final double lat1Rad = point1.latitude * (pi / 180);
  final double lat2Rad = point2.latitude * (pi / 180);
  final double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
  final double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

  final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
      cos(lat1Rad) * cos(lat2Rad) *
      sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
  
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  
  return earthRadiusKm * c;
}

// TODO: Export visits to Firestore for BQ-T5 hotspots