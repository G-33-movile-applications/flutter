import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medical_File_Upload"),
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
            const Text(
              "UPLOAD PRESCRIPTION",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Lorem ipsum dolor sit amet lorem ipsum dolor sit amet",
              textAlign: TextAlign.center,
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
                    color: Colors.black,
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
                  backgroundColor: Colors.black,
                ),
                child: const Text(
                  "UPLOAD",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Indicador de progreso
            if (isUploading)
              const CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 3,
              ),
          ],
        ),
      ),
    );
  }
}
