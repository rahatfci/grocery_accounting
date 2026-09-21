import '../../../core/result.dart';
import '../logic/app_user.dart';
import '../logic/auth_failure.dart';

/// Sign-in for accounts created by hand in the Firebase console.
///
/// Implementations own every Firebase type; none of them cross this boundary.
abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();

  Future<Result<AppUser, AuthFailure>> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
