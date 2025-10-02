// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// This file provides ready-to-use Firebase initialization and authentication helpers.
// Add your Firebase configuration files (google-services.json, GoogleService-Info.plist) to your project for production use.

class FirebaseService {
  // static Future<void> initialize() async {
  //   WidgetsFlutterBinding.ensureInitialized();
  //   await Firebase.initializeApp();
  // }

  // static Future<UserCredential?> signInWithEmail(String email, String password) async {
  //   try {
  //     return await FirebaseAuth.instance.signInWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );
  //   } on FirebaseAuthException catch (e) {
  //     debugPrint('FirebaseAuthException: \\${e.message}');
  //     return null;
  //   } catch (e) {
  //     debugPrint('Unknown error: \\${e.toString()}');
  //     return null;
  //   }
  // }

  // static Future<UserCredential?> registerWithEmail(String email, String password) async {
  //   try {
  //     return await FirebaseAuth.instance.createUserWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );
  //   } on FirebaseAuthException catch (e) {
  //     debugPrint('FirebaseAuthException: \\${e.message}');
  //     return null;
  //   } catch (e) {
  //     debugPrint('Unknown error: \\${e.toString()}');
  //     return null;
  //   }
  // }

  // static User? get currentUser => FirebaseAuth.instance.currentUser;

  // static Future<void> signOut() async {
  //   await FirebaseAuth.instance.signOut();
  // }
}
