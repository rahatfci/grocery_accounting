import 'package:equatable/equatable.dart';

import '../../../core/result.dart';
import 'auth_failure.dart';

/// A signed-in household member.
final class AppUser extends Equatable {
  const AppUser({required this.uid, required this.email});

  final String uid;

  /// Null only if an account was created without one, which the console flow
  /// for this project never does.
  final String? email;

  @override
  List<Object?> get props => [uid, email];
}

/// The member Firebase reported, or null when it reported no user.
AppUser? appUserFrom({required String? uid, required String? email}) =>
    uid == null ? null : AppUser(uid: uid, email: email);

/// A sign in that Firebase accepted but that came back without a user cannot
/// be treated as a session, so it is reported as unexpected.
Result<AppUser, AuthFailure> signInResultFrom(AppUser? user) =>
    user == null ? const Err(UnexpectedAuthFailure()) : Ok(user);
