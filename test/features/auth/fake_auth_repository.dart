import 'dart:async';

import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/data/auth_repository.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/auth/logic/auth_failure.dart';

const testUser = AppUser(uid: 'abc123', email: 'rahat@example.com');

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>();

  Result<AppUser, AuthFailure> signInResult = const Ok(testUser);
  Object? signInThrows;
  int signOutCalls = 0;

  /// When set, `signIn` waits on this instead of returning at once, so a test
  /// can observe the submitting state.
  Completer<void>? signInGate;

  bool get hasListener => _controller.hasListener;

  void emitAuthState(AppUser? user) => _controller.add(user);

  void emitAuthError(Object error) => _controller.addError(error);

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<Result<AppUser, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async {
    final gate = signInGate;
    if (gate != null) {
      await gate.future;
    }
    final thrown = signInThrows;
    if (thrown != null) {
      throw thrown;
    }
    return signInResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
