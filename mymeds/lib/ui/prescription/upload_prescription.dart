import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../upload/widget/upload_prescription_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';


class UploadPrescriptionPage extends StatefulWidget {
  const UploadPrescriptionPage({super.key});

  @override
  State<UploadPrescriptionPage> createState() => _UploadPrescriptionPageState();
}

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> {
  bool isUploading = false;

  Future<void> startUpload() async {
    setState(() => isUploading = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.bytes != null) {
        // Convertir el archivo PDF a base64 para JSON
        String base64Pdf = base64Encode(result.files.single.bytes!);
        Map<String, dynamic> jsonData = {
          'fileName': result.files.single.name,
          'fileBytesBase64': base64Pdf,
        };
        String jsonString = jsonEncode(jsonData);
        // jsonString a un backend o guardarlo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF convertido a JSON correctamente")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se seleccionó ningún archivo PDF")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
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
      drawer: const Drawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: UploadPrescriptionWidget(
          onUpload: startUpload,
          isUploading: isUploading,
        ),
      ),
    );
  }
}
