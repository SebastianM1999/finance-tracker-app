import 'dart:async';

/// Minimal user model (mirrors firebase_auth.User fields we need).
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
}

/// Abstract interface for authentication.
/// Currently backed by [MockAuthRepository].
/// TODO: Replace with FirebaseAuthRepository after `flutterfire configure`.
abstract class AuthRepository {
  Stream<AuthUser?> get authStateChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

/// Mock implementation – used until Firebase is configured.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    _current = const AuthUser(
      uid: 'demo-uid-001',
      displayName: 'Demo Nutzer',
      email: 'demo@fintrack.app',
      photoUrl: null,
    );
    _controller.add(_current);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}
