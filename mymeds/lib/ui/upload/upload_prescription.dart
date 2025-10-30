import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/motion_provider.dart';
import '../widgets/driving_overlay.dart';

/// Main upload page that provides navigation to different upload methods
/// - PDF upload (traditional file upload)
/// - NFC upload (read/write prescriptions from NFC tags)
/// - Image OCR upload (extract text from prescription photos)
class UploadPrescriptionPage extends StatelessWidget {
  const UploadPrescriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDriving = context.watch<MotionProvider>().isDriving;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              "Cargar Prescripción",
              style: theme.appBarTheme.titleTextStyle,
            ),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
            ],
          ),
          body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Selecciona un Método',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige cómo deseas cargar tu prescripción médica',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // NFC Upload Card
            _buildUploadMethodCard(
              context: context,
              icon: Icons.nfc,
              title: 'Cargar por NFC',
              description: 'Lee o escribe prescripciones usando tags NFC',
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, '/upload/nfc'),
            ),

            const SizedBox(height: 16),

            // Image OCR Upload Card
            _buildUploadMethodCard(
              context: context,
              icon: Icons.camera_alt,
              title: 'Cargar por Imagen',
              description: 'Toma una foto o selecciona una imagen de tu prescripción',
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/upload/ocr'),
            ),

            const SizedBox(height: 16),

            // PDF Upload Card (Existing method)
            _buildUploadMethodCard(
              context: context,
              icon: Icons.picture_as_pdf,
              title: 'Cargar PDF',
              description: 'Selecciona un archivo PDF de tu prescripción',
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, '/upload/pdf'),
            ),

            const SizedBox(height: 40),

            // Help Section
            Card(
              color: Colors.blue.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Text(
                          '¿Necesitas ayuda?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem(
                      'NFC: Ideal para compartir prescripciones entre dispositivos',
                    ),
                    _buildHelpItem(
                      'Imagen: Extrae automáticamente los datos de la prescripción',
                    ),
                    _buildHelpItem(
                      'PDF: Sube archivos digitales de tu médico',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Todos los métodos guardan tus prescripciones de forma segura en la nube.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ),
        
        // Driving overlay
        if (isDriving)
          DrivingOverlay(
            customMessage: "Por seguridad, no puedes cargar prescripciones mientras conduces.",
          ),
      ],
    );
  }

  Widget _buildUploadMethodCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
