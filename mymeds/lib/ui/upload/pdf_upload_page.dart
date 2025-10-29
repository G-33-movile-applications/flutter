import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/motion_provider.dart';
import '../../repositories/pdf_repository.dart';
import '../widgets/driving_overlay.dart';
import 'widget/upload_prescription_widget.dart';

class PdfUploadPage extends StatefulWidget {
  const PdfUploadPage({super.key});

  @override
  State<PdfUploadPage> createState() => _PdfUploadPageState();
}

class _PdfUploadPageState extends State<PdfUploadPage> {
  bool isUploading = false;
  final List<File> selectedFiles = [];
  final List<String> processedTexts = [];
  final PdfRepository _pdfRepository = PdfRepository(userId: 'user123'); // TODO: Usar ID real del usuario

  /// Selección de archivo PDF
  Future<void> _selectFile() async {
    // Verificar si ya hay 5 archivos seleccionados
    if (selectedFiles.length >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No puedes seleccionar más de 5 prescripciones a la vez"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      // Calcular cuántos archivos podemos agregar
      final remainingSlots = 5 - selectedFiles.length;
      final filesToAdd = result.files.take(remainingSlots).toList();

      setState(() {
        for (final file in filesToAdd) {
          if (file.path != null) {
            selectedFiles.add(File(file.path!));
          }
        }
      });

      if (!mounted) return;
      
      if (result.files.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Se seleccionaron ${filesToAdd.length} archivo(s). No se pueden agregar más de 5 prescripciones."),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${filesToAdd.length} archivo(s) seleccionado(s)"),
          ),
        );
      }
    }
  }

  /// Procesar y subir PDFs
  Future<void> _startUpload() async {
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, selecciona al menos un archivo")),
      );
      return;
    }

    setState(() {
      isUploading = true;
      processedTexts.clear();
    });

    try {
      // Procesar PDFs y guardar medicamentos
      final medications = await _pdfRepository.processPrescriptionPdfs(selectedFiles);

      if (!mounted) return;

      setState(() {
        isUploading = false;
        selectedFiles.clear();
      });

      // Mostrar resultado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Se procesaron ${medications.length} medicamento(s) correctamente"),
          backgroundColor: Colors.green,
        ),
      );

      // Navegar a la lista de medicamentos
      Navigator.pushReplacementNamed(context, '/medications');

    } catch (e) {
      setState(() {
        isUploading = false;
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error procesando PDFs: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<MotionProvider>(
      builder: (context, motionProvider, child) {
        final isDriving = motionProvider.isDriving;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              "Medical_File_Upload",
              style: theme.appBarTheme.titleTextStyle,
            ),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.more_vert),
            ],
          ),
          drawer: const Drawer(),
          body: Stack(
            children: [
              // Main content
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    UploadPrescriptionWidget(
                      isUploading: isUploading,
                      onSelectFile: _selectFile,
            onUpload: _startUpload, // usamos la función ya preparada
                    ),
                    const SizedBox(height: 20),

        // 🔹 Lista de archivos seleccionados
                    if (selectedFiles.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Archivos seleccionados:",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...selectedFiles.map(
                            (file) => ListTile(
                              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              title: Text(
                                file.path.split(Platform.pathSeparator).last,
                                style: theme.textTheme.bodyMedium,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    selectedFiles.remove(file);
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    if (processedTexts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: processedTexts
                              .map((text) => Text(
                                    text,
                                    style: const TextStyle(fontSize: 12),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),

              // Driving overlay
              if (isDriving)
                DrivingOverlay(
                  customMessage: "Por seguridad, no puedes subir prescripciones mientras conduces.",
                ),
            ],
          ),
        );
      },
    );
  }
}