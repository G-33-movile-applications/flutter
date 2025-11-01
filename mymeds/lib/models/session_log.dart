import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// User session tracking
/// Collection path: user_sessions/{sessionId}
class SessionLog {
  final String id; // sessionId
  final String userId;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final int? duracionSegundos;

  const SessionLog({
    required this.id,
    required this.userId,
    required this.fechaInicio,
    this.fechaFin,
    this.duracionSegundos,
  });

  // Create SessionLog from Firestore document
  factory SessionLog.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return SessionLog(
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      fechaInicio: map['fechaInicio'] != null 
          ? (map['fechaInicio'] as Timestamp).toDate() 
          : DateTime.now(),
      fechaFin: map['fechaFin'] != null 
          ? (map['fechaFin'] as Timestamp).toDate() 
          : null,
      duracionSegundos: map['duracionSegundos'],
    );
  }

  // Convert SessionLog to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      if (fechaFin != null) 'fechaFin': Timestamp.fromDate(fechaFin!),
      if (duracionSegundos != null) 'duracionSegundos': duracionSegundos,
    };
  }

  // Create from JSON string
  factory SessionLog.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SessionLog.fromMap(map);
    
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  SessionLog copyWith({
    String? id,
    String? userId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? duracionSegundos,
  }) {
    return SessionLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      duracionSegundos: duracionSegundos ?? this.duracionSegundos,
    );
  }

  @override
  String toString() {
    return 'SessionLog(id: $id, userId: $userId, fechaInicio: $fechaInicio)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
