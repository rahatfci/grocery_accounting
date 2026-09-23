import 'package:equatable/equatable.dart';

import '../../auth/logic/app_user.dart';

/// A member of the household, mirrored from a Firebase Auth account.
final class HouseholdMember extends Equatable {
  const HouseholdMember({
    required this.id,
    required this.displayName,
    required this.email,
  });

  /// The Firebase Auth uid, which is also the `users/{userId}` document id.
  final String id;

  /// What the member is called in the payer picker, and in feature 4's reports.
  final String displayName;

  final String email;

  @override
  List<Object?> get props => [id, displayName, email];
}

/// The name to mirror for an account created in the Firebase console.
///
/// The console creates accounts from an email and a password only, so there is
/// never an Auth display name to copy and the local part of the address is the
/// only name the household has given. Nothing edits it yet.
String displayNameFromEmail(String? email) {
  final local = (email ?? '').split('@').first.trim();
  return local.isEmpty ? 'Member' : local;
}

/// The members who may be chosen as the payer, sorted by name.
///
/// The signed-in member is always one of them, even before their mirror
/// document exists or has synced, so a purchase can always be recorded.
List<HouseholdMember> payerOptions(
  Iterable<HouseholdMember> members,
  AppUser currentUser,
) {
  final byId = {for (final member in members) member.id: member};
  byId.putIfAbsent(
    currentUser.uid,
    () => HouseholdMember(
      id: currentUser.uid,
      displayName: displayNameFromEmail(currentUser.email),
      email: currentUser.email ?? '',
    ),
  );

  return byId.values.toList()..sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
}
