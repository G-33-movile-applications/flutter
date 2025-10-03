import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
	const LoginScreen({super.key});

	@override
	State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
		final _emailController = TextEditingController();
		final _passwordController = TextEditingController();
		bool _isLoading = false;

		Future<void> _login() async {
			setState(() => _isLoading = true);
			await Future.delayed(const Duration(seconds: 1));
			if (!mounted) return;
			// Simulate successful login for now
			Navigator.pushReplacementNamed(context, '/home');
			setState(() => _isLoading = false);
		}

	@override
	Widget build(BuildContext context) {
		final theme = AppTheme.lightTheme;

		return Scaffold(
			body: Center(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(horizontal: 32),
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
							TextField(
								controller: _emailController,
								style: GoogleFonts.balsamiqSans(),
								decoration: InputDecoration(
									labelText: 'Usuario',
									hintText: '¿Olvidó su usuario?',
									filled: true,
									fillColor: const Color(0xFFFFF1D5),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(16),
									),
								),
							),
							const SizedBox(height: 16),
							// Password Field
							TextField(
								controller: _passwordController,
								obscureText: true,
								style: GoogleFonts.balsamiqSans(),
								decoration: InputDecoration(
									labelText: 'Contraseña',
									hintText: '¿Olvidó su contraseña?',
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
		);
	}
}
