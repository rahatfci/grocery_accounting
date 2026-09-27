import 'package:equatable/equatable.dart';

import '../../auth/logic/app_user.dart';
import 'household_member.dart';

/// Whoever paid or added something without having a `users` document.
const String unknownMemberName = 'Unknown member';

/// The five avatar colour pairs the design has.
const int avatarToneCount = 5;

/// The household as the screens read it: every member, sorted by name, with
/// the signed-in member always present, and a colour for each that is the same
/// on every screen.
final class Household extends Equatable {
  factory Household.of(Iterable<HouseholdMember> members, AppUser currentUser) {
    final sorted = payerOptions(members, currentUser);
    // Ordered by uid, which never changes, so renaming someone in the console
    // cannot swap two people's colours.
    final ids = [for (final member in sorted) member.id]..sort();
    return Household._(sorted, currentUser.uid, {
      for (final (index, id) in ids.indexed) id: index % avatarToneCount,
    });
  }

  const Household._(this.members, this.currentUserId, this._tones);

  final List<HouseholdMember> members;
  final String currentUserId;
  final Map<String, int> _tones;

  HouseholdMember? member(String id) =>
      members.where((member) => member.id == id).firstOrNull;

  String nameOf(String id) => member(id)?.displayName ?? unknownMemberName;

  String initialsOf(String id) => memberInitials(nameOf(id));

  /// The avatar colour pair for [id]. Someone outside the household still
  /// gets a stable one, derived from the id itself.
  int toneOf(String id) =>
      _tones[id] ??
      id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % avatarToneCount;

  bool isCurrentUser(String id) => id == currentUserId;

  @override
  List<Object?> get props => [members, currentUserId];
}
