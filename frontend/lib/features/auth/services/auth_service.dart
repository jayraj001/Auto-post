import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Providers ─────────────────────────────────────────────────

/// Stream of Firebase auth state changes (null = logged out)
final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (e) {
    debugPrint('Firebase not ready: $e');
    return Stream.value(null);
  }
});

/// Current user (nullable)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── AuthService ───────────────────────────────────────────────

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Sign In ─────────────────────────────────────────────────
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Register ────────────────────────────────────────────────
  Future<UserCredential> register(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Set display name
    await cred.user?.updateDisplayName(name);
    // Send email verification
    await cred.user?.sendEmailVerification();
    return cred;
  }

  // ── Google Sign In ──────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    // Step 1: trigger the Google sign-in flow (exactly as requested)
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    // User cancelled the picker
    if (googleUser == null) return null;

    // Step 2: get auth tokens from the selected account
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Step 3: create a Firebase credential from the Google tokens
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Step 4: sign in to Firebase with the Google credential
    return await _auth.signInWithCredential(credential);
  }

  // ── Forgot Password ─────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign Out ────────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      GoogleSignIn().signOut(),
    ]);
  }

  // ── Current User ────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ── Firebase error → human readable message ─────────────────
  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
