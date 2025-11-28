import 'dart:convert';

/// Result of checking medicine availability in a pharmacy
class MedicineAvailability {
  final String medicineId;
  final String medicineName;
  final bool available;
  final int stock;
  final double price; // in dollars (converted from cents)
  final bool missingData; // true if inventory data was not found

  const MedicineAvailability({
    required this.medicineId,
    required this.medicineName,
    required this.available,
    required this.stock,
    required this.price,
    this.missingData = false,
  });

  factory MedicineAvailability.fromMap(Map<String, dynamic> map) {
    return MedicineAvailability(
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      available: map['available'] ?? false,
      stock: map['stock'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      missingData: map['missingData'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'available': available,
      'stock': stock,
      'price': price,
      'missingData': missingData,
    };
  }

  String toJson() => json.encode(toMap());

  factory MedicineAvailability.fromJson(String source) =>
      MedicineAvailability.fromMap(json.decode(source));

  @override
  String toString() {
    return 'MedicineAvailability(medicineId: $medicineId, medicineName: $medicineName, available: $available, stock: $stock, price: \$$price, missingData: $missingData)';
  }
}

/// Result of checking prescription availability at a pharmacy
class InventoryCheckResult {
  final String prescriptionId;
  final String pharmacyId;
  final String pharmacyName;
  final bool allAvailable; // true if all medicines are available
  final List<MedicineAvailability> medicines;
  final double totalPrice; // sum of all medicine prices
  final DateTime checkedAt;
  final bool fromCache;

  const InventoryCheckResult({
    required this.prescriptionId,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.allAvailable,
    required this.medicines,
    required this.totalPrice,
    required this.checkedAt,
    this.fromCache = false,
  });

  /// Calculate total medicines with missing data
  int get missingDataCount => medicines.where((m) => m.missingData).length;

  /// Get list of unavailable medicines
  List<MedicineAvailability> get unavailableMedicines =>
      medicines.where((m) => !m.available).toList();

  /// Get list of available medicines
  List<MedicineAvailability> get availableMedicines =>
      medicines.where((m) => m.available).toList();

  factory InventoryCheckResult.fromMap(Map<String, dynamic> map) {
    return InventoryCheckResult(
      prescriptionId: map['prescriptionId'] ?? '',
      pharmacyId: map['pharmacyId'] ?? '',
      pharmacyName: map['pharmacyName'] ?? '',
      allAvailable: map['allAvailable'] ?? false,
      medicines: List<MedicineAvailability>.from(
        map['medicines']?.map((x) => MedicineAvailability.fromMap(x)) ?? [],
      ),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      checkedAt: DateTime.parse(map['checkedAt']),
      fromCache: map['fromCache'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prescriptionId': prescriptionId,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'allAvailable': allAvailable,
      'medicines': medicines.map((x) => x.toMap()).toList(),
      'totalPrice': totalPrice,
      'checkedAt': checkedAt.toIso8601String(),
      'fromCache': fromCache,
    };
  }

  String toJson() => json.encode(toMap());

  factory InventoryCheckResult.fromJson(String source) =>
      InventoryCheckResult.fromMap(json.decode(source));

  @override
  String toString() {
    return 'InventoryCheckResult(prescriptionId: $prescriptionId, pharmacyId: $pharmacyId, pharmacyName: $pharmacyName, allAvailable: $allAvailable, medicines: ${medicines.length}, totalPrice: \$$totalPrice, fromCache: $fromCache, checkedAt: $checkedAt)';
  }
}
