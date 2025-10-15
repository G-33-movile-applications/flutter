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

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _zipCodeController = TextEditingController();

  bool _loading = true;
  bool _updating = false;
  UserModel? _user;

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
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading user: $e")),
      );
    }
  }

  Future<void> _updateUser() async {
    if (_user == null) return;

    setState(() => _updating = true);

    try {
      final updatedUser = _user!.copyWith(
        nombre: _nameController.text,
        email: _emailController.text,
        telefono: _phoneController.text,
        direccion: _addressController.text,
        city: _cityController.text,
        department: _departmentController.text,
        zipCode: _zipCodeController.text,
      );

      await _usuarioRepository.update(updatedUser);

      setState(() {
        _user = updatedUser;
        _updating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User updated successfully!")),
      );
    } catch (e) {
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating user: $e")),
      );
    }
  }

  Widget _buildTextField(
      {required String label,
      required TextEditingController controller,
      bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              _buildTextField(label: "Name", controller: _nameController),
              const SizedBox(height: 12),
              _buildTextField(label: "Email", controller: _emailController),
              const SizedBox(height: 12),
              _buildTextField(label: "Phone", controller: _phoneController),
              const SizedBox(height: 12),
              _buildTextField(label: "Address", controller: _addressController),
              const SizedBox(height: 12),
              _buildTextField(label: "City", controller: _cityController),
              const SizedBox(height: 12),
              _buildTextField(label: "Department", controller: _departmentController),
              const SizedBox(height: 12),
              _buildTextField(label: "ZIP Code", controller: _zipCodeController),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _updating ? null : _updateUser,
                  child: _updating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Update"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
