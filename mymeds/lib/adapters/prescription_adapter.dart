import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prescripcion.dart';

/// Adapter for converting Prescripcion to/from NFC NDEF JSON format
/// and for parsing OCR-extracted text into Prescripcion objects
class PrescriptionAdapter {
  
  // ==================== NFC CONVERSION ====================
  
  /// Convert Prescripcion to JSON string for NFC storage
  static String toNdefJson(Prescripcion prescripcion) {
    // Handle fechaCreacion - could be DateTime or Timestamp from Firestore
    DateTime fechaCreacion;
    if (prescripcion.fechaCreacion is Timestamp) {
      fechaCreacion = (prescripcion.fechaCreacion as Timestamp).toDate();
    } else {
      fechaCreacion = prescripcion.fechaCreacion;
    }
    
    final Map<String, dynamic> data = {
      'id': prescripcion.id,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'diagnostico': prescripcion.diagnostico,
      'medico': prescripcion.medico,
      'activa': prescripcion.activa,
      '_version': '1.0', // For future compatibility
      '_timestamp': DateTime.now().toIso8601String(),
    };
    
    return jsonEncode(data);
  }
  
  /// Create Prescripcion from NFC JSON string
  static Prescripcion fromNdefJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      return Prescripcion(
        id: data['id'] ?? _generatePrescriptionId(),
        fechaCreacion: data['fechaCreacion'] != null 
            ? DateTime.parse(data['fechaCreacion'])
            : DateTime.now(),
        diagnostico: data['diagnostico'] ?? 'Sin diagnóstico',
        medico: data['medico'] ?? 'No especificado',
        activa: data['activa'] ?? true,
      );
    } catch (e) {
      throw FormatException('Invalid NFC prescription JSON: $e');
    }
  }
  
  // ==================== OCR CONVERSION ====================
  
  /// Create Prescripcion from OCR parsed data
  /// The parsedData map comes from OcrService.parsePrescriptionText()
  static Prescripcion fromOcrData(Map<String, dynamic> parsedData) {
    return Prescripcion(
      id: parsedData['id'] ?? _generatePrescriptionId(),
      fechaCreacion: _parseDate(parsedData['fechaCreacion']) ?? DateTime.now(),
      diagnostico: parsedData['diagnostico'] ?? 'Diagnóstico pendiente de verificar',
      medico: parsedData['medico'] ?? 'Médico no detectado',
      activa: parsedData['activa'] ?? true,
    );
  }
  
  /// Create a complete prescription map suitable for Firestore with OCR data
  /// Includes nested medicamentos if detected
  static Map<String, dynamic> createPrescriptionMapFromOcr(
    Map<String, dynamic> ocrData,
    String userId,
  ) {
    final prescriptionId = _generatePrescriptionId();
    
    final Map<String, dynamic> prescriptionData = {
      'id': prescriptionId,
      'fechaCreacion': Timestamp.fromDate(
        _parseDate(ocrData['fechaCreacion']) ?? DateTime.now()
      ),
      'diagnostico': ocrData['diagnostico'] ?? 'Pendiente de verificación',
      'medico': ocrData['medico'] ?? 'No detectado',
      'activa': ocrData['activa'] ?? true,
    };
    
    // Extract medications if present
    List<Map<String, dynamic>> medicamentos = [];
    if (ocrData.containsKey('medicamentos') && ocrData['medicamentos'] is List) {
      for (var med in ocrData['medicamentos']) {
        medicamentos.add({
          'nombre': med['nombre'] ?? 'Medicamento sin nombre',
          'dosis': med['dosis'] ?? 'Dosis no especificada',
          'frecuenciaHoras': _parseInt(med['frecuenciaHoras']) ?? 24,
          'duracionDias': _parseInt(med['duracionDias']) ?? 7,
          'fechaInicio': Timestamp.now(),
          'fechaFin': Timestamp.fromDate(
            DateTime.now().add(Duration(days: _parseInt(med['duracionDias']) ?? 7))
          ),
          'activo': true,
        });
      }
    }
    
    return {
      'prescription': prescriptionData,
      'medications': medicamentos,
      'userId': userId,
    };
  }
  
  // ==================== VALIDATION ====================
  
  /// Validate that prescription has all required fields
  static bool validate(Prescripcion prescripcion) {
    if (prescripcion.id.isEmpty) return false;
    if (prescripcion.diagnostico.isEmpty) return false;
    if (prescripcion.medico.isEmpty) return false;
    return true;
  }
  
  /// Validate OCR parsed data has minimum required fields
  static bool validateOcrData(Map<String, dynamic> ocrData) {
    // At minimum, we need a doctor or diagnosis
    return ocrData.containsKey('medico') || ocrData.containsKey('diagnostico');
  }
  
  /// Get list of missing required fields for user feedback
  static List<String> getMissingFields(Map<String, dynamic> ocrData) {
    List<String> missing = [];
    
    if (!ocrData.containsKey('medico') || 
        ocrData['medico'] == 'No detectado' ||
        ocrData['medico'] == 'Médico no detectado') {
      missing.add('Médico');
    }
    
    if (!ocrData.containsKey('diagnostico') || 
        ocrData['diagnostico'] == 'No detectado' ||
        ocrData['diagnostico'] == 'Diagnóstico pendiente de verificar') {
      missing.add('Diagnóstico');
    }
    
    if (!ocrData.containsKey('fechaCreacion')) {
      missing.add('Fecha');
    }
    
    if (!ocrData.containsKey('medicamentos') || 
        (ocrData['medicamentos'] as List).isEmpty) {
      missing.add('Medicamentos');
    }
    
    return missing;
  }
  
  // ==================== HELPER METHODS ====================
  
  /// Generate a unique prescription ID
  static String _generatePrescriptionId() {
    return 'pres_${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
  }
  
  /// Generate random string for ID uniqueness
  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }
  
  /// Parse date from string (supports multiple formats)
  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    
    if (dateValue is DateTime) return dateValue;
    
    if (dateValue is String) {
      try {
        // Try ISO format first
        return DateTime.parse(dateValue);
      } catch (e) {
        // Try DD/MM/YYYY format
        final parts = dateValue.split(RegExp(r'[/-]'));
        if (parts.length == 3) {
          try {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            // Handle 2-digit years
            final fullYear = year < 100 ? 2000 + year : year;
            return DateTime(fullYear, month, day);
          } catch (e) {
            return null;
          }
        }
      }
    }
    
    return null;
  }
  
  /// Parse integer from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Create a mock prescription for testing NFC write
  static Prescripcion createMockPrescription() {
    return Prescripcion(
      id: _generatePrescriptionId(),
      fechaCreacion: DateTime.now(),
      diagnostico: 'Diagnóstico de ejemplo para prueba de NFC',
      medico: 'Dr. Juan Pérez (Demo)',
      activa: true,
    );
  }
  
  /// Format prescription data for display in preview
  static Map<String, String> formatForDisplay(Prescripcion prescripcion) {
    return {
      'ID': prescripcion.id,
      'Fecha': _formatDate(prescripcion.fechaCreacion),
      'Diagnóstico': prescripcion.diagnostico,
      'Médico': prescripcion.medico,
      'Estado': prescripcion.activa ? 'Activa' : 'Inactiva',
    };
  }
  
  /// Format date for display
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }
}
