import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mymeds/models/user_preferencias.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final StorageService _storage = StorageService();

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
    required String zipCode, required UserPreferencias preferencias,
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
            'preferencias': preferencias.toMap(),
          };
          
          await _firestore.collection('usuarios').doc(user.uid).set(userData);
          debugPrint('AuthService: User document created successfully for ${user.uid}');
          
          // Save session to local storage after successful registration
          await _saveSessionToLocal(user);
          
          return AuthResult(success: true, user: user);
        } catch (firestoreError) {
          debugPrint('AuthService: Failed to create user document: $firestoreError');
          // If Firestore fails, we still return success since Firebase Auth succeeded
          // The UserSession will handle creating a fallback user
          // Still save session locally
          await _saveSessionToLocal(user);
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
      
      // Save session to local storage after successful login
      if (userCredential.user != null) {
        await _saveSessionToLocal(userCredential.user!);
      }
      
      return AuthResult(success: true, user: userCredential.user);
      
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 FirebaseAuthException caught: Code=${e.code}');
      
      String errorMessage;
      switch (e.code) {
        case 'invalid-credential':
          errorMessage = 'Correo o contraseña incorrecta.';
          break;
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
        case 'network-request-failed':
          errorMessage = 'No tienes acceso a internet. Intenta ingresar más tarde cuando tengas conexión.';
          break;
        default:
          errorMessage = 'Error al iniciar sesión. Verifica tus credenciales.';
      }
      
      return AuthResult(success: false, errorMessage: errorMessage);
      
    } catch (e) {
      debugPrint('🔥 General Exception caught: Type=${e.runtimeType}');
      
      // Check if it's a network-related error
      final errorString = e.toString().toLowerCase();
      final isNetworkError = errorString.contains('network') || 
        errorString.contains('connection') || 
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('failed host lookup');
      
      return AuthResult(
        success: false,
        errorMessage: isNetworkError
          ? 'No tienes acceso a internet. Intenta ingresar más tarde cuando tengas conexión.'
          : 'Error inesperado. Intenta nuevamente más tarde.',
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

  // ========== Session Persistence Methods ==========

  /// Save user session to local storage after successful login
  /// 
  /// This allows the user to stay logged in across app restarts for up to 24 hours.
  static Future<void> _saveSessionToLocal(User user) async {
    try {
      // Get the auth token
      final token = await user.getIdToken();
      
      await _storage.saveUserSession(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
        token: token,
      );
      
      debugPrint('AuthService: Session saved to local storage for ${user.uid}');
    } catch (e) {
      debugPrint('AuthService: Failed to save session to local storage: $e');
      // Don't throw - login should succeed even if session storage fails
    }
  }

  /// Restore user session from local storage
  /// 
  /// Called on app startup to automatically log in the user if a valid session exists.
  /// Returns true if session was restored successfully, false otherwise.
  static Future<bool> restoreSessionFromLocal() async {
    try {
      debugPrint('AuthService: Attempting to restore session from local storage...');
      
      // Check if session is valid
      final isValid = await _storage.isSessionValid();
      if (!isValid) {
        debugPrint('AuthService: No valid session found in local storage');
        await _storage.clearUserSession(); // Clean up expired session
        return false;
      }
      
      // Get session data
      final sessionData = await _storage.getUserSession();
      if (sessionData == null) {
        debugPrint('AuthService: Session data is null');
        return false;
      }
      
      // Check if user is already authenticated with Firebase
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == sessionData['uid']) {
        debugPrint('AuthService: User already authenticated with Firebase');
        return true;
      }
      
      // If Firebase user doesn't match, the session is invalid
      // (user might have been deleted or signed out on another device)
      if (currentUser == null) {
        debugPrint('AuthService: Firebase user is null, but local session exists');
        debugPrint('AuthService: This likely means offline mode - session is still valid');
        // In offline mode, we consider the session valid
        // The UserSession will handle loading cached user data
        return true;
      }
      
      debugPrint('AuthService: Session restored successfully for ${sessionData['uid']}');
      return true;
      
    } catch (e) {
      debugPrint('AuthService: Error restoring session from local storage: $e');
      return false;
    }
  }

  /// Logout and clear all session data
  /// 
  /// This signs out the user from Firebase and clears all local session data.
  static Future<void> logout() async {
    try {
      debugPrint('AuthService: Logging out user...');
      
      // Sign out from Firebase
      await signOut();
      
      // Clear local session storage
      await _storage.clearUserSession();
      
      debugPrint('AuthService: User logged out and session cleared');
    } catch (e) {
      debugPrint('AuthService: Error during logout: $e');
      // Force clear session even if signOut fails
      await _storage.clearUserSession();
      rethrow;
    }
  }

  /// Check if there's a valid local session
  /// 
  /// Returns true if a valid session exists in local storage.
  static Future<bool> hasValidLocalSession() async {
    return await _storage.isSessionValid();
  }

  /// Get the session data from local storage
  /// 
  /// Returns session data map or null if no session exists.
  static Future<Map<String, String>?> getLocalSessionData() async {
    return await _storage.getUserSession();
  }
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