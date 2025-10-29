import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationInfo {
  final String medicationId;
  final String name;
  final String medicationRef;
  final int doseMg;
  final int frequencyHours;
  final DateTime startDate;
  final DateTime endDate;
  final bool active;
  final String prescriptionId;
  final String sourceFile;

  MedicationInfo({
    required this.medicationId,
    required this.name,
    required this.medicationRef,
    required this.doseMg,
    required this.frequencyHours,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.prescriptionId,
    required this.sourceFile,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicationId': medicationId,
      'name': name,
      'medicationRef': medicationRef,
      'doseMg': doseMg,
      'frequencyHours': frequencyHours,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'active': active,
      'prescriptionId': prescriptionId,
      'sourceFile': sourceFile,
    };
  }

  factory MedicationInfo.fromMap(Map<String, dynamic> map) {
    return MedicationInfo(
      medicationId: map['medicationId'] ?? '',
      name: map['name'] ?? '',
      medicationRef: map['medicationRef'] ?? '',
      doseMg: map['doseMg']?.toInt() ?? 0,
      frequencyHours: map['frequencyHours']?.toInt() ?? 24,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      active: map['active'] ?? true,
      prescriptionId: map['prescriptionId'] ?? '',
      sourceFile: map['sourceFile'] ?? '',
    );
  }

  MedicationInfo copyWith({
    String? medicationId,
    String? name,
    String? medicationRef,
    int? doseMg,
    int? frequencyHours,
    DateTime? startDate,
    DateTime? endDate,
    bool? active,
    String? prescriptionId,
    String? sourceFile,
  }) {
    return MedicationInfo(
      medicationId: medicationId ?? this.medicationId,
      name: name ?? this.name,
      medicationRef: medicationRef ?? this.medicationRef,
      doseMg: doseMg ?? this.doseMg,
      frequencyHours: frequencyHours ?? this.frequencyHours,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      sourceFile: sourceFile ?? this.sourceFile,
    );
  }
}