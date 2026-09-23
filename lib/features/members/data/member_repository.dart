import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../auth/logic/app_user.dart';
import '../logic/household_member.dart';

/// The `users` collection: the household itself.
///
/// The collection mirrors hand-created Firebase Auth accounts. There is no
/// signup, so nothing here creates a member who cannot already sign in.
abstract interface class MemberRepository {
  /// Every member, sorted by display name, refreshed as the collection
  /// changes.
  ///
  /// The stream fails with a [DataFailure], never with a raw Firebase error.
  Stream<List<HouseholdMember>> watchMembers();

  /// Mirrors the signed-in account into `users/{uid}`.
  ///
  /// Called once per session, on sign in and on launch with an existing
  /// session. `createdAt` is written only when the document is absent, so a
  /// later mirror write cannot move it.
  Future<Result<void, DataFailure>> upsertCurrentMember(AppUser user);
}
