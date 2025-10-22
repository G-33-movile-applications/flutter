/// Utility class for validating addresses using the same logic as registration
class AddressValidator {
  // List of valid Colombian departments and cities for validation
  static const Map<String, List<String>> _validLocations = {
    "Cundinamarca": ["Mosquera", "Soacha", "Chía", "Funza"],
    "Bogotá D.C.": ["Bogotá"],
    "Antioquia": ["Medellín", "Bello", "Envigado", "Itagüí"],
  };

  /// Validates an address using the same rules as the registration screen
  /// Now supports addresses with city/department suffixes from geocoding
  /// Returns null if valid, otherwise returns the error message
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Campo requerido";
    }

    final v = value.trim();

    // Length check
    if (v.length < 5) return "Dirección demasiado corta";
    if (v.length > 120) return "Dirección demasiado larga"; // Increased to accommodate city/department

    // Forbidden characters (emojis, symbols) - but allow common punctuation for addresses
    final forbidden = RegExp(r'[^\w\s#\-\.,°ºáéíóúÁÉÍÓÚñÑ()]');
    if (forbidden.hasMatch(v)) {
      return "La dirección contiene caracteres inválidos";
    }

    // Split address to separate the main address from city/department info
    final parts = v.split(',').map((part) => part.trim()).toList();
    final mainAddress = parts[0];

    // Validate the main address part (before any commas)
    if (!_isValidMainAddress(mainAddress)) {
      return "Formato de dirección no válido (ej. Calle 45 #12-30)";
    }

    // If there are additional parts (city/department), validate them
    if (parts.length > 1) {
      if (!_areValidLocationParts(parts.skip(1).toList())) {
        // Don't fail validation for unknown cities, just warn
        // This allows geocoded addresses to work while still validating format
      }
    }

    return null; // Valid
  }

  /// Validates the main address part (street, number, etc.)
  static bool _isValidMainAddress(String address) {
    // Must contain both letters and numbers
    final hasLetters = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(address);
    final hasNumbers = RegExp(r'\d').hasMatch(address);
    if (!hasLetters || !hasNumbers) {
      return false;
    }

    // Should have at least two parts (e.g. "Calle 10")
    if (!address.contains(" ")) return false;

    // Colombian-style format validation (more flexible)
    final colombianPattern = RegExp(
      r'^(?:(?:Calle|Cll|Cl|Carrera|Cra|Kra|Kr|Avenida|Av|Ak|Transversal|Transv|Tv|Diagonal|Dg|Manzana|Mz)\.?\s+\d+[A-Za-z]?(?:\s+(?:bis))?(?:\s+[A-Za-z])?(?:\s+(?:Norte|Sur|Este|Oeste))?(?:\s*(?:#|No\.?|Nº|n\.º|nº|n°)\s*\d+[A-Za-z]?(?:-\d+[A-Za-z]?)?)?(?:\s+(?:Norte|Sur|Este|Oeste))?\s*)$',
      caseSensitive: false,
    );
    
    return colombianPattern.hasMatch(address);
  }

  /// Validates city/department parts from geocoded addresses
  static bool _areValidLocationParts(List<String> locationParts) {
    // Check if any of the location parts match our known cities/departments
    for (final part in locationParts) {
      final cleanPart = part.trim();
      
      // Check if it's a known department
      if (_validLocations.containsKey(cleanPart)) {
        return true;
      }
      
      // Check if it's a known city
      for (final cities in _validLocations.values) {
        if (cities.contains(cleanPart)) {
          return true;
        }
      }
    }
    
    // If we don't recognize the location, still allow it
    // This handles cases where geocoding returns valid but unlisted locations
    return true;
  }

  /// Checks if an address is valid (returns true if valid)
  static bool isValidAddress(String? value) {
    return validateAddress(value) == null;
  }

  /// Cleans an address by removing duplicate city/department references
  static String cleanAddress(String address) {
    // Remove duplicate "Bogotá, Bogotá D.C." patterns
    String cleaned = address.replaceAll(RegExp(r',\s*Bogotá,\s*Bogotá\s*D\.C\.'), ', Bogotá D.C.');
    cleaned = cleaned.replaceAll(RegExp(r',\s*Bogotá,\s*Bogotá'), ', Bogotá');
    
    // Remove trailing commas and extra spaces
    cleaned = cleaned.replaceAll(RegExp(r',\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned.trim();
  }
}