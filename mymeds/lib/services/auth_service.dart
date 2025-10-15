import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Register with email and password
  static Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
    required String city,
    required String department,
    required String zipCode,
  }) async {
    try {
      // Create user with Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user != null) {
        try {
          // Create user document in Firestore using consistent field names
          final userData = {
            'uid': user.uid,
            'nombre': fullName,
            'email': email,
            'telefono': phoneNumber,
            'direccion': address,
            'city': city,
            'department': department,
            'zipCode': zipCode,
            'createdAt': FieldValue.serverTimestamp(),
          };
          
          await _firestore.collection('usuarios').doc(user.uid).set(userData);
          debugPrint('AuthService: User document created successfully for ${user.uid}');
          
          return AuthResult(success: true, user: user);
        } catch (firestoreError) {
          debugPrint('AuthService: Failed to create user document: $firestoreError');
          // If Firestore fails, we still return success since Firebase Auth succeeded
          // The UserSession will handle creating a fallback user
          return AuthResult(success: true, user: user);
        }
      } else {
        return AuthResult(
          success: false,
          errorMessage: 'Failed to create user account',
        );
      }
    } on PlatformException catch (e) {
      // Handle PlatformException which is thrown on some platforms for auth errors
      String errorMessage;
      switch (e.code) {
        case 'ERROR_WEAK_PASSWORD':
          errorMessage = 'La contraseña es muy débil.';
          break;
        case 'ERROR_EMAIL_ALREADY_IN_USE':
          errorMessage = 'Ya existe una cuenta con este correo electrónico.';
          break;
        case 'ERROR_INVALID_EMAIL':
          errorMessage = 'El formato del correo electrónico no es válido.';
          break;
        case 'ERROR_INVALID_CREDENTIAL':
          errorMessage = 'Las credenciales son inválidas.';
          break;
        default:
          errorMessage = 'Error al crear la cuenta: ${e.message ?? 'Error desconocido'}';
      }
      return AuthResult(success: false, errorMessage: errorMessage);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'La contraseña es muy débil.';
          break;
        case 'email-already-in-use':
          errorMessage = 'Ya existe una cuenta con este correo electrónico.';
          break;
        case 'invalid-email':
          errorMessage = 'El formato del correo electrónico no es válido.';
          break;
        default:
          errorMessage = 'Error al crear la cuenta: ${e.message}';
      }
      return AuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Error inesperado: ${e.toString()}',
      );
    }
  }

  // Sign in with email and password
  static Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    debugPrint('🚀 AuthService.signInWithEmailAndPassword called with email: $email');
    
    try {
      debugPrint('📡 About to call Firebase Auth signInWithEmailAndPassword...');
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Firebase Auth signInWithEmailAndPassword successful');
      
      return AuthResult(success: true, user: userCredential.user);
      
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 FirebaseAuthException caught: Code=${e.code}');
      
      String errorMessage;
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          errorMessage = 'Correo o contraseña incorrectos.';
          break;
        case 'user-not-found':
          errorMessage = 'No existe una cuenta con este correo electrónico.';
          break;
        case 'invalid-email':
          errorMessage = 'El formato del correo electrónico no es válido.';
          break;
        case 'too-many-requests':
          errorMessage = 'Demasiados intentos fallidos. Intenta más tarde.';
          break;
        default:
          errorMessage = 'Error al iniciar sesión. Verifica tus credenciales.';
      }
      
      return AuthResult(success: false, errorMessage: errorMessage);
      
    } catch (e) {
      debugPrint('🔥 General Exception caught: Type=${e.runtimeType}');
      return AuthResult(
        success: false,
        errorMessage: 'Error inesperado. Intenta nuevamente más tarde.',
      );
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  static Future<UserModel?> getUserData(String uid) async {
    try {
      if (uid.isEmpty) {
        debugPrint('Error getting user data: UID is empty');
        return null;
      }
      
      final DocumentSnapshot doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, documentId: uid);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: ${e.toString()}');
      return null;
    }
  }
  
static Future<AuthResult> sendPasswordResetEmail(String email) async {
  print("🔥 FirebaseAuth instance: $_auth"); // Debug
  try {
    await _auth.sendPasswordResetEmail(email: email);
    return AuthResult(success: true);
  } on FirebaseAuthException catch (e) {
    print("⚠️ FirebaseAuthException: ${e.code} - ${e.message}");
    return AuthResult(success: false, errorMessage: e.message);
  } catch (e) {
    print("❌ Otro error: $e");
    return AuthResult(success: false, errorMessage: "Error inesperado");
  }
}
  // Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  // Listen to auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}

// Result class for authentication operations
class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
  });
}