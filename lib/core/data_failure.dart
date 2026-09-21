import 'package:equatable/equatable.dart';

/// A Firestore read or write failure, already carrying the text the user
/// should see.
///
/// Same contract as `AuthFailure`: a raw Firebase code, message or stack trace
/// never reaches the user.
sealed class DataFailure extends Equatable {
  const DataFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class PermissionDenied extends DataFailure {
  const PermissionDenied() : super('You do not have access to this data');
}

final class ConnectionUnavailable extends DataFailure {
  const ConnectionUnavailable()
    : super('No connection. Check your network and try again');
}

final class UnexpectedDataFailure extends DataFailure {
  const UnexpectedDataFailure() : super('Something went wrong. Try again');
}

/// Maps a `FirebaseException.code` onto a failure the UI can render.
DataFailure dataFailureFromCode(String code) => switch (code) {
  'permission-denied' => const PermissionDenied(),
  'unavailable' => const ConnectionUnavailable(),
  _ => const UnexpectedDataFailure(),
};
