import 'package:flutter/material.dart';
import '../../models/punto_fisico.dart';
import '../../services/favorites_service.dart';

/// Favorite toggle button widget for pharmacy cards/lists
/// 
/// Features:
/// - Heart icon that toggles between filled/unfilled
/// - Smooth animation on state change
/// - Offline-first with instant feedback
/// - Automatic persistence and sync
class FavoriteHeartButton extends StatefulWidget {
  final PuntoFisico pharmacy;
  final double size;
  final Color? favoriteColor;
  final Color? inactiveColor;
  final Function(bool isFavorite)? onToggle;

  const FavoriteHeartButton({
    super.key,
    required this.pharmacy,
    this.size = 24,
    this.favoriteColor,
    this.inactiveColor,
    this.onToggle,
  });

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  final FavoritesService _favoritesService = FavoritesService();
  bool _isFavorite = false;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final isFavorite = await _favoritesService.isFavorite(widget.pharmacy.id);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading favorite status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      // Optimistic update
      setState(() => _isFavorite = !_isFavorite);

      // Play animation
      await _animationController.forward();
      await _animationController.reverse();

      // Persist change
      final newStatus = await _favoritesService.toggleFavorite(widget.pharmacy);
      
      // Verify state matches
      if (mounted && newStatus != _isFavorite) {
        setState(() => _isFavorite = newStatus);
      }

      // Callback
      widget.onToggle?.call(_isFavorite);

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite
                  ? '❤️ ${widget.pharmacy.nombre} agregada a favoritos'
                  : '💔 ${widget.pharmacy.nombre} removida de favoritos',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: _isFavorite ? Colors.pink : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      
      // Revert optimistic update on error
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Error al actualizar favorito'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultFavoriteColor = widget.favoriteColor ?? Colors.pink;
    final defaultInactiveColor = widget.inactiveColor ?? Colors.grey[400];

    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          size: widget.size,
          color: _isFavorite ? defaultFavoriteColor : defaultInactiveColor,
        ),
        onPressed: _toggleFavorite,
        tooltip: _isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
      ),
    );
  }
}

/// Compact favorite heart icon (for inline use in cards)
class CompactFavoriteHeart extends StatefulWidget {
  final PuntoFisico pharmacy;
  final double size;

  const CompactFavoriteHeart({
    super.key,
    required this.pharmacy,
    this.size = 20,
  });

  @override
  State<CompactFavoriteHeart> createState() => _CompactFavoriteHeartState();
}

class _CompactFavoriteHeartState extends State<CompactFavoriteHeart> {
  final FavoritesService _favoritesService = FavoritesService();
  bool _isFavorite = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final isFavorite = await _favoritesService.isFavorite(widget.pharmacy.id);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      setState(() => _isFavorite = !_isFavorite);
      await _favoritesService.toggleFavorite(widget.pharmacy);
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return InkWell(
      onTap: _toggleFavorite,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          size: widget.size,
          color: _isFavorite ? Colors.pink : Colors.grey[400],
        ),
      ),
    );
  }
}
