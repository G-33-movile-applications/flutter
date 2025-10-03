import 'package:flutter/material.dart';
import 'package:mymeds/ui/auth/register_screen.dart';
import 'package:mymeds/ui/delivery/delivery_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/map/map_screen.dart';
import '../ui/upload/upload_prescription.dart';
import '../ui/profile/profile_screen_stub.dart';
import '../ui/auth/login_screen.dart';

class AppRouter {
  static const String login = '/';
  static const String register = '/register';
  static const String home = '/home';
  static const String map = '/map';
  static const String upload = '/upload';
  static const String profile = '/profile';
  static const String delivery = '/delivery';
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
      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreenStub(),
          settings: settings,
        );
      case delivery:
        return MaterialPageRoute(
          builder: (_) => const DeliveryScreen(),
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