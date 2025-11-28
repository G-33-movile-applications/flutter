import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine.dart';
import '../models/medicamento_usuario.dart';
import '../services/user_session.dart';

/// Repository for fetching user's medicines
abstract class MedicinesRepository {
  Future<List<Medicine>> getUserMedicines();
}

/// Firestore implementation that fetches active medicines for the current user
class FirestoreMedicinesRepository implements MedicinesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<Medicine>> getUserMedicines() async {
    final userId = UserSession().currentUid;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('medicamentosUsuario')
          .where('activo', isEqualTo: true)
          .get();

      final medicines = snapshot.docs.map((doc) {
        final medUsuario = MedicamentoUsuario.fromMap(doc.data(), documentId: doc.id);
        return Medicine(
          id: medUsuario.id,
          name: medUsuario.nombre,
        );
      }).toList();

      // Sort alphabetically by name
      medicines.sort((a, b) => a.name.compareTo(b.name));

      return medicines;
    } catch (e) {
      print('Error fetching user medicines: $e');
      return [];
    }
  }
}

/// Fake implementation for testing without Firestore
class FakeMedicinesRepository implements MedicinesRepository {
  @override
  Future<List<Medicine>> getUserMedicines() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    return const [
      Medicine(id: '1', name: 'Omeprazol 20mg'),
      Medicine(id: '2', name: 'Losartán 50mg'),
      Medicine(id: '3', name: 'Atorvastatina 20mg'),
      Medicine(id: '4', name: 'Metformina 850mg'),
      Medicine(id: '5', name: 'Ibuprofeno 600mg'),
    ];
  }
}
