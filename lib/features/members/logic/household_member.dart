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

  /// What the member is called across the app. Derived from the email until
  /// someone edits it in the Firebase console, and kept from then on.
  final String displayName;

  final String email;

  @override
  List<Object?> get props => [id, displayName, email];
}

const _fallbackName = 'Member';

/// The name to mirror for an account created in the Firebase console.
///
/// The console creates accounts from an email and a password only, so there is
/// never an Auth display name to copy and the local part of the address is the
/// only name the household has given. It is capitalised, because it is read
/// as a name: "Good evening, Rahat".
String displayNameFromEmail(String? email) {
  final local = _localPart(email);
  if (local.isEmpty) {
    return _fallbackName;
  }
  return local[0].toUpperCase() + local.substring(1);
}

String _localPart(String? email) => (email ?? '').split('@').first.trim();

/// The display name a sign in should write over [stored], or null to keep it.
///
/// A name someone typed into the console is theirs and is never replaced. Only
/// a missing one, or the lower-case local part earlier versions of the app
/// wrote on their own, is rewritten with [displayNameFromEmail].
String? mirroredDisplayName({required String? stored, required String? email}) {
  final current = (stored ?? '').trim();
  final derived = displayNameFromEmail(email);
  if (current.isEmpty) {
    return derived;
  }
  final automatic = _localPart(email);
  return current == automatic && current != derived ? derived : null;
}

/// Up to two initials: the first letters of the first two words, or the first
/// two letters of a single word, upper-cased.
String memberInitials(String displayName) {
  final words = displayName
      .trim()
      .split(RegExp(r'[\s._-]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return '?';
  }
  final initials = words.length > 1
      ? words[0].substring(0, 1) + words[1].substring(0, 1)
      : words[0].substring(0, words[0].length < 2 ? words[0].length : 2);
  return initials.toUpperCase();
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
