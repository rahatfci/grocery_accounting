import 'package:equatable/equatable.dart';

import '../logic/app_user.dart';
import '../logic/auth_failure.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

/// Before the auth stream has reported anything, so it is not yet known
/// whether a session exists.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthSubmitting extends AuthState {
  const AuthSubmitting();
}

final class AuthSignInFailure extends AuthState {
  const AuthSignInFailure(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}
