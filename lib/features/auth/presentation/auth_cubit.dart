import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result.dart';
import '../data/auth_repository.dart';
import '../logic/app_user.dart';
import '../logic/auth_failure.dart';
import 'auth_state.dart';

@injectable
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthInitial()) {
    _subscription = _repository.authStateChanges().listen(_onAuthStateChanged);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AppUser?> _subscription;

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthSubmitting());
    try {
      final result = await _repository.signIn(email: email, password: password);
      // Success is left to the auth stream, so a signed-in state is only ever
      // claimed once Firebase itself reports the session.
      if (result case Err(:final error)) {
        emit(AuthSignInFailure(error));
      }
    } catch (_) {
      // The repository maps the Firebase codes it knows. Anything else still
      // has to reach the user as a state rather than an unhandled error.
      emit(const AuthSignInFailure(UnexpectedAuthFailure()));
    }
  }

  Future<void> signOut() => _repository.signOut();

  /// Drops a failure message once the user starts correcting the form.
  void failureAcknowledged() {
    if (state is AuthSignInFailure) {
      emit(const AuthSignedOut());
    }
  }

  void _onAuthStateChanged(AppUser? user) {
    if (user != null) {
      emit(AuthSignedIn(user));
      return;
    }
    // A null while a sign in is in flight, or while its error is still on
    // screen, must not overwrite either state.
    if (state is AuthSubmitting || state is AuthSignInFailure) {
      return;
    }
    emit(const AuthSignedOut());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
