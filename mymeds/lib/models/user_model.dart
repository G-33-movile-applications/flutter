import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_preferencias.dart';
import 'dart:convert';

class UserModel {
  final String uid;
  final String nombre;
  final String email;
  final String telefono;
  final String direccion;
  final String city;
  final String department;
  final String zipCode;
  final UserPreferencias? preferencias;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.direccion,
    required this.city,
    required this.department,
    required this.zipCode,
    this.preferencias,
    this.createdAt,
  });

  // Getters for backward compatibility with different naming conventions
  String get fullName => nombre;
  String get phoneNumber => telefono;
  String get address => direccion;

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    // Use documentId first (from Firestore document), then map['uid'], then generate a fallback
    String finalUid = documentId?.isNotEmpty == true 
        ? documentId! 
        : (map['uid']?.toString().isNotEmpty == true 
            ? map['uid'].toString() 
            : 'user_${DateTime.now().millisecondsSinceEpoch}');
    
    return UserModel(
      uid: finalUid,
      nombre: map['nombre'] ?? map['fullName'] ?? '', // Support both new and old field names
      email: map['email'] ?? '',
      telefono: map['telefono'] ?? map['phoneNumber'] ?? '',
      direccion: map['direccion'] ?? map['address'] ?? '',
      city: map['city'] ?? '',
      department: map['department'] ?? '',
      zipCode: map['zipCode'] ?? '',
      preferencias: map['preferencias'] != null 
          ? UserPreferencias.fromMap(map['preferencias'] as Map<String, dynamic>)
          : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is DateTime 
              ? map['createdAt'] as DateTime  // Already DateTime (from cache)
              : (map['createdAt'] as Timestamp).toDate())  // Firestore Timestamp
          : null,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid, // Include uid for consistency
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'city': city,
      'department': department,
      'zipCode': zipCode,
      if (preferencias != null) 'preferencias': preferencias!.toMap(),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  // Create from JSON string
  factory UserModel.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return UserModel.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  UserModel copyWith({
    String? uid,
    String? nombre,
    String? email,
    String? telefono,
    String? direccion,
    String? city,
    String? department,
    String? zipCode,
    UserPreferencias? preferencias,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      city: city ?? this.city,
      department: department ?? this.department,
      zipCode: zipCode ?? this.zipCode,
      preferencias: preferencias ?? this.preferencias,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, nombre: $nombre, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}