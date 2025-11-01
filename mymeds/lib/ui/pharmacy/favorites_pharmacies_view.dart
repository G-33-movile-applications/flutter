import 'package:flutter/material.dart';
import '../../models/favorite_pharmacy.dart';
import '../../models/punto_fisico.dart';
import '../../services/favorites_service.dart';
import '../../repositories/punto_fisico_repository.dart';
import '../../widgets/favorite_heart_button.dart';

/// Favorites Pharmacies View
/// 
/// Shows user's favorite pharmacies and frequent pharmacies
/// Features:
/// - Offline-first display
/// - Tabbed interface (Favorites / Frequent)
/// - Pull-to-refresh for sync
/// - Empty states
class FavoritesPharmaciesView extends StatefulWidget {
  const FavoritesPharmaciesView({super.key});

  @override
  State<FavoritesPharmaciesView> createState() => _FavoritesPharmaciesViewState();
}

class _FavoritesPharmaciesViewState extends State<FavoritesPharmaciesView>
    with SingleTickerProviderStateMixin {
  final FavoritesService _favoritesService = FavoritesService();
  final PuntoFisicoRepository _pharmacyRepo = PuntoFisicoRepository();
  
  late TabController _tabController;
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  List<FavoritePharmacy> _favorites = [];
  List<FavoritePharmacy> _frequent = [];
  
  // Cache for full pharmacy data
  final Map<String, PuntoFisico> _pharmacyCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      // Load favorites and frequent from local database
      final favorites = await _favoritesService.getFavorites();
      final frequent = await _favoritesService.getFrequentPharmacies(limit: 20);

      if (mounted) {
        setState(() {
          _favorites = favorites;
          _frequent = frequent;
          _isLoading = false;
          _isRefreshing = false;
        });

        // Preload full pharmacy data
        _preloadPharmacyData();
      }

      // Sync from Firestore in background if force refresh
      if (forceRefresh) {
        await _favoritesService.syncFromFirestore();
        // Reload after sync
        _loadData();
      }
    } catch (e) {
      debugPrint('❌ Error loading favorites: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _preloadPharmacyData() async {
    // Get unique pharmacy IDs
    final pharmacyIds = {..._favorites, ..._frequent}
        .map((f) => f.pharmacyId)
        .toSet();

    for (final pharmacyId in pharmacyIds) {
      if (!_pharmacyCache.containsKey(pharmacyId)) {
        try {
          final pharmacy = await _pharmacyRepo.read(pharmacyId);
          if (pharmacy != null && mounted) {
            setState(() {
              _pharmacyCache[pharmacyId] = pharmacy;
            });
          }
        } catch (e) {
          debugPrint('⚠️ Failed to load pharmacy $pharmacyId: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Farmacias Favoritas'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.favorite),
              text: 'Favoritas (${_favorites.length})',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'Frecuentes (${_frequent.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFavoritesTab(isDark),
                _buildFrequentTab(isDark),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildFavoritesTab(bool isDark) {
    if (_favorites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'Sin favoritas',
        message: 'Toca el corazón ❤️ en cualquier farmacia para agregarla a favoritos',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          final pharmacy = _pharmacyCache[favorite.pharmacyId];
          return _buildPharmacyCard(favorite, pharmacy, isDark);
        },
      ),
    );
  }

  Widget _buildFrequentTab(bool isDark) {
    if (_frequent.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Sin historial',
        message: 'Realiza pedidos en farmacias para verlas aquí',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _frequent.length,
        itemBuilder: (context, index) {
          final favorite = _frequent[index];
          final pharmacy = _pharmacyCache[favorite.pharmacyId];
          return _buildPharmacyCard(favorite, pharmacy, isDark, showVisits: true);
        },
      ),
    );
  }

  Widget _buildPharmacyCard(
    FavoritePharmacy favorite,
    PuntoFisico? pharmacy,
    bool isDark, {
    bool showVisits = false,
  }) {
    final displayName = pharmacy?.nombre ?? favorite.pharmacyName ?? 'Cargando...';
    final displayAddress = pharmacy?.direccion ?? favorite.pharmacyAddress ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: pharmacy != null
            ? () => _showPharmacyDetails(pharmacy)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Pharmacy icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.local_pharmacy,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Pharmacy info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (displayAddress.isNotEmpty)
                      Text(
                        displayAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (showVisits && favorite.visitsCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${favorite.visitsCount} ${favorite.visitsCount == 1 ? 'pedido' : 'pedidos'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Favorite heart button
              if (pharmacy != null)
                CompactFavoriteHeart(
                  pharmacy: pharmacy,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPharmacyDetails(PuntoFisico pharmacy) {
    // Navigate to pharmacy details or show bottom sheet
    // This can be customized based on your navigation structure
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Title
                Text(
                  pharmacy.nombre,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildDetailRow('Dirección', pharmacy.direccion, Icons.location_on, isDark),
                if (pharmacy.telefono != null)
                  _buildDetailRow('Teléfono', pharmacy.telefono!, Icons.phone, isDark),
                if (pharmacy.horario != null)
                  _buildDetailRow('Horario', pharmacy.horario!, Icons.schedule, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
