import '../../../core/dates.dart';
import '../../members/logic/household.dart';
import 'shopping_entry.dart';

/// Who put [entry] on the list and when: `Added by Giulia · Today`, or
/// `Added by you` for the signed-in member.
String entryMeta(
  ShoppingEntry entry, {
  required Household household,
  required DateTime now,
}) {
  final who = household.isCurrentUser(entry.addedByUserId)
      ? 'you'
      : household.nameOf(entry.addedByUserId);
  return 'Added by $who · ${relativeDay(entry.addedAt, now: now)}';
}
