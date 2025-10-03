import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class UploadPrescriptionPage extends StatefulWidget {
  const UploadPrescriptionPage({super.key});

  @override
  State<UploadPrescriptionPage> createState() => _UploadPrescriptionPageState();
}

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> {
  bool isUploading = false; // para controlar el indicador de carga

  void startUpload() {
    setState(() {
      isUploading = true;
    });

    // Simulación de carga de archivo
    Future.delayed(const Duration(seconds: 3), () {
    if (!mounted) return; 

    setState(() {
      isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Archivo subido exitosamente ")),
    );
    });

  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Medical_File_Upload",
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: const [
          Icon(Icons.home_outlined),
          SizedBox(width: 10),
          Icon(Icons.more_vert),
        ],
      ),
      drawer: const Drawer(), // menú lateral
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
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
              "Selecciona tu archivo de prescripción médica para subirlo y procesarlo.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 30),

            // Botón circular para seleccionar archivo
            Center(
              child: InkWell(
                onTap: () {
                  // Aquí iría lógica para seleccionar archivo
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Seleccionar archivo")),
                  );
                },
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
                onPressed: startUpload,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: AppTheme.buttonBackgroundColor,
                  foregroundColor: AppTheme.buttonTextColor,
                  textStyle: theme.textTheme.titleMedium,
                ),
                child: const Text(
                  "UPLOAD",
                  // El color de texto lo da foregroundColor
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Indicador de progreso
            if (isUploading)
              const CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
          ],
        ),
      ),
    );
  }
}
