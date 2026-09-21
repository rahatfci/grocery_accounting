import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result.dart';
import '../logic/app_user.dart';
import '../logic/auth_failure.dart';
import 'auth_repository.dart';

@LazySingleton(as: AuthRepository)
class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : _toAppUser(user),
  );

  @override
  Future<Result<AppUser, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const Err(UnexpectedAuthFailure());
      }
      return Ok(_toAppUser(user));
    } on FirebaseAuthException catch (e) {
      return Err(authFailureFromCode(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AppUser _toAppUser(User user) => AppUser(uid: user.uid, email: user.email);
}
