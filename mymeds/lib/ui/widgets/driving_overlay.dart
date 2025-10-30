import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable overlay that blocks UI when driving mode is detected
/// Shows a warning message to prevent distracted driving
class DrivingOverlay extends StatelessWidget {
  final String? customMessage;
  final IconData? customIcon;
  final bool useBlur;
  
  const DrivingOverlay({
    super.key,
    this.customMessage,
    this.customIcon,
    this.useBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Colors.black.withOpacity(useBlur ? 0.5 : 0.6),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              customIcon ?? Icons.directions_car_rounded,
              color: Colors.white,
              size: customIcon == Icons.directions_car_filled ? 70 : 80,
            ),
            const SizedBox(height: 20),
            Text(
              "Modo conducción detectado",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              customMessage ??
                  "Por tu seguridad, esta funcionalidad está bloqueada mientras conduces.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
    
    return Positioned.fill(
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: content,
            )
          : content,
    );
  }
}
