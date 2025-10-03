import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UsuarioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'usuarios';

  // Create a new user
  Future<void> create(UserModel usuario) async {
    try {
      await _firestore.collection(_collection).doc(usuario.uid).set(usuario.toMap());
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  // Read a user by ID
  Future<UserModel?> read(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error reading user: $e');
    }
  }

  // Read all users
  Future<List<UserModel>> readAll() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error reading all users: $e');
    }
  }

  // Update a user
  Future<void> update(UserModel usuario) async {
    try {
      await _firestore.collection(_collection).doc(usuario.uid).update(usuario.toMap());
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  // Delete a user
  Future<void> delete(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).delete();
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  // Find user by email
  Future<UserModel?> findByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Error finding user by email: $e');
    }
  }

  // Check if user exists
  Future<bool> exists(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Error checking if user exists: $e');
    }
  }

  // Stream of user changes
  Stream<UserModel?> streamUser(String uid) {
    return _firestore
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null 
            ? UserModel.fromMap(doc.data()!) 
            : null);
  }
}