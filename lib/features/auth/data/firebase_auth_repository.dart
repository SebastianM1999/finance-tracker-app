import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository() : _auth = FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: use Firebase's built-in popup — no client ID needed
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
    } else {
      // Mobile: use google_sign_in package
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) await GoogleSignIn().signOut();
  }

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      displayName: user.displayName ?? 'Nutzer',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }
}
