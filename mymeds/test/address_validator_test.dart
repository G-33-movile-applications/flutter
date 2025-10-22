import 'package:flutter_test/flutter_test.dart';
import 'package:mymeds/utils/address_validator.dart';

void main() {
  group('AddressValidator Tests', () {
    test('validates correct Colombian addresses', () {
      // Valid addresses
      expect(AddressValidator.validateAddress('Calle 123 #45-67'), isNull);
      expect(AddressValidator.validateAddress('Carrera 15 #23-45'), isNull);
      expect(AddressValidator.validateAddress('Avenida 68 #12-34'), isNull);
      expect(AddressValidator.validateAddress('Cll 45 #67-89'), isNull);
      expect(AddressValidator.validateAddress('Cra 7 #11-22'), isNull);
      expect(AddressValidator.validateAddress('Cl. 18 #2'), isNull);
      
      // Valid with bis and directions
      expect(AddressValidator.validateAddress('Calle 123 bis #45-67'), isNull);
      expect(AddressValidator.validateAddress('Carrera 15 Sur #23-45'), isNull);
      
      // Valid with apartment/building numbers
      expect(AddressValidator.validateAddress('Calle 123 #45-67 Norte'), isNull);
      
      // Valid with city/department (geocoded addresses)
      expect(AddressValidator.validateAddress('Calle 20 c #93-25, Bogotá, Bogotá D.C.'), isNull);
      expect(AddressValidator.validateAddress('Cl. 18 #2, 2, Bogotá, Bogotá'), isNull);
      expect(AddressValidator.validateAddress('Carrera 7 #11-22, Mosquera, Cundinamarca'), isNull);
    });

    test('rejects invalid addresses', () {
      // Too short
      expect(AddressValidator.validateAddress('C 1'), isNotNull);
      
      // No numbers
      expect(AddressValidator.validateAddress('Calle Principal'), isNotNull);
      
      // No letters
      expect(AddressValidator.validateAddress('123 456'), isNotNull);
      
      // Invalid format
      expect(AddressValidator.validateAddress('Random text here'), isNotNull);
      
      // Empty or null
      expect(AddressValidator.validateAddress(''), isNotNull);
      expect(AddressValidator.validateAddress(null), isNotNull);
      
      // Forbidden characters
      expect(AddressValidator.validateAddress('Calle 123 #45-67 😀'), isNotNull);
    });

    test('isValidAddress helper works correctly', () {
      expect(AddressValidator.isValidAddress('Calle 123 #45-67'), isTrue);
      expect(AddressValidator.isValidAddress('Cl. 18 #2, Bogotá'), isTrue);
      expect(AddressValidator.isValidAddress('Random text'), isFalse);
      expect(AddressValidator.isValidAddress(null), isFalse);
    });

    test('cleanAddress removes duplicates correctly', () {
      expect(
        AddressValidator.cleanAddress('Calle 20 c #93-25, Bogotá, Bogotá D.C.'),
        equals('Calle 20 c #93-25, Bogotá D.C.'),
      );
      
      expect(
        AddressValidator.cleanAddress('Cl. 18 #2, 2, Bogotá, Bogotá'),
        equals('Cl. 18 #2, 2, Bogotá'),
      );
      
      expect(
        AddressValidator.cleanAddress('Carrera 7 #11-22'),
        equals('Carrera 7 #11-22'),
      );
    });
  });
}