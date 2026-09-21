import 'package:equatable/equatable.dart';

/// A sign-in failure, already carrying the text the user should see.
sealed class AuthFailure extends Equatable {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class InvalidCredentials extends AuthFailure {
  const InvalidCredentials() : super('Email or password is not correct');
}

final class AccountDisabled extends AuthFailure {
  const AccountDisabled() : super('This account has been disabled');
}

final class TooManyAttempts extends AuthFailure {
  const TooManyAttempts()
    : super('Too many attempts. Wait a moment and try again');
}

final class NetworkUnavailable extends AuthFailure {
  const NetworkUnavailable()
    : super('No connection. Check your network and try again');
}

final class UnexpectedAuthFailure extends AuthFailure {
  const UnexpectedAuthFailure() : super('Something went wrong. Try again');
}

/// Maps a `FirebaseAuthException.code` onto a failure the UI can render.
///
/// Firebase returns the same unified code for a wrong password and an unknown
/// account, and the distinct legacy codes are kept because older accounts and
/// some platforms still emit them.
AuthFailure authFailureFromCode(String code) => switch (code) {
  'invalid-credential' ||
  'invalid-email' ||
  'user-not-found' ||
  'wrong-password' => const InvalidCredentials(),
  'user-disabled' => const AccountDisabled(),
  'too-many-requests' => const TooManyAttempts(),
  'network-request-failed' => const NetworkUnavailable(),
  _ => const UnexpectedAuthFailure(),
};
