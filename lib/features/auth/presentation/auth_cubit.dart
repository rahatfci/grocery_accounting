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
    _subscription = _repository.authStateChanges().listen(
      _onAuthStateChanged,
      onError: _onAuthStreamError,
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AppUser?> _subscription;

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthSubmitting());
    try {
      final result = await _repository.signIn(email: email, password: password);
      // Ok carries the user Firebase returned, so this is already a confirmed
      // session. The stream event that follows is an equal state and is
      // dropped, and emitting here means the form cannot wait on it forever.
      switch (result) {
        case Ok(:final value):
          emit(AuthSignedIn(value));
        case Err(:final error):
          emit(AuthSignInFailure(error));
      }
    } catch (error, stackTrace) {
      // The repository maps the Firebase codes it knows. Anything else still
      // has to reach the user as a state rather than an unhandled error, and is
      // reported so the cause is not lost behind the generic message.
      addError(error, stackTrace);
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

  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    // Only a state that is waiting on the stream needs a way out. A signed-in
    // member stays where they are rather than being sent back to sign in.
    if (state is AuthInitial || state is AuthSubmitting) {
      emit(const AuthSignInFailure(UnexpectedAuthFailure()));
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
