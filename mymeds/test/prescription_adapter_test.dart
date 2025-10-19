import 'package:flutter_test/flutter_test.dart';
import 'package:mymeds/adapters/prescription_adapter.dart';
import 'package:mymeds/models/prescripcion.dart';

void main() {
  group('PrescriptionAdapter - NFC Conversion Tests', () {
    test('toNdefJson creates valid JSON string', () {
      final prescription = Prescripcion(
        id: 'pres_test_001',
        fechaCreacion: DateTime(2024, 1, 15, 10, 30),
        diagnostico: 'Hipertensión arterial',
        medico: 'Dr. Juan Pérez',
        activa: true,
      );

      final jsonString = PrescriptionAdapter.toNdefJson(prescription);

      expect(jsonString, isNotEmpty);
      expect(jsonString, contains('pres_test_001'));
      expect(jsonString, contains('Hipertensión arterial'));
      expect(jsonString, contains('Dr. Juan Pérez'));
      expect(jsonString, contains('"activa":true'));
    });

    test('fromNdefJson parses valid JSON correctly', () {
      const jsonString = '''
      {
        "id": "pres_test_002",
        "fechaCreacion": "2024-02-20T14:45:00.000",
        "diagnostico": "Diabetes tipo 2",
        "medico": "Dra. María González",
        "activa": true,
        "_version": "1.0"
      }
      ''';

      final prescription = PrescriptionAdapter.fromNdefJson(jsonString);

      expect(prescription.id, equals('pres_test_002'));
      expect(prescription.diagnostico, equals('Diabetes tipo 2'));
      expect(prescription.medico, equals('Dra. María González'));
      expect(prescription.activa, equals(true));
      expect(prescription.fechaCreacion.year, equals(2024));
      expect(prescription.fechaCreacion.month, equals(2));
    });

    test('NFC roundtrip preserves data', () {
      final original = Prescripcion(
        id: 'pres_roundtrip',
        fechaCreacion: DateTime(2024, 3, 10, 9, 0),
        diagnostico: 'Asma bronquial',
        medico: 'Dr. Carlos Rodríguez',
        activa: false,
      );

      // Convert to JSON and back
      final jsonString = PrescriptionAdapter.toNdefJson(original);
      final restored = PrescriptionAdapter.fromNdefJson(jsonString);

      expect(restored.id, equals(original.id));
      expect(restored.diagnostico, equals(original.diagnostico));
      expect(restored.medico, equals(original.medico));
      expect(restored.activa, equals(original.activa));
      expect(restored.fechaCreacion.year, equals(original.fechaCreacion.year));
      expect(restored.fechaCreacion.month, equals(original.fechaCreacion.month));
      expect(restored.fechaCreacion.day, equals(original.fechaCreacion.day));
    });

    test('fromNdefJson handles missing optional fields', () {
      const jsonString = '''
      {
        "diagnostico": "Gripe común",
        "medico": "Dr. Test"
      }
      ''';

      final prescription = PrescriptionAdapter.fromNdefJson(jsonString);

      expect(prescription.id, isNotEmpty); // Should generate an ID
      expect(prescription.diagnostico, equals('Gripe común'));
      expect(prescription.medico, equals('Dr. Test'));
      expect(prescription.activa, equals(true)); // Default value
    });

    test('fromNdefJson throws on invalid JSON', () {
      const invalidJson = 'not a valid json';

      expect(
        () => PrescriptionAdapter.fromNdefJson(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PrescriptionAdapter - OCR Conversion Tests', () {
    test('fromOcrData creates prescription with parsed data', () {
      final ocrData = {
        'medico': 'Dr. Andrés López',
        'diagnostico': 'Gastritis aguda',
        'fechaCreacion': '15/04/2024',
        'activa': true,
      };

      final prescription = PrescriptionAdapter.fromOcrData(ocrData);

      expect(prescription.medico, equals('Dr. Andrés López'));
      expect(prescription.diagnostico, equals('Gastritis aguda'));
      expect(prescription.activa, equals(true));
      expect(prescription.id, isNotEmpty);
    });

    test('fromOcrData handles missing fields with defaults', () {
      final ocrData = <String, dynamic>{};

      final prescription = PrescriptionAdapter.fromOcrData(ocrData);

      expect(prescription.medico, equals('Médico no detectado'));
      expect(prescription.diagnostico, equals('Diagnóstico pendiente de verificar'));
      expect(prescription.activa, equals(true));
      expect(prescription.id, isNotEmpty);
    });

    test('validateOcrData returns true for valid data', () {
      final validData = {
        'medico': 'Dr. Test',
        'diagnostico': 'Test diagnosis',
      };

      expect(PrescriptionAdapter.validateOcrData(validData), isTrue);
    });

    test('validateOcrData returns true with only medico', () {
      final validData = {
        'medico': 'Dr. Test',
      };

      expect(PrescriptionAdapter.validateOcrData(validData), isTrue);
    });

    test('validateOcrData returns true with only diagnostico', () {
      final validData = {
        'diagnostico': 'Test diagnosis',
      };

      expect(PrescriptionAdapter.validateOcrData(validData), isTrue);
    });

    test('validateOcrData returns false for empty data', () {
      final emptyData = <String, dynamic>{};

      expect(PrescriptionAdapter.validateOcrData(emptyData), isFalse);
    });

    test('getMissingFields identifies missing required fields', () {
      final incompleteData = {
        'observaciones': 'Some notes',
      };

      final missing = PrescriptionAdapter.getMissingFields(incompleteData);

      expect(missing, contains('Médico'));
      expect(missing, contains('Diagnóstico'));
      expect(missing, contains('Fecha'));
      expect(missing, contains('Medicamentos'));
    });

    test('getMissingFields returns empty for complete data', () {
      final completeData = {
        'medico': 'Dr. Complete',
        'diagnostico': 'Complete diagnosis',
        'fechaCreacion': '2024-01-15',
        'medicamentos': [
          {'nombre': 'Med 1'},
        ],
      };

      final missing = PrescriptionAdapter.getMissingFields(completeData);

      expect(missing, isEmpty);
    });
  });

  group('PrescriptionAdapter - Validation Tests', () {
    test('validate returns true for valid prescription', () {
      final validPrescription = Prescripcion(
        id: 'valid_id',
        fechaCreacion: DateTime.now(),
        diagnostico: 'Valid diagnosis',
        medico: 'Dr. Valid',
        activa: true,
      );

      expect(PrescriptionAdapter.validate(validPrescription), isTrue);
    });

    test('validate returns false for prescription with empty id', () {
      final invalidPrescription = Prescripcion(
        id: '',
        fechaCreacion: DateTime.now(),
        diagnostico: 'Valid diagnosis',
        medico: 'Dr. Valid',
        activa: true,
      );

      expect(PrescriptionAdapter.validate(invalidPrescription), isFalse);
    });

    test('validate returns false for prescription with empty medico', () {
      final invalidPrescription = Prescripcion(
        id: 'valid_id',
        fechaCreacion: DateTime.now(),
        diagnostico: 'Valid diagnosis',
        medico: '',
        activa: true,
      );

      expect(PrescriptionAdapter.validate(invalidPrescription), isFalse);
    });
  });

  group('PrescriptionAdapter - Helper Tests', () {
    test('createMockPrescription generates valid prescription', () {
      final mockPrescription = PrescriptionAdapter.createMockPrescription();

      expect(mockPrescription.id, isNotEmpty);
      expect(mockPrescription.id, startsWith('pres_'));
      expect(mockPrescription.diagnostico, isNotEmpty);
      expect(mockPrescription.medico, contains('Demo'));
      expect(mockPrescription.activa, isTrue);
    });

    test('formatForDisplay converts prescription to readable format', () {
      final prescription = Prescripcion(
        id: 'display_test',
        fechaCreacion: DateTime(2024, 6, 15),
        diagnostico: 'Test diagnosis',
        medico: 'Dr. Display',
        activa: true,
      );

      final displayData = PrescriptionAdapter.formatForDisplay(prescription);

      expect(displayData['ID'], equals('display_test'));
      expect(displayData['Diagnóstico'], equals('Test diagnosis'));
      expect(displayData['Médico'], equals('Dr. Display'));
      expect(displayData['Estado'], equals('Activa'));
      expect(displayData['Fecha'], contains('15/06/2024'));
    });

    test('formatForDisplay shows Inactiva for inactive prescription', () {
      final prescription = Prescripcion(
        id: 'inactive_test',
        fechaCreacion: DateTime(2024, 1, 1),
        diagnostico: 'Old diagnosis',
        medico: 'Dr. Old',
        activa: false,
      );

      final displayData = PrescriptionAdapter.formatForDisplay(prescription);

      expect(displayData['Estado'], equals('Inactiva'));
    });
  });

  group('PrescriptionAdapter - Date Parsing Tests', () {
    test('parses ISO 8601 date format', () {
      final ocrData = {
        'fechaCreacion': '2024-03-15T10:30:00.000',
        'medico': 'Dr. Test',
        'diagnostico': 'Test',
      };

      final prescription = PrescriptionAdapter.fromOcrData(ocrData);

      expect(prescription.fechaCreacion.year, equals(2024));
      expect(prescription.fechaCreacion.month, equals(3));
      expect(prescription.fechaCreacion.day, equals(15));
    });

    test('parses DD/MM/YYYY date format', () {
      final ocrData = {
        'fechaCreacion': '25/12/2023',
        'medico': 'Dr. Test',
        'diagnostico': 'Test',
      };

      final prescription = PrescriptionAdapter.fromOcrData(ocrData);

      expect(prescription.fechaCreacion.year, equals(2023));
      expect(prescription.fechaCreacion.month, equals(12));
      expect(prescription.fechaCreacion.day, equals(25));
    });

    test('uses current date when parsing fails', () {
      final ocrData = {
        'fechaCreacion': 'invalid date',
        'medico': 'Dr. Test',
        'diagnostico': 'Test',
      };

      final prescription = PrescriptionAdapter.fromOcrData(ocrData);
      final now = DateTime.now();

      expect(prescription.fechaCreacion.year, equals(now.year));
      expect(prescription.fechaCreacion.month, equals(now.month));
      expect(prescription.fechaCreacion.day, equals(now.day));
    });
  });
}
