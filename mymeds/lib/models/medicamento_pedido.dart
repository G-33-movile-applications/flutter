import 'dart:convert';

/// Medication in an order with pricing and quantity
/// Collection path: usuarios/{userId}/pedidos/{pedidoId}/medicamentos/{medicamentoId}
class MedicamentoPedido {
  final String id; // medicamentoId from global catalog
  final String medicamentoRef; // "/medicamentosGlobales/{medicamentoId}"
  final String nombre; // denormalized for quick access
  final int cantidad;
  final int precioUnitario; // in cents
  final int total; // in cents
  // Denormalized fields for collectionGroup queries
  final String userId;
  final String pedidoId;

  const MedicamentoPedido({
    required this.id,
    required this.medicamentoRef,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    required this.userId,
    required this.pedidoId,
  });

  // Create MedicamentoPedido from Firestore document
  factory MedicamentoPedido.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return MedicamentoPedido(
      id: documentId ?? map['id'] ?? '',
      medicamentoRef: map['medicamentoRef'] ?? '',
      nombre: map['nombre'] ?? '',
      cantidad: map['cantidad'] ?? 0,
      precioUnitario: map['precioUnitario'] ?? 0,
      total: map['total'] ?? 0,
      userId: map['userId'] ?? '',
      pedidoId: map['pedidoId'] ?? '',
    );
  }

  // Convert MedicamentoPedido to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'medicamentoRef': medicamentoRef,
      'nombre': nombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'total': total,
      'userId': userId,
      'pedidoId': pedidoId,
    };
  }

  // Create from JSON string
  factory MedicamentoPedido.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MedicamentoPedido.fromMap(map);
  }

  // Convert to JSON string
  String toJson() => jsonEncode(toMap());

  // Create a copy with some fields updated
  MedicamentoPedido copyWith({
    String? id,
    String? medicamentoRef,
    String? nombre,
    int? cantidad,
    int? precioUnitario,
    int? total,
    String? userId,
    String? pedidoId,
  }) {
    return MedicamentoPedido(
      id: id ?? this.id,
      medicamentoRef: medicamentoRef ?? this.medicamentoRef,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      total: total ?? this.total,
      userId: userId ?? this.userId,
      pedidoId: pedidoId ?? this.pedidoId,
    );
  }

  @override
  String toString() {
    return 'MedicamentoPedido(id: $id, nombre: $nombre, cantidad: $cantidad)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicamentoPedido && other.id == id && other.pedidoId == pedidoId;
  }

  @override
  int get hashCode => Object.hash(id, pedidoId);
}