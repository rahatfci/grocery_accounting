import 'package:equatable/equatable.dart';

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
