import 'dart:convert';

/// User preferences embedded in UserModel
class UserPreferencias {
  final String modoEntregaPreferido; // "domicilio" or "recogida"
  final bool notificaciones;

  const UserPreferencias({
    required this.modoEntregaPreferido,
    required this.notificaciones,
  });

  // Create UserPreferencias from Map
  factory UserPreferencias.fromMap(Map<String, dynamic> map) {
    return UserPreferencias(
      modoEntregaPreferido: map['modoEntregaPreferido'] ?? 'domicilio',
      notificaciones: map['notificaciones'] ?? true,
    );
  }

  // Convert UserPreferencias to Map
  Map<String, dynamic> toMap() {
    return {
      'modoEntregaPreferido': modoEntregaPreferido,
      'notificaciones': notificaciones,
    };
  }

  // Create from JSON string
  factory UserPreferencias.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return UserPreferencias.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  UserPreferencias copyWith({
    String? modoEntregaPreferido,
    bool? notificaciones,
  }) {
    return UserPreferencias(
      modoEntregaPreferido: modoEntregaPreferido ?? this.modoEntregaPreferido,
      notificaciones: notificaciones ?? this.notificaciones,
    );
  }

  @override
  String toString() {
    return 'UserPreferencias(modoEntregaPreferido: $modoEntregaPreferido, notificaciones: $notificaciones)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferencias && 
           other.modoEntregaPreferido == modoEntregaPreferido &&
           other.notificaciones == notificaciones;
  }

  @override
  int get hashCode => Object.hash(modoEntregaPreferido, notificaciones);
}