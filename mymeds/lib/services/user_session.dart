import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/pedido.dart';
import '../models/prescripcion.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/prescripcion_repository.dart';
/// Thread-safe Singleton that manages the current user session across the app.
/// 
/// This class automatically keeps the user model in sync with Firebase Auth
/// state changes and provides a reactive way to access the current user data
/// throughout the app using ValueNotifier.
/// 
/// Usage:
/// ```dart
/// // Initialize in main()
/// await UserSession().init();
/// 
/// // Listen to user changes
/// UserSession().currentUser.addListener(() {
///   final user = UserSession().currentUser.value;
///   if (user != null) {
///     print('User logged in: ${user.fullName}');
///   }
/// });
/// 
/// // Sign out
/// await UserSession().signOut();
/// ```
class UserSession {
  // ---- Singleton ----
  UserSession._internal();
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  
  // ---- Dependencias ----
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PedidoRepository _pedidoRepo = PedidoRepository();
  final PrescripcionRepository _prescripcionRepo = PrescripcionRepository();

  // Reactive current user state - null means not authenticated
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);
  final ValueNotifier<List<Pedido>> currentPedidos = ValueNotifier<List<Pedido>>([]);
  final ValueNotifier<List<Prescripcion>> currentPrescripciones = ValueNotifier<List<Prescripcion>>([]);

  // Auth state subscription for cleanup
  StreamSubscription<User?>? _authSubscription;
  
  // Flag to track initialization
  bool _isInitialized = false;

  /// Initializes the user session and sets up auth state monitoring.
  /// 
  /// This method should be called once in main() after Firebase initialization.
  /// It will:
  /// 1. Check current auth state for warm starts
  /// 2. Set up a listener for auth state changes
  /// 3. Load user data from Firestore when authenticated
  /// 
  /// Throws [Exception] if initialization fails.
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('UserSession: Already initialized, skipping...');
      return;
    }

    try {
      debugPrint('UserSession: Initializing...');
      
      // Handle current user on warm start
      final currentAuthUser = _auth.currentUser;
      if (currentAuthUser != null) {
        await _loadUserData(currentAuthUser.uid);
        await _loadSessionEntities(currentAuthUser.uid);
      }
      
      // Listen to auth state changes
      _authSubscription = _auth.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (error) {
          debugPrint('UserSession: Auth state change error: $error');
        },
      );
      
      _isInitialized = true;
      debugPrint('UserSession: Initialization complete');
      
    } catch (e) {
      debugPrint('UserSession: Initialization failed: $e');
      throw Exception('Failed to initialize UserSession: $e');
    }
  }

  /// Handles Firebase Auth state changes.
  /// 
  /// When a user signs in, loads their data from Firestore.
  /// When a user signs out, clears the current user.
  Future<void> _onAuthStateChanged(User? authUser) async {
    try {
      if (authUser != null) {
        debugPrint('UserSession: User signed in: ${authUser.uid}');
        await _loadUserData(authUser.uid);
        await _loadSessionEntities(authUser.uid);
      } else {
        debugPrint('UserSession: User signed out');
        _clearEntities();
        currentUser.value = null;
      }
    } catch (e) {
      debugPrint('UserSession: Error handling auth state change: $e');
      // Don't throw here as it would break the stream
      currentUser.value = null;
      _clearEntities();
    }
  }

  /// Loads user data from Firestore for the given UID.
  /// 
  /// If the user document doesn't exist or is malformed, waits a bit and retries
  /// (in case the document is still being created), then creates a fallback
  /// UserModel with basic information from Firebase Auth.
  Future<void> _loadUserData(String uid) async {
    try {
      debugPrint('UserSession: Loading user data for UID: $uid');
      
      // First attempt to load user data
      DocumentSnapshot userDoc = await _firestore
          .collection('usuarios')
          .doc(uid)
          .get();
      
      // If document doesn't exist, wait a bit and try again (for registration flow)
      if (!userDoc.exists) {
        debugPrint('UserSession: User document not found, waiting and retrying...');
        await Future.delayed(const Duration(milliseconds: 1500));
        
        userDoc = await _firestore
            .collection('usuarios')
            .doc(uid)
            .get();
      }
      
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()! as Map<String, dynamic>;
        final userModel = UserModel.fromMap(userData);
        currentUser.value = userModel;
        debugPrint('UserSession: User data loaded: ${userModel.fullName}');
      } else {
        // Fallback for missing Firestore document
        debugPrint('UserSession: User document still not found, creating fallback');
        await _createFallbackUser(uid);
      }
    } catch (e) {
      debugPrint('UserSession: Error loading user data: $e');
      // Set fallback on error
      await _createFallbackUser(uid);
    }
  }
  
  /// Creates a fallback user when Firestore document is not available
  Future<void> _createFallbackUser(String uid) async {
    final authUser = _auth.currentUser;
    if (authUser != null) {
      final fallbackUser = UserModel(
        uid: uid,
        fullName: authUser.displayName ?? 
                 authUser.email?.split('@').first.replaceAll(RegExp(r'[^a-zA-Z]'), '') ?? 
                 'Usuario',
        email: authUser.email ?? '',
        phoneNumber: authUser.phoneNumber ?? '',
        address: '',
        city: '',
        department: '',
        zipCode: '',
        createdAt: DateTime.now(),
      );
      currentUser.value = fallbackUser;
      debugPrint('UserSession: Fallback user created: ${fallbackUser.fullName}');
    }
  }

// ---- Sesion Entities ----
   Future<void> _loadSessionEntities(String uid) async {
    try {
      debugPrint('UserSession: Loading pedidos & prescripciones...');
      final pedidos = await _pedidoRepo.getPedidosByUser(uid);
      final prescripciones = await _prescripcionRepo.getPrescripcionesByUser(uid);

      currentPedidos.value = pedidos;
      currentPrescripciones.value = prescripciones;

      debugPrint('UserSession: Entities loaded (Pedidos=${pedidos.length}, Prescripciones=${prescripciones.length})');
    } catch (e) {
      debugPrint('UserSession: Error loading session entities: $e');
      _clearEntities();
    }
  }

  Future<void> refreshPedidos() async {
    if (currentUser.value == null) return;
    currentPedidos.value = await _pedidoRepo.getPedidosByUser(currentUser.value!.uid);
  }

  Future<void> refreshPrescripciones() async {
    if (currentUser.value == null) return;
    currentPrescripciones.value = await _prescripcionRepo.getPrescripcionesByUser(currentUser.value!.uid);
  }

  void _clearEntities() {
    currentPedidos.value = [];
    currentPrescripciones.value = [];
  }

  /// Refreshes the current user data from Firestore.
  /// 
  /// Returns the updated user model or null if not authenticated.
  /// Useful after profile updates or when you need to ensure data is fresh.
  Future<UserModel?> refresh() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      debugPrint('UserSession: Cannot refresh - no authenticated user');
      return null;
    }

    try {
      debugPrint('UserSession: Refreshing user data...');
      await _loadUserData(authUser.uid);
      return currentUser.value;
    } catch (e) {
      debugPrint('UserSession: Error refreshing user data: $e');
      return currentUser.value;
    }
  }

  /// Signs out the current user and clears the session.
  /// 
  /// This will trigger the auth state change listener which will
  /// automatically clear the currentUser value.
  Future<void> signOut() async {
    try {
      debugPrint('UserSession: Signing out user');
      await _auth.signOut();
      // currentUser.value will be cleared by _onAuthStateChanged
    } catch (e) {
      debugPrint('UserSession: Error signing out: $e');
      // Force clear on error
      currentUser.value = null;
      _clearEntities();
      rethrow;
    }
  }

  /// Checks if a user is currently authenticated.
  /// 
  /// Returns true if there's a current user, false otherwise.
  bool get isAuthenticated => currentUser.value != null;

  /// Gets the current user's UID if authenticated.
  /// 
  /// Returns null if no user is authenticated.
  String? get currentUid => currentUser.value?.uid;

  /// Gets the current user's display name for greetings.
  /// 
  /// Returns the first name from fullName, or a fallback if not available.
  String get displayName {
    final user = currentUser.value;
    if (user == null) return 'Usuario';
    
    // Try to get first name from fullName
    final fullName = user.fullName.trim();
    if (fullName.isNotEmpty) {
      return fullName.split(' ').first;
    }
    
    // Fallback to email prefix
    if (user.email.isNotEmpty) {
      return user.email.split('@').first;
    }
    
    return 'Usuario';
  }

  /// Disposes the user session and cleans up resources.
  /// 
  /// Should be called when the app is being destroyed to prevent memory leaks.
  /// In most Flutter apps, this isn't necessary as the app lifecycle handles it.
  void dispose() {
    debugPrint('UserSession: Disposing...');
    _authSubscription?.cancel();
    _authSubscription = null;
    currentUser.dispose();
    currentPedidos.dispose();
    currentPrescripciones.dispose();
    _isInitialized = false;
  }
}