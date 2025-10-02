import 'package:flutter/material.dart';
import '../ui/home/home_screen.dart';
import '../ui/map/map_screen.dart';
import '../ui/upload/upload_screen_stub.dart';
import '../ui/profile/profile_screen_stub.dart';

class AppRouter {
  static const String home = '/home';
  static const String map = '/map';
  static const String upload = '/upload';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
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
          builder: (_) => const UploadScreenStub(),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreenStub(),
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