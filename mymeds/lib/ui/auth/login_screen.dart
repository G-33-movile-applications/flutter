import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
	const LoginScreen({super.key});

	@override
	State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
		final _formKey = GlobalKey<FormState>();
		final _emailController = TextEditingController();
		final _passwordController = TextEditingController();
		bool _isLoading = false;

		Future<void> _login() async {
			if (!_formKey.currentState!.validate()) return;

			setState(() => _isLoading = true);

			try {
				final result = await AuthService.signInWithEmailAndPassword(
					email: _emailController.text.trim(),
					password: _passwordController.text,
				);

				if (!mounted) return;

				if (result.success) {
					Navigator.pushReplacementNamed(context, '/home');
				} else {
					ScaffoldMessenger.of(context).showSnackBar(
						SnackBar(
							content: Text(result.errorMessage ?? "Error al iniciar sesión"),
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
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
							// App Logo
							Image.asset(
								'assets/Logo.png',
								height: 120,
							),
							const SizedBox(height: 32),
							// Title
							Text(
								'Iniciar Sesión',
								style: GoogleFonts.poetsenOne(
									textStyle: theme.textTheme.headlineMedium,
									color: theme.colorScheme.primary,
								),
							),
							const SizedBox(height: 24),
							// Email Field
							TextFormField(
								controller: _emailController,
								keyboardType: TextInputType.emailAddress,
								style: GoogleFonts.balsamiqSans(),
								validator: (value) {
									if (value == null || value.isEmpty) {
										return 'Ingresa tu correo electrónico';
									}
									final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
									if (!emailRegex.hasMatch(value)) {
										return 'Ingresa un correo electrónico válido';
									}
									return null;
								},
								decoration: InputDecoration(
									labelText: 'Correo electrónico',
									hintText: 'ejemplo@mail.com',
									filled: true,
									fillColor: const Color(0xFFFFF1D5),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(16),
									),
								),
							),
							const SizedBox(height: 16),
							// Password Field
							TextFormField(
								controller: _passwordController,
								obscureText: true,
								style: GoogleFonts.balsamiqSans(),
								validator: (value) {
									if (value == null || value.isEmpty) {
										return 'Ingresa tu contraseña';
									}
									if (value.length < 6) {
										return 'La contraseña debe tener al menos 6 caracteres';
									}
									return null;
								},
								decoration: InputDecoration(
									labelText: 'Contraseña',
									hintText: 'Tu contraseña',
									filled: true,
									fillColor: const Color(0xFFFFF1D5),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(16),
									),
								),
							),
							const SizedBox(height: 24),
							// Login Button
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
									onPressed: _isLoading ? null : _login,
									child: _isLoading
											? const CircularProgressIndicator(
													valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
												)
											: Text(
													'INICIAR SESIÓN',
													style: GoogleFonts.poetsenOne(
														color: Colors.white,
														fontSize: 18,
													),
												),
								),
							),
							const SizedBox(height: 12),
							// Register Button
							SizedBox(
								width: double.infinity,
								child: OutlinedButton(
									style: OutlinedButton.styleFrom(
										side: const BorderSide(color: Color(0xFF9EC6F3)),
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(16),
										),
										padding: const EdgeInsets.symmetric(vertical: 16),
									),
									onPressed: _isLoading
											? null
											: () => Navigator.pushNamed(context, '/register'),
									child: Text(
										'REGISTRAR',
										style: GoogleFonts.poetsenOne(
											color: const Color(0xFF9EC6F3),
											fontSize: 18,
										),
									),
								),
							),
						],
						),
					),
				),
			),
		);
	}
}
