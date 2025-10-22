import 'package:flutter/material.dart';
import 'package:mymeds/ui/auth/forgot_password.dart';
import 'package:mymeds/ui/auth/register_screen.dart';
import 'package:mymeds/ui/delivery/delivery_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/map/map_screen.dart';
import '../ui/upload/upload_prescription.dart';
import '../ui/upload/nfc_upload_page.dart';
import '../ui/upload/ocr_upload_page.dart';
import '../ui/upload/pdf_upload_page.dart';
import '../ui/profile/profile_screen.dart';
import '../ui/auth/login_screen.dart';
import '../models/punto_fisico.dart';

class AppRouter {
  static const String login = '/';
  static const String register = '/register';
  static const String home = '/home';
  static const String map = '/map';
  static const String upload = '/upload';
  static const String uploadNfc = '/upload/nfc';
  static const String uploadOcr = '/upload/ocr';
  static const String uploadPdf = '/upload/pdf';
  static const String profile = '/profile';
  static const String delivery = '/delivery';
  static const String forgotPassword = '/forgot-password';
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case map:
        return MaterialPageRoute(
          builder: (_) => const MapScreen(),
          settings: settings,
        );
      case upload:
        return MaterialPageRoute(
          builder: (_) => const UploadPrescriptionPage(),
          settings: settings,
        );
      case uploadNfc:
        return MaterialPageRoute(
          builder: (_) => const NfcUploadPage(),
          settings: settings,
        );
      case uploadOcr:
        return MaterialPageRoute(
          builder: (_) => const OcrUploadPage(),
          settings: settings,
        );
      case uploadPdf:
        return MaterialPageRoute(
          builder: (_) => const PdfUploadPage(),
          settings: settings,
        );
      case profile:
        final args = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ProfilePage(uid: args),
          settings: settings,
        );
      case delivery:
        final pharmacy = settings.arguments as PuntoFisico?;
        return MaterialPageRoute(
          builder: (_) => DeliveryScreen(pharmacy: pharmacy),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Page not found'),
            ),
          ),
        );
    }
  }
}