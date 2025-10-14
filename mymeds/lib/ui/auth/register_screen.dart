import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

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

    // Additional validation
    if (_claveController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La contraseña debe tener al menos 6 caracteres")),
      );
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_correoController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingresa un correo electrónico válido")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.registerWithEmailAndPassword(
        email: _correoController.text.trim(),
        password: _claveController.text,
        fullName: _nombreController.text.trim(),
        phoneNumber: _telefonoController.text.trim(),
        address: _direccionController.text.trim(),
        city: _ciudadController.text.trim(),
        department: _departamentoController.text.trim(),
        zipCode: _codigoZipController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Cuenta creada con éxito! Ahora puedes iniciar sesión."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? "Error al crear la cuenta"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error inesperado: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
