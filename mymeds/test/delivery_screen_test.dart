import 'package:flutter_test/flutter_test.dart';
import 'package:mymeds/models/user_model.dart';
import 'package:mymeds/models/user_preferencias.dart';

void main() {
  group('Delivery Screen Tests', () {
    test('user preferences should initialize correctly', () {
      // Test delivery preference
      final deliveryUser = UserModel(
        uid: 'test1',
        nombre: 'Test User',
        email: 'test@test.com',
        telefono: '1234567890',
        direccion: 'Calle 123 #45-67',
        city: 'Bogotá',
        department: 'Bogotá D.C.',
        zipCode: '110111',
        preferencias: const UserPreferencias(
          modoEntregaPreferido: 'domicilio',
          notificaciones: true,
        ),
      );

      expect(deliveryUser.preferencias!.modoEntregaPreferido, equals('domicilio'));

      // Test pickup preference
      final pickupUser = UserModel(
        uid: 'test2',
        nombre: 'Test User 2',
        email: 'test2@test.com',
        telefono: '1234567890',
        direccion: 'Carrera 15 #23-45',
        city: 'Bogotá',
        department: 'Bogotá D.C.',
        zipCode: '110111',
        preferencias: const UserPreferencias(
          modoEntregaPreferido: 'recogida',
          notificaciones: true,
        ),
      );

      expect(pickupUser.preferencias!.modoEntregaPreferido, equals('recogida'));
    });

    test('user model should handle null preferences', () {
      final userWithoutPreferences = UserModel(
        uid: 'test3',
        nombre: 'Test User 3',
        email: 'test3@test.com',
        telefono: '1234567890',
        direccion: 'Avenida 68 #12-34',
        city: 'Bogotá',
        department: 'Bogotá D.C.',
        zipCode: '110111',
        // No preferences provided
      );

      expect(userWithoutPreferences.preferencias, isNull);
    });

    test('user model should build complete address correctly', () {
      final user = UserModel(
        uid: 'test4',
        nombre: 'Test User 4',
        email: 'test4@test.com',
        telefono: '1234567890',
        direccion: 'Calle 20 c #93-25',
        city: 'Bogotá',
        department: 'Bogotá D.C.',
        zipCode: '110111',
      );

      // Test that we can build a complete address from user data
      final addressParts = <String>[];
      if (user.direccion.isNotEmpty) addressParts.add(user.direccion);
      if (user.city.isNotEmpty) addressParts.add(user.city);
      if (user.department.isNotEmpty) addressParts.add(user.department);
      
      final completeAddress = addressParts.join(', ');
      expect(completeAddress, equals('Calle 20 c #93-25, Bogotá, Bogotá D.C.'));
    });
  });
}