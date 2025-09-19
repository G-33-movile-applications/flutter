import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? selectedOption;
  bool check1 = false;
  bool check2 = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView( // para evitar overflow en pantallas pequeñas
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              "REGISTER",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Campo 1
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Label",
                helperText: "Assistive Text",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Campo 2
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Label",
                helperText: "Assistive Text",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Dropdown
            DropdownButtonFormField<String>(
              initialValue: selectedOption,
              items: ["Opción 1", "Opción 2", "Opción 3"]
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedOption = value;
                });
              },
              decoration: const InputDecoration(
                labelText: "Label",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Campo 3
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Label",
                helperText: "Assistive Text",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            // Campo 4
            TextField(
              decoration: const InputDecoration(
                labelText: "Label",
                helperText: "Assistive Text",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            // Botón
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // lógica de registro aquí
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.black,
                ),
                child: const Text(
                  "REGISTER",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Texto informativo
            const Text(
              "Lorem ipsum dolor sit amet lorem ipsum dolor sit amet",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Checkboxes
            CheckboxListTile(
              title: const Text("Label"),
              value: check1,
              onChanged: (val) {
                setState(() {
                  check1 = val ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text("Label"),
              value: check2,
              onChanged: (val) {
                setState(() {
                  check2 = val ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}