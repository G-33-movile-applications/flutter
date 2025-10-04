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

  bool _loading = true;
  bool _updating = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _usuarioRepository.read(widget.uid);
      if (user != null) {
        setState(() {
          _user = user;
          _nameController.text = user.fullName;
          _emailController.text = user.email;
          _phoneController.text = user.phoneNumber ;
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
        fullName: _nameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
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
                  _user?.fullName.isNotEmpty == true
                      ? _user!.fullName[0].toUpperCase()
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
