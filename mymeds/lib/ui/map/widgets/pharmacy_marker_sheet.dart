import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/punto_fisico.dart';

class PharmacyMarkerSheet extends StatelessWidget {
  const PharmacyMarkerSheet({
    super.key,
    required this.pharmacy,
    required this.distance,
    required this.onNavigate,
    required this.onViewInventory,
  });

  final PuntoFisico pharmacy;
  final double distance;
  final VoidCallback onNavigate;
  final VoidCallback onViewInventory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  pharmacy.nombre,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle row - chain and distance
                Row(
                  children: [
                    Text(
                      pharmacy.cadena,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' • ${distance.toStringAsFixed(1)} km',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Address row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pharmacy.direccion,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Navegar a ${pharmacy.nombre}',
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onNavigate();
                          },
                          icon: const Icon(Icons.directions_rounded),
                          label: const Text('Navegar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Ver inventario de ${pharmacy.nombre}',
                        child: ElevatedButton.icon(
                          onPressed: onViewInventory,
                          icon: const Icon(Icons.inventory_2_rounded),
                          label: const Text('Ver inventario'),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Safe area padding for bottom
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}