import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../auth/logic/app_user.dart';
import '../logic/household_member.dart';
import 'member_dto.dart';
import 'member_repository.dart';

@LazySingleton(as: MemberRepository)
class FirestoreMemberRepository implements MemberRepository {
  const FirestoreMemberRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Ordered by `displayName`, which every mirror write sets, so no member is
  /// dropped for want of the field Firestore is ordering on.
  @override
  Stream<List<HouseholdMember>> watchMembers() => _users
      .orderBy('displayName')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            memberFromFirestore(doc.id, doc.data()),
        ],
      )
      .handleError(
        (Object error, StackTrace stackTrace) =>
            Error.throwWithStackTrace(dataFailureFromError(error), stackTrace),
      );

  @override
  Future<Result<void, DataFailure>> upsertCurrentMember(AppUser user) async {
    final member = HouseholdMember(
      id: user.uid,
      displayName: displayNameFromEmail(user.email),
      email: user.email ?? '',
    );
    final document = _users.doc(user.uid);

    try {
      final snapshot = await document.get();
      if (snapshot.exists) {
        // Merge, so the `createdAt` already on the document survives.
        await document.set(memberToFirestore(member), SetOptions(merge: true));
      } else {
        await document.set(
          newMemberToFirestore(member, createdAt: FieldValue.serverTimestamp()),
        );
      }
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }
}
