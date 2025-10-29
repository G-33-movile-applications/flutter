import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/motion_provider.dart';
import '../widgets/driving_overlay.dart';
import 'widget/upload_prescription_widget.dart';

class PdfUploadPage extends StatefulWidget {
  const PdfUploadPage({super.key});

  @override
  State<PdfUploadPage> createState() => _PdfUploadPageState();
}

class _PdfUploadPageState extends State<PdfUploadPage> {
  bool isUploading = false;
  String? selectedFileName;
  Map<String, dynamic>? pdfAsJson;
  List<String> selectedFiles = [];

  /// Selección de archivo PDF
  Future<void> _selectFile() async {
    if (selectedFiles.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Solo puedes subir un máximo de 3 prescripciones.")),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      setState(() {
        selectedFileName = fileName;
        selectedFiles.add(fileName);
      });

      // Convertir PDF a JSON
      await _convertPdfToJson(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Archivo seleccionado: $selectedFileName")),
      );
    }
  }

  /// Conversión PDF a JSON
  Future<void> _convertPdfToJson(String filePath) async {
    final fileBytes = File(filePath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: fileBytes);

    Map<String, dynamic> jsonData = {};

    for (int i = 0; i < document.pages.count; i++) {
      String pageText = PdfTextExtractor(document).extractText(startPageIndex: i);
      jsonData["page_${i + 1}"] = pageText;
    }

    document.dispose();

    setState(() {
      pdfAsJson = jsonData;
    });

    debugPrint("PDF en JSON: ${jsonEncode(jsonData)}");
  }

  void _startUpload() {
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, selecciona al menos un archivo.")),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

  // Simulación de "subida"
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Se subieron ${selectedFiles.length} archivo(s) correctamente."),
        ),
      );
    });
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
                          Row(
                            children: [
                              Text(
                                "Archivos seleccionados:",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "(${selectedFiles.length}/3)",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...selectedFiles.map(
                            (file) => ListTile(
                              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              title: Text(file, style: theme.textTheme.bodyMedium),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

      // Preview de JSON (del último archivo)
                    if (pdfAsJson != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          const JsonEncoder.withIndent("  ").convert(pdfAsJson),
                          style: const TextStyle(fontSize: 12),
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