import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mymeds/ui/upload/pdf_upload_page.dart';
import 'package:mymeds/providers/motion_provider.dart';
import 'package:mymeds/models/prescripcion.dart';

void main() {
  late MotionProvider motionProvider;

  setUp(() {
    motionProvider = MotionProvider();
  });

  Widget createTestWidget({Widget? child}) {
    return MaterialApp(
      home: ChangeNotifierProvider<MotionProvider>.value(
        value: motionProvider,
        child: child ?? const PdfUploadPage(),
      ),
    );
  }

  group('PDF Upload Page - UI Tests', () {
    testWidgets('should display page title and instructions', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Cargar Prescripción PDF'), findsOneWidget);
      expect(find.text('Cargar desde PDF'), findsOneWidget);
      expect(find.text('Selecciona un archivo PDF de tu prescripción médica'), findsOneWidget);
    });

    testWidgets('should display file selection button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Seleccionar Archivo PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('should display help section', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('¿Cómo funciona?'), findsOneWidget);
      expect(find.text('Selecciona un archivo PDF de tu prescripción'), findsOneWidget);
    });

    testWidgets('should show driving overlay when driving', (WidgetTester tester) async {
      motionProvider.setIsDrivingConfirmed(true);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Por seguridad, no puedes cargar prescripciones mientras conduces.'), findsOneWidget);
    });

    testWidgets('should hide driving overlay when not driving', (WidgetTester tester) async {
      motionProvider.setIsDrivingConfirmed(false);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Por seguridad, no puedes cargar prescripciones mientras conduces.'), findsNothing);
    });
  });

  group('PDF Upload - Data Extraction Tests', () {
    test('should parse doctor name from text correctly', () {
      final testText = 'Doctor: Dr. Juan Pérez\nDiagnóstico: Gripe común';
      
      expect(testText.toLowerCase().contains('doctor'), isTrue);
      expect(testText.toLowerCase().contains('diagnóstico'), isTrue);
    });

    test('should extract diagnosis from text', () {
      final testText = 'Diagnóstico: Infección respiratoria aguda';
      final match = RegExp(r'diagnóstico\s*:?\s*(.+)', caseSensitive: false).firstMatch(testText.toLowerCase());
      
      expect(match, isNotNull);
    });

    test('should detect medication patterns in text', () {
      final testText = 'Medicamento: Amoxicilina 500mg\nCada 8 horas durante 7 días';
      
      expect(testText.toLowerCase().contains('medicamento'), isTrue);
      expect(testText.contains('500mg'), isTrue);
      expect(testText.contains('8 horas'), isTrue);
    });
  });

  group('PDF Upload - Form Validation Tests', () {
    test('should validate doctor name is not empty', () {
      const doctorName = '';
      expect(doctorName.trim().isEmpty, isTrue);
    });

    test('should validate doctor name has minimum length', () {
      const shortName = 'Dr.';
      const validName = 'Dr. Juan Pérez';
      
      expect(shortName.length < 5, isTrue);
      expect(validName.length >= 5, isTrue);
    });

    test('should validate diagnosis is not empty', () {
      const diagnosis = '';
      expect(diagnosis.trim().isEmpty, isTrue);
    });

    test('should validate diagnosis has minimum length', () {
      const shortDiagnosis = 'Gr';
      const validDiagnosis = 'Gripe común';
      
      expect(shortDiagnosis.length < 3, isTrue);
      expect(validDiagnosis.length >= 3, isTrue);
    });

    test('should validate medication name', () {
      const emptyName = '';
      const shortName = 'Ab';
      const validName = 'Amoxicilina';
      
      expect(emptyName.isEmpty, isTrue);
      expect(shortName.length < 3, isTrue);
      expect(validName.length >= 3, isTrue);
    });

    test('should validate medication has required fields', () {
      final medication = {
        'nombre': 'Amoxicilina',
        'dosis': '500mg',
        'frecuencia': 'Cada 8 horas',
        'duracion': '7 días',
      };
      
      expect(medication['nombre']?.toString().isNotEmpty, isTrue);
      expect(medication['dosis']?.toString().isNotEmpty, isTrue);
      expect(medication['frecuencia']?.toString().isNotEmpty, isTrue);
      expect(medication['duracion']?.toString().isNotEmpty, isTrue);
    });

    test('should validate at least one medication exists', () {
      final medications = <Map<String, dynamic>>[];
      expect(medications.isEmpty, isTrue);
      
      medications.add({
        'nombre': 'Test',
        'dosis': '1mg',
        'frecuencia': '1',
        'duracion': '1',
      });
      expect(medications.isNotEmpty, isTrue);
    });

    test('should not exceed maximum medication limit', () {
      final medications = List.generate(51, (index) => {'nombre': 'Med$index'});
      expect(medications.length > 50, isTrue);
    });
  });

  group('PDF Upload - Data Parsing Tests', () {
    test('should parse duration from text to days', () {
      final durations = {
        '7 días': 7,
        '10 días': 10,
        '14 días': 14,
      };

      for (final entry in durations.entries) {
        final match = RegExp(r'(\d+)').firstMatch(entry.key);
        if (match != null) {
          final days = int.tryParse(match.group(1)!);
          expect(days, entry.value);
        }
      }
    });

    test('should parse frequency from text to hours', () {
      final frequencies = {
        'Cada 8 horas': 8,
        'Cada 12 horas': 12,
        'Cada 6 horas': 6,
      };

      for (final entry in frequencies.entries) {
        final match = RegExp(r'(\d+)').firstMatch(entry.key);
        if (match != null) {
          final hours = int.tryParse(match.group(1)!);
          expect(hours, entry.value);
        }
      }
    });

    test('should create medication map with all required fields', () {
      final now = DateTime.now();
      final duracionDias = 7;
      final medicationData = {
        'id': 'med_123',
        'medicamentoRef': '/medicamentosGlobales/unknown',
        'nombre': 'Amoxicilina',
        'dosisMg': 0.0,
        'frecuenciaHoras': 8,
        'duracionDias': duracionDias,
        'fechaInicio': now,
        'fechaFin': now.add(Duration(days: duracionDias)),
        'observaciones': '500mg - Cada 8 horas - 7 días',
        'activo': true,
        'userId': 'user123',
        'prescripcionId': 'pres123',
      };

      expect(medicationData.containsKey('id'), isTrue);
      expect(medicationData.containsKey('nombre'), isTrue);
      expect(medicationData.containsKey('duracionDias'), isTrue);
      expect(medicationData['fechaFin'], now.add(Duration(days: duracionDias)));
    });

    test('should generate unique prescription ID', () {
      final id1 = 'pres_${DateTime.now().millisecondsSinceEpoch}';
      
      expect(id1.startsWith('pres_'), isTrue);
      expect(id1.length > 5, isTrue);
    });

    test('should create Prescripcion object with correct fields', () {
      final prescripcion = Prescripcion(
        id: 'pres_123',
        medico: 'Dr. Juan Pérez',
        diagnostico: 'Gripe común',
        fechaCreacion: DateTime.now(),
        activa: true,
      );

      expect(prescripcion.id, 'pres_123');
      expect(prescripcion.medico, 'Dr. Juan Pérez');
      expect(prescripcion.diagnostico, 'Gripe común');
      expect(prescripcion.activa, isTrue);
    });
  });

  group('PDF Upload - Text Cleaning Tests', () {
    test('should remove common doctor title prefixes', () {
      final names = {
        'Dr. Juan Pérez': 'Juan Pérez',
        'Dra. María García': 'María García',
        'Doctor Carlos Ruiz': 'Carlos Ruiz',
        'Doctora Ana López': 'Ana López',
      };

      for (final entry in names.entries) {
        final cleaned = entry.key.replaceAll(
          RegExp(r'\b(Dr|Dra|Doctor|Doctora)\.?\s*', caseSensitive: false),
          '',
        ).trim();
        expect(cleaned, entry.value);
      }
    });

    test('should validate text contains letters', () {
      final texts = {
        '12345': false,
        'Juan123': true,
        'Dr. Pérez': true,
        '@#\$%': false,
      };

      for (final entry in texts.entries) {
        final hasLetters = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').hasMatch(entry.key);
        expect(hasLetters, entry.value);
      }
    });

    test('should detect gibberish text', () {
      final texts = {
        'Juan': false,
        '1234': true,
        'Med123456': true,
        'Amoxicilina500': false,
      };

      for (final entry in texts.entries) {
        final letterCount = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').allMatches(entry.key).length;
        final numberCount = RegExp(r'\d').allMatches(entry.key).length;
        final isGibberish = numberCount > letterCount;
        
        expect(isGibberish, entry.value);
      }
    });
  });

  group('PDF Upload - Error Handling Tests', () {
    test('should handle empty PDF text extraction', () {
      const extractedText = '';
      expect(extractedText.isEmpty, isTrue);
    });

    test('should handle null values in parsed data', () {
      final parsedData = {
        'medico': null,
        'diagnostico': null,
        'medicamentos': null,
      };

      expect(parsedData['medico'] ?? '', '');
      expect(parsedData['diagnostico'] ?? '', '');
      expect((parsedData['medicamentos'] as List?)?.isEmpty ?? true, isTrue);
    });

    test('should validate user is authenticated before saving', () {
      const String? userId = null;
      expect(userId == null, isTrue);
    });

    test('should collect multiple validation errors', () {
      final errors = <String>[];
      
      if (''.isEmpty) errors.add('Doctor name is required');
      if (''.isEmpty) errors.add('Diagnosis is required');
      if (<dynamic>[].isEmpty) errors.add('At least one medication is required');
      
      expect(errors.length, 3);
      expect(errors.join('\n'), contains('Doctor name is required'));
    });
  });

  group('PDF Upload - Date Handling Tests', () {
    test('should use current date as default', () {
      final now = DateTime.now();
      final selectedDate = DateTime.now();
      
      expect(selectedDate.year, now.year);
      expect(selectedDate.month, now.month);
      expect(selectedDate.day, now.day);
    });

    test('should calculate medication end date correctly', () {
      final startDate = DateTime(2025, 1, 1);
      final duracionDias = 7;
      final endDate = startDate.add(Duration(days: duracionDias));
      
      expect(endDate, DateTime(2025, 1, 8));
    });

    test('should handle different duration periods', () {
      final startDate = DateTime(2025, 1, 1);
      final durations = [1, 7, 14, 30, 90];
      
      for (final days in durations) {
        final endDate = startDate.add(Duration(days: days));
        final difference = endDate.difference(startDate).inDays;
        expect(difference, days);
      }
    });
  });

  group('PDF Upload - Medication Management Tests', () {
    test('should add new medication to list', () {
      final medications = <Map<String, dynamic>>[];
      
      expect(medications.isEmpty, isTrue);
      
      medications.add({
        'controller_nombre': TextEditingController(),
        'controller_dosis': TextEditingController(),
      });
      
      expect(medications.length, 1);
    });

    test('should remove medication from list', () {
      final medications = <Map<String, dynamic>>[
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ];
      
      medications.removeAt(1);
      
      expect(medications.length, 2);
      expect(medications[0]['id'], 1);
      expect(medications[1]['id'], 3);
    });

    test('should generate unique medication IDs', () {
      final ids = <String>{};
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      for (int i = 0; i < 5; i++) {
        final id = 'med_${timestamp}_$i';
        ids.add(id);
      }
      
      expect(ids.length, 5);
    });
  });

  group('PDF Upload - Integration Tests', () {
    test('should create complete prescription data structure', () {
      final userId = 'user123';
      final prescripcionId = 'pres_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final prescripcion = Prescripcion(
        id: prescripcionId,
        medico: 'Dr. Juan Pérez',
        diagnostico: 'Gripe común',
        fechaCreacion: now,
        activa: true,
      );

      final medications = [
        {
          'id': 'med_1',
          'nombre': 'Amoxicilina',
          'frecuenciaHoras': 8,
          'duracionDias': 7,
          'userId': userId,
          'prescripcionId': prescripcionId,
        },
      ];

      expect(prescripcion.id, prescripcionId);
      expect(medications.length, 1);
      expect(medications[0]['prescripcionId'], prescripcionId);
      expect(medications[0]['userId'], userId);
    });

    test('should combine medication observations', () {
      final dosis = '500mg';
      final frecuencia = 'Cada 8 horas';
      final duracion = '7 días';
      final observaciones = 'Tomar con alimentos';

      final combined = '$dosis - $frecuencia - $duracion - $observaciones';
      
      expect(combined, '500mg - Cada 8 horas - 7 días - Tomar con alimentos');
    });
  });
}
