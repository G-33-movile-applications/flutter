import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.overline,
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.onPressed,
  });

  final String overline;
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with texts and icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overline
                    Text(
                      overline.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right side - icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Button row
          Row(
            children: [
              Semantics(
                label: '$buttonText para $title',
                child: ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// TODO: add golden test for light/dark