import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

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
  // Private constructor for singleton pattern
  UserSession._internal();
  
  // Singleton instance
  static final UserSession _instance = UserSession._internal();
  
  // Factory constructor returns the same instance
  factory UserSession() => _instance;

  // Dependencies
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Reactive current user state - null means not authenticated
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);
  
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
      } else {
        debugPrint('UserSession: User signed out');
        currentUser.value = null;
      }
    } catch (e) {
      debugPrint('UserSession: Error handling auth state change: $e');
      // Don't throw here as it would break the stream
      currentUser.value = null;
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
    _isInitialized = false;
  }
}