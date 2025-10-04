import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class UploadPrescriptionWidget extends StatelessWidget {
  final VoidCallback? onSelectFile;
  final VoidCallback? onUpload;
  final bool isUploading;

  const UploadPrescriptionWidget({
    super.key,
    this.onSelectFile,
    this.onUpload,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          "UPLOAD PRESCRIPTION",
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Selecciona tu archivo de prescripción médica para subirlo.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 30),

        // Botón circular para seleccionar archivo
        Center(
          child: InkWell(
            onTap: onSelectFile,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Botón rectangular para subir
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: AppTheme.buttonBackgroundColor,
              foregroundColor: AppTheme.buttonTextColor,
              textStyle: theme.textTheme.titleMedium,
            ),
            child: const Text("UPLOAD"),
          ),
        ),
        const SizedBox(height: 30),

        if (isUploading)
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
      ],
    );
  }
}
