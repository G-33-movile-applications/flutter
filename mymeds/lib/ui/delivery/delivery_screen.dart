import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

  String _getRecommendation() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Recomendación: Recoger en farmacia";
    } else {
      return "Recomendación: Entrega a domicilio";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "DELIVERY",
          style: GoogleFonts.poetsenOne(
            textStyle: theme.textTheme.headlineMedium,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Imagen placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage("delivery_image.avif"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Texto de recomendación
            Text(
              _getRecommendation(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poetsenOne(
                fontSize: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),

            // Texto explicativo
            Text(
              "Puedes elegir si deseas recoger tu pedido directamente en la farmacia seleccionada o recibirlo en la dirección indicada. El tiempo de entrega puede variar según la opción seleccionada.",
              textAlign: TextAlign.center,
              style: GoogleFonts.balsamiqSans(fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Selección de farmacia
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Farmacia seleccionada",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: "Farmacia A", child: Text("Farmacia A")),
                DropdownMenuItem(value: "Farmacia B", child: Text("Farmacia B")),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),

            // Selección de receta
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Receta seleccionada",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: "Receta 1", child: Text("Receta 1")),
                DropdownMenuItem(value: "Receta 2", child: Text("Receta 2")),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 30),

            // Botón de aceptar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1D5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pedido confirmado")),
                  );
                },
                child: Text(
                  "ACCEPT",
                  style: GoogleFonts.poetsenOne(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
