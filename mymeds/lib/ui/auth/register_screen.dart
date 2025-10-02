import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _claveController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _codigoZipController = TextEditingController();

  bool _isLoading = false;
  bool _aceptaTerminos = false;
  bool _aceptaNotificaciones = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes aceptar los términos y condiciones")),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // 🔹 Simulación por ahora
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Usuario registrado con éxito")),
    );
    Navigator.pop(context);

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Título
                Text(
                  'REGISTRAR',
                  style: GoogleFonts.poetsenOne(
                    textStyle: theme.textTheme.headlineMedium,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Campos
                _buildStyledField("Nombre completo", _nombreController),
                const SizedBox(height: 16),
                _buildStyledField("Correo electrónico", _correoController,
                    type: TextInputType.emailAddress, hint: "ejemplo@mail.com"),
                const SizedBox(height: 16),
                _buildStyledField("Contraseña", _claveController,
                    isPassword: true, hint: "Mínimo 6 caracteres"),
                const SizedBox(height: 16),
                _buildStyledField("Número de teléfono", _telefonoController,
                    type: TextInputType.phone),
                const SizedBox(height: 16),
                _buildStyledField("Dirección de residencia", _direccionController),
                const SizedBox(height: 16),
                _buildStyledField("Ciudad de residencia", _ciudadController),
                const SizedBox(height: 16),
                _buildStyledField("Departamento de residencia", _departamentoController),
                const SizedBox(height: 16),
                _buildStyledField("Código ZIP", _codigoZipController,
                    type: TextInputType.number),
                const SizedBox(height: 24),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9EC6F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            'REGISTRAR',
                            style: GoogleFonts.poetsenOne(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Texto explicativo
                Text(
                  "Al registrarte aceptas nuestros términos de servicio y políticas de privacidad.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.balsamiqSans(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),

                // Checkboxes
                CheckboxListTile(
                  title: Text(
                    "Acepto términos y condiciones",
                    style: GoogleFonts.balsamiqSans(),
                  ),
                  value: _aceptaTerminos,
                  onChanged: (val) => setState(() => _aceptaTerminos = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text(
                    "Acepto recibir notificaciones",
                    style: GoogleFonts.balsamiqSans(),
                  ),
                  value: _aceptaNotificaciones,
                  onChanged: (val) => setState(() => _aceptaNotificaciones = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: type,
      style: GoogleFonts.balsamiqSans(),
      validator: (value) =>
          (value == null || value.isEmpty) ? "Campo requerido" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFFFF1D5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
