/// Simplified model representing a medicine for selection in reminders
/// This is a lightweight version used specifically for the reminder feature
class Medicine {
  final String id;
  final String name;

  const Medicine({
    required this.id,
    required this.name,
  });

  Medicine copyWith({
    String? id,
    String? name,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  static Medicine fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Medicine && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Medicine(id: $id, name: $name)';
}
