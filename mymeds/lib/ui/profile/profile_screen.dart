  import 'package:flutter/material.dart';
  import '../../models/user_model.dart';
  import '../../repositories/usuario_repository.dart';

  class ProfilePage extends StatefulWidget {
    final String uid; // ID del usuario logueado

    const ProfilePage({super.key, required this.uid});

    @override
    State<ProfilePage> createState() => _ProfilePageState();
  }

  class _ProfilePageState extends State<ProfilePage> {
    final UsuarioRepository _usuarioRepository = UsuarioRepository();
    final _formKey = GlobalKey<FormState>();

    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _phoneController = TextEditingController();
    final _addressController = TextEditingController();
    final _cityController = TextEditingController();
    final _departmentController = TextEditingController();
    final _zipCodeController = TextEditingController();

    bool _loading = true;
    bool _updating = false;
    bool _editable = false;
    bool _hasChanges = false;

    
    String _modoEntregaPreferido = "domicilio";
    bool _aceptaNotificaciones = false;
    UserModel? _user;
    UserModel? _originalUser;
    String? _selectedDepartamento;
    String? _selectedCiudad;

     // Departamentos y ciudades válidas
    final Map<String, List<String>> _ciudadesPorDepartamento = {
      "Cundinamarca": ["Mosquera", "Soacha", "Chía", "Funza"],
      "Bogotá D.C.": ["Bogotá"],
      "Antioquia": ["Medellín", "Bello", "Envigado", "Itagüí"],
    };

    @override
    void initState() {
      super.initState();
      _loadUser();
    }

    @override
    void dispose() {
      _nameController.dispose();
      _emailController.dispose();
      _phoneController.dispose();
      _addressController.dispose();
      _cityController.dispose();
      _departmentController.dispose();
      _zipCodeController.dispose();
      super.dispose();
    }

    void _markChanged() {
      if (!_hasChanges) {
        setState(() => _hasChanges = true);
      }
    }
    
    Future<void> _loadUser() async {
      try {
        final user = await _usuarioRepository.read(widget.uid);
        if (user != null) {
          setState(() {
            _user = user;
            _nameController.text = user.nombre;
            _emailController.text = user.email;
            _phoneController.text = user.telefono;
            _addressController.text = user.direccion;
            _cityController.text = user.city;
            _departmentController.text = user.department;
            _zipCodeController.text = user.zipCode;
            _modoEntregaPreferido = user.preferencias?.modoEntregaPreferido ?? "domicilio";
            _aceptaNotificaciones = user.preferencias?.notificaciones ?? false;
            _selectedDepartamento = user.department; 
            _selectedCiudad = user.city;
            _loading = false;
          }); 
          _originalUser = user.copyWith();
        }
      } catch (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading user: $e")),
        );
      }
    }
    // VALIDATORS
    
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


    Future<void> _updateUser() async {
      if (!_formKey.currentState!.validate()) return;
      if (_user == null) return;

      setState(() => _updating = true);

      try {
        final updatedUser = _user!.copyWith(
          nombre: _nameController.text.trim(),
          email: _emailController.text.trim(),
          telefono: _phoneController.text.trim(),
          direccion: _addressController.text.trim(),
          city: _cityController.text.trim(),
          department: _departmentController.text.trim(),
          zipCode: _zipCodeController.text.trim(),
          preferencias: _user!.preferencias?.copyWith(
              modoEntregaPreferido: _modoEntregaPreferido,
              notificaciones: _aceptaNotificaciones,
          ),
        );

        await _usuarioRepository.update(updatedUser);

        // Update controllers with trimmed values
        setState(() {
          _user = updatedUser;
          _originalUser = updatedUser.copyWith();
          
          // Update controllers to show trimmed values
          _nameController.text = updatedUser.nombre;
          _emailController.text = updatedUser.email;
          _phoneController.text = updatedUser.telefono;
          _addressController.text = updatedUser.direccion;
          _cityController.text = updatedUser.city;
          _departmentController.text = updatedUser.department;
          _zipCodeController.text = updatedUser.zipCode;
          
          _editable = false; // Return to read-only after saving
          _updating = false;
          _hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuario actualizado correctamente!")),
        );
      } catch (e) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar el usuario: $e")),
        );
      }
    }
    void _revertChanges() {
      if (_originalUser == null) return;
      setState(() {
        final u = _originalUser!;
        _nameController.text = u.nombre;
        _emailController.text = u.email;
        _phoneController.text = u.telefono;
        _addressController.text = u.direccion;
        _cityController.text = u.city;
        _departmentController.text = u.department;
        _zipCodeController.text = u.zipCode;
        _modoEntregaPreferido = u.preferencias?.modoEntregaPreferido ?? "domicilio";
        _aceptaNotificaciones = u.preferencias?.notificaciones ?? false;
        _selectedDepartamento = u.department;
        _selectedCiudad = u.city;
        _hasChanges = false;
      });
    }

    Widget _buildTextField({
      required String label,
      required TextEditingController controller,
      String? Function(String?)? validator,
      TextInputType type = TextInputType.text,
      bool enabled = true
    }) {
      final isEnabled = _editable;

      return TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: type,
        enabled: isEnabled && enabled, // Disable if not editable
        onChanged: (value) =>_markChanged(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87, // Always readable
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 14,
            color: isEnabled ? Colors.grey[700] : Colors.black54, // clearer when disabled
          ),
          filled: true,
          fillColor: isEnabled ? Colors.white : Colors.white, // no grey background when read-only
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isEnabled ? Colors.grey.shade400 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
      );
    }

    Future<bool> _confirmDiscardChanges() async {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Descartar cambios"),
          content:
              const Text("Tienes cambios sin guardar. ¿Deseas descartarlos?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Descartar"),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    Future<bool> _confirmSaveChanges() async {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Guardar cambios"),
          content: const Text("¿Deseas guardar los cambios realizados?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Guardar"),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    @override
    Widget build(BuildContext context) {
      if (_loading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return WillPopScope( // 🔹 NEW: prevent accidental back
      onWillPop: () async {
        if (_editable && _hasChanges) {
          final discard = await _confirmDiscardChanges();
          return discard;
        }
        return true;
      },
      child:Scaffold(
          appBar: AppBar(
            title: const Text("Perfil de Usuario"),
            actions: [
              IconButton(
                icon: Icon(_editable ? Icons.close : Icons.edit),
                onPressed: () async {
                  if (_editable && _hasChanges) {
                    final discard = await _confirmDiscardChanges();
                    if (!discard) return; // user canceled
                    _revertChanges(); 
                  }
                  setState(() {
                    _editable = !_editable;
                    if (!_editable) _hasChanges = false;
                  });
                },
              ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form (
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar circular
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[400],
                      child: Text(
                        _user?.nombre.isNotEmpty == true
                            ? _user!.nombre[0].toUpperCase()
                            : "U",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Name
                    _buildTextField(
                      label: "Nombre", 
                      controller: _nameController,
                      validator: (v) {
                          if (_onlySpaces(v)) return "Campo requerido";
                          v = v!.trim();
                          if (!RegExp(r"^[a-zA-ZÀ-ÿ\s]+$").hasMatch(v)) {
                            return "Solo letras (sin símbolos o emojis)";
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),
                    // Email
                    _buildTextField(
                      label: "Correo electrónico", 
                      controller: _emailController, 
                      type: TextInputType.emailAddress,
                      enabled: false, // Email is not editable
                    ),
                    const SizedBox(height: 12),
                    // Phone
                    _buildTextField(
                      label: "Teléfono", 
                      controller: _phoneController,
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
                    const SizedBox(height: 12),
                    // Address
                    _buildTextField(
                      label: "Dirección de residencia", 
                      controller: _addressController, 
                      validator: direccionValidator),                
                    const SizedBox(height: 12),
                    // Department Dropdown
                    IgnorePointer(
                      ignoring: !_editable,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDepartamento,
                        decoration: InputDecoration(
                          labelText: "Departamento de residencia",
                          filled: true,
                          fillColor: _editable ? Colors.white : Colors.grey.shade200,
                        ),
                        items: _ciudadesPorDepartamento.keys
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                         onChanged: (v) {
                          setState(() {
                            _selectedDepartamento = v;
                            _selectedCiudad = null;
                          });
                          _markChanged();
                        },
                        validator: (v) => v == null ? "Selecciona un departamento" : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // City Dropdown
                    IgnorePointer(
                      ignoring: !_editable,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCiudad,
                        decoration: InputDecoration(
                          labelText: "Ciudad de residencia",
                          filled: true,
                          fillColor: _editable ? Colors.white : Colors.grey.shade200,
                        ),
                        items: (_selectedDepartamento != null)
                            ? _ciudadesPorDepartamento[_selectedDepartamento]!
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList()
                            : [],
                       onChanged: (v) {
                          setState(() => _selectedCiudad = v);
                          _markChanged();
                        },
                        validator: (v) => v == null ? "Selecciona una ciudad" : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ZIP Code
                    _buildTextField(
                      label: "Código ZIP", 
                      controller: _zipCodeController,  
                      validator: codigoPostalValidator, 
                      type: TextInputType.number),
                    const SizedBox(height: 24),
                    // Preferences
                    // Delivery Method
                    DropdownButtonFormField<String>(
                      initialValue: _modoEntregaPreferido,
                      decoration: InputDecoration(
                        labelText: "Modo de entrega preferido",
                        filled: true,
                        fillColor: Colors.white, // ✅ no grey background
                        labelStyle: TextStyle(
                          color: _editable ? Colors.grey[700] : Colors.black87,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: "domicilio", child: Text("Domicilio")),
                        DropdownMenuItem(value: "recogida", child: Text("Recogida en tienda")),
                      ],
                      onChanged: _editable
                        ? (v) {
                            setState(() =>
                                _modoEntregaPreferido = v ?? "domicilio");
                            _markChanged();
                          }
                        : null,
                    ),
                    // Notifications
                    SwitchListTile(
                      title: const Text("Recibir notificaciones"),
                      value: _aceptaNotificaciones,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      onChanged: _editable
                        ? (val) {
                            setState(() => _aceptaNotificaciones = val);
                            _markChanged();
                          }
                        : null,
                          // Force normal colors when disabled:
                      tileColor: Colors.white,
                      subtitle: !_editable
                          ? const Text(
                              "Solo lectura",
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    if (_editable)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _updating
                            ? null
                            : () async {
                                if (_hasChanges) {
                                  final confirm = await _confirmSaveChanges();
                                  if (!confirm) return;
                                }
                                await _updateUser();
                              },
                          child: _updating
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Update"),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  
