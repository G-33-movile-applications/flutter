import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/punto_fisico.dart';
import '../../models/prescripcion.dart';
import '../widgets/connectivity_feedback_banner.dart';
import 'widgets/pharmacy_marker_sheet.dart';
import '../pharmacy/pharmacy_inventory_page.dart';
import 'package:provider/provider.dart'; 
import '../../providers/motion_provider.dart';
import '../widgets/driving_overlay.dart';

class MapScreen extends StatefulWidget {
  final Prescripcion? prescripcion; // Optional: if user is selecting pharmacy for a prescription
  
  const MapScreen({super.key, this.prescripcion});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;
  List<PuntoFisico> _nearbyPharmacies = [];
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
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
      
      // Setup Firestore stream to listen for pharmacy data
      _setupFirestoreListener();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'No pudimos obtener tu ubicación. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  void _setupFirestoreListener() {
    _firestoreSubscription = _firestore
        .collection('puntosFisicos')
        .snapshots()
        .listen(
      (snapshot) {
        final allPharmacies = snapshot.docs
            .map((doc) => PuntoFisico.fromMap(doc.data(), documentId: doc.id))
            .toList();
        
        _filterNearbyPharmacies(allPharmacies);
        _createMarkers();
      },
      onError: (error) {
        setState(() {
          _errorMessage = 'Error al cargar las farmacias. Inténtalo de nuevo.';
          _isLoading = false;
        });
      },
    );
  }

  void _filterNearbyPharmacies(List<PuntoFisico> allPharmacies) {
    if (_currentPosition == null) return;

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    _nearbyPharmacies = allPharmacies
        .where((pharmacy) {
          final pharmacyLocation = LatLng(pharmacy.latitud, pharmacy.longitud);
          final distance = _haversineKm(userLocation, pharmacyLocation);
          return distance <= 100.0; // Only pharmacies within 100km for testing
        })
        .toList()
      ..sort((a, b) {
        final locationA = LatLng(a.latitud, a.longitud);
        final locationB = LatLng(b.latitud, b.longitud);
        final distanceA = _haversineKm(userLocation, locationA);
        final distanceB = _haversineKm(userLocation, locationB);
        return distanceA.compareTo(distanceB);
      });

    // Take only the 3 nearest pharmacies
    if (_nearbyPharmacies.length > 3) {
      _nearbyPharmacies = _nearbyPharmacies.take(3).toList();
    }
  }

  void _createMarkers() {
    if (_currentPosition == null) return;

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final Set<Marker> markers = {};

    for (final pharmacy in _nearbyPharmacies) {
      final pharmacyLocation = LatLng(pharmacy.latitud, pharmacy.longitud);
      final distance = _haversineKm(userLocation, pharmacyLocation);
      
      markers.add(
        Marker(
          markerId: MarkerId(pharmacy.id),
          position: pharmacyLocation,
          infoWindow: InfoWindow(
            title: pharmacy.nombre,
            snippet: '${pharmacy.nombre} • ${distance.toStringAsFixed(1)} km',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _showPharmacyDetails(pharmacy, distance),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _isLoading = false;
    });
  }

  void _showPharmacyDetails(PuntoFisico pharmacy, double distance) {
    final isSelectionMode = widget.prescripcion != null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PharmacyMarkerSheet(
        pharmacy: pharmacy,
        distance: distance,
        onDelivery: () => _goToDelivery(pharmacy),
        onViewInventory: () => _viewInventory(pharmacy),
        onSelect: isSelectionMode ? () => _selectPharmacy(pharmacy) : null,
      ),
    );
  }

  void _selectPharmacy(PuntoFisico pharmacy) {
    // Return the selected pharmacy to the previous screen
    Navigator.pop(context); // Close bottom sheet
    Navigator.pop(context, pharmacy); // Return pharmacy to home screen
  }

  void _goToDelivery(PuntoFisico pharmacy) {
    Navigator.pushNamed(
      context,
      '/delivery',
      arguments: pharmacy,
    );
  }



  void _viewInventory(PuntoFisico pharmacy) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PharmacyInventoryPage(pharmacy: pharmacy),
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
    final motionProvider = context.watch<MotionProvider>();
    final isDriving = motionProvider.isDriving;

    return Scaffold(
     backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('MAPA')),
      body: Stack(
        children: [
          _buildBody(),
          if (isDriving)
            DrivingOverlay(
              customMessage: "Por tu seguridad, el mapa está bloqueado mientras conduces.",
              customIcon: Icons.directions_car_filled,
              useBlur: true,
            ),
        ],
      ),
      floatingActionButton: isDriving ? null : _buildFABStack(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Column(
        children: [
          const ConnectivityFeedbackBanner(),
          Expanded(
            child: Center(
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
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          const ConnectivityFeedbackBanner(),
          Expanded(
            child: Center(
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
            ),
          ),
        ],
      );
    }

    if (_currentPosition == null) {
      return Column(
        children: [
          const ConnectivityFeedbackBanner(),
          Expanded(
            child: Center(
              child: Text(
                'No se pudo obtener la ubicación',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const ConnectivityFeedbackBanner(),
        Expanded(
          child: GoogleMap(
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
          ),
        ),
      ],
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
            backgroundColor: Theme.of(context).colorScheme.surface,
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
            backgroundColor: Theme.of(context).colorScheme.surface,
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