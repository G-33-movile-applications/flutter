  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../../services/auth_service.dart';
  import '../../models/user_preferencias.dart';

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
    final _codigoZipController = TextEditingController();

    String? _selectedDepartamento;
    String? _selectedCiudad;
    

    String _modoEntregaPreferido = "domicilio"; // default

    bool _isLoading = false;
    bool _aceptaTerminos = false;
    bool _aceptaNotificaciones = false;
    bool _showPassword = false;

    // Departamentos y ciudades válidas
    final Map<String, List<String>> _ciudadesPorDepartamento = {
      "Cundinamarca": ["Mosquera", "Soacha", "Chía", "Funza"],
      "Bogotá D.C.": ["Bogotá"],
      "Antioquia": ["Medellín", "Bello", "Envigado", "Itagüí"],
    };

    Future<void> _register() async {
      if (!_formKey.currentState!.validate()) return;

      if (!_aceptaTerminos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Debes aceptar los términos y condiciones")),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {

        final userPrefs = UserPreferencias(
          modoEntregaPreferido: _modoEntregaPreferido,
          notificaciones: _aceptaNotificaciones,
        );

        final result = await AuthService.registerWithEmailAndPassword(
          email: _correoController.text.trim(),
          password: _claveController.text.trim(),
          fullName: _nombreController.text.trim(),
          phoneNumber: _telefonoController.text.trim(),
          address: _direccionController.text.trim(),
          city: _selectedCiudad ?? '',
          department: _selectedDepartamento ?? '',
          zipCode: _codigoZipController.text.trim(),
          preferencias: userPrefs,
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
        if (mounted) setState(() => _isLoading = false);
      }
    }

    bool _onlySpaces(String? v) => v == null || v.trim().isEmpty;
    
    String? direccionValidator(String? v) {
      
      if (v == null || v.trim().isEmpty) return "Campo requerido";

      v = v.trim();

      // Length check
      if (v.length < 5) return "Dirección demasiado corta";
      if (v.length > 80) return "Dirección demasiado larga";

      // Forbidden characters (emojis, symbols)
      final forbidden = RegExp(r'[^\w\s#\-\.,°ºáéíóúÁÉÍÓÚñÑ]');
      if (forbidden.hasMatch(v)) {
        return "La dirección contiene caracteres inválidos";
      }

      // Must contain both letters and numbers
      final hasLetters = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(v);
      final hasNumbers = RegExp(r'\d').hasMatch(v);
      if (!hasLetters || !hasNumbers) {
        return "Debe incluir letras y números (ej. Calle 10 #5-20)";
      }

      // Should have at least two parts (e.g. “Calle 10”)
      if (!v.contains(" ")) return "Dirección incompleta";

      // Optional: Colombian-style format (Calle, Carrera, Transversal, etc.)
      final colombianPattern =
          RegExp(r'^(?:(?:Calle|Cll|Carrera|Cra|Kra|Kr|Avenida|Av|Ak|Transversal|Transv|Tv|Diagonal|Dg)\s+\d+[A-Za-z]?(?:\s+(?:bis))?(?:\s+[A-Za-z])?(?:\s+(?:Norte|Sur|Este|Oeste))?(?:\s*(?:#|No\.?|Nº|n\.º|nº|n°)\s*\d+[A-Za-z]?(?:-\d+[A-Za-z]?)?)?(?:\s+(?:Norte|Sur|Este|Oeste))?\s*)$', caseSensitive: false);
      if (!colombianPattern.hasMatch(v)) {
        return "Formato de dirección no válido (ej. Calle 45 #12-30)";
      }

      return null; //All good
    }
    String? codigoPostalValidator(String? v) {
      if (v == null || v.trim().isEmpty) return "Campo requerido";
      v = v.trim();

      // Must be 4 to 6 digits only
      if (!RegExp(r'^\d{4,6}$').hasMatch(v)) {
        return "Debe tener entre 4 y 6 dígitos numéricos";
      }

      // Valid Colombian department prefixes
      const validPrefixes = {
        '11', '91', '05', '08', '13', '15', '17', '18', '81', '85', '19', '20',
        '23', '25', '94', '95', '41', '44', '47', '50', '52', '54', '86', '63',
        '66', '88', '68', '70', '73', '76', '97', '99'
      };

      final prefix = v.substring(0, 2);

      if (!validPrefixes.contains(prefix)) {
        return "Código postal no válido en Colombia \n (prefijo desconocido)";
      }

      return null; //All good
    }
    
    String? passwordValidator(String? v) {
      if (v == null || v.trim().isEmpty) return "Campo requerido";
      v = v.trim();

      // Length requirement
      if (v.length < 8) return "Mínimo 8 caracteres";

      // Allowed characters only (letters, numbers, limited symbols)
      final allowedChars = RegExp(r'^[A-Za-z0-9#@!\$%&/()=?¿\+\*\-_\.,:;]+$');
      if (!allowedChars.hasMatch(v)) {
        return "Contiene caracteres no permitidos";
      }

      // Must have at least one letter, one number, and one symbol
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
      final hasNumber = RegExp(r'\d').hasMatch(v);
      final hasSymbol = RegExp(r'[#@!\$%&/()=?¿\+\*\-_\.,:;]').hasMatch(v);

      if (!hasLetter || !hasNumber || !hasSymbol) {
        return "Debe incluir letras, números y símbolos (#@!\$%&/...)";
      }

      return null; //All good
    }

    void _showTermsDialog() {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Términos y Condiciones"),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: SingleChildScrollView(
                  child: Text(
                    '''
  Al registrarte y continuar con el uso de esta aplicación, declaras haber leído y aceptado los siguientes términos:

  1️⃣ **Uso de datos personales:**  
  Autorizas a la aplicación a recopilar, almacenar y procesar tus datos personales necesarios para el funcionamiento del servicio, incluyendo nombre, número de identificación, dirección, ubicación geográfica y datos de contacto.

  2️⃣ **Datos médicos y prescripciones:**  
  La aplicación podrá manejar información sobre tus prescripciones médicas, medicamentos y farmacias asociadas, exclusivamente con el fin de facilitar el proceso de entrega y verificación de los pedidos.

  3️⃣ **Ubicación:**  
  Tu ubicación podrá ser utilizada para asignar entregas, calcular tiempos de envío y mostrar farmacias cercanas.

  4️⃣ **Notificaciones:**  
  Podrás recibir notificaciones sobre el estado de tus pedidos, actualizaciones del servicio y recordatorios de entregas. Puedes modificar esta preferencia en cualquier momento.

  5️⃣ **Confidencialidad:**  
  Nos comprometemos a proteger tu información conforme a las normas vigentes de protección de datos personales. No compartiremos tu información con terceros sin tu consentimiento, salvo requerimiento legal.

  6️⃣ **Responsabilidad del usuario:**  
  Eres responsable de proporcionar información veraz y de mantener la confidencialidad de tus credenciales de acceso.

  Al aceptar estos términos, confirmas que entiendes y consientes el tratamiento de tus datos con los fines descritos anteriormente.
                    ''',
                    style: GoogleFonts.balsamiqSans(fontSize: 14),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ],
            ),
          );
        }
    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);

      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'REGISTRAR',
                    style: GoogleFonts.poetsenOne(
                      textStyle: theme.textTheme.headlineMedium,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nombre
                  _buildStyledField(
                    "Nombre completo",
                    _nombreController,
                    validator: (v) {
                      if (_onlySpaces(v)) return "Campo requerido";
                      v = v!.trim();
                      if (!RegExp(r"^[a-zA-ZÀ-ÿ\s]+$").hasMatch(v)) {
                        return "Solo letras (sin símbolos o emojis)";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _buildStyledField(
                    "Correo electrónico",
                    _correoController,
                    type: TextInputType.emailAddress,
                    hint: "ejemplo@mail.com",
                    validator: (v) {
                      if (_onlySpaces(v)) return "Campo requerido";
                      v = v!.trim();
                      if (!RegExp(r'^[\w\.\-]+@[a-zA-Z\d\-]+\.[a-zA-Z]{2,}$').hasMatch(v)) {
                        return "Correo electrónico inválido";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contraseña
                  _buildStyledField(
                    "Contraseña",
                    _claveController,
                    isPassword: true,
                    showPasswordToggle: true,
                    hint: "Mínimo 8 caracteres, incluye letras, números y símbolos (#@!\$%&/...)",
                    validator: passwordValidator,
                  ),
                  const SizedBox(height: 16),

                  // Teléfono
                  _buildStyledField(
                    "Número de teléfono",
                    _telefonoController,
                    type: TextInputType.phone,
                    validator: (v) {
                      if (_onlySpaces(v)) return "Campo requerido";
                      v = v!.trim();
                      if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                        return "Solo dígitos, sin símbolos";
                      }
                      if (v.length < 7 || v.length > 16) return "Teléfono inválido";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dirección
                  _buildStyledField(
                    "Dirección de residencia",
                    _direccionController,
                    validator:direccionValidator,
                  ),
                  const SizedBox(height: 16),

                  // Departamento
                  DropdownButtonFormField<String>(
                    value: _selectedDepartamento,
                    decoration: _dropdownDecoration("Departamento de residencia"),
                    items: _ciudadesPorDepartamento.keys
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedDepartamento = v;
                        _selectedCiudad = null;
                      });
                    },
                    validator: (v) => v == null ? "Selecciona un departamento" : null,
                  ),
                  const SizedBox(height: 16),

                  // Ciudad (dependiente)
                  DropdownButtonFormField<String>(
                    value: _selectedCiudad,
                    decoration: _dropdownDecoration("Ciudad de residencia"),
                    items: (_selectedDepartamento != null)
                        ? _ciudadesPorDepartamento[_selectedDepartamento]!
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList()
                        : [],
                    onChanged: (v) => setState(() => _selectedCiudad = v),
                    validator: (v) => v == null ? "Selecciona una ciudad" : null,
                  ),
                  const SizedBox(height: 16),

                  // Código ZIP
                  _buildStyledField(
                    "Código ZIP",
                    _codigoZipController,
                    type: TextInputType.number,
                    validator: codigoPostalValidator,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _modoEntregaPreferido,
                    decoration: _dropdownDecoration("Forma preferida de entrega"),
                    items: const [
                      DropdownMenuItem(value: "domicilio", child: Text("Domicilio")),
                      DropdownMenuItem(value: "recogida", child: Text("Recogida en tienda")),
                    ],
                    onChanged: (v) => setState(() => _modoEntregaPreferido = v ?? "domicilio"),
                  ),
                  const SizedBox(height: 24),
                  // Botón registrar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              'REGISTRAR',
                              style: GoogleFonts.poetsenOne(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    "Al registrarte aceptas nuestros términos de servicio y políticas de privacidad.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    title: Row(
                      children: [
                        Text("Acepto ", style: GoogleFonts.balsamiqSans()),
                        GestureDetector(
                          onTap: _showTermsDialog,
                          child: Text(
                            "términos y condiciones",
                            style: GoogleFonts.balsamiqSans(
                              decoration: TextDecoration.underline,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    value: _aceptaTerminos,
                    onChanged: (val) => setState(() => _aceptaTerminos = val!),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: Text(
                      "Acepto recibir notificaciones",
                      style: GoogleFonts.balsamiqSans(
                        color: theme.colorScheme.onSurface,
                      ),
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

    // Helpers
    Widget _buildStyledField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool showPasswordToggle = false,
    TextInputType type = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !(_showPassword),
      keyboardType: type,
      style: GoogleFonts.balsamiqSans(
        color: theme.textTheme.bodyLarge?.color,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.primary,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        // Show suffix icon only when requested and for password fields
        suffixIcon: (isPassword && showPasswordToggle)
            ? IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: theme.iconTheme.color,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
      ),
    );
  }


    InputDecoration _dropdownDecoration(String label) {
      final theme = Theme.of(context);
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.primary,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
      );
    }
  }
