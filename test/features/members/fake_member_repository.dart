import 'dart:async';

import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/members/data/member_repository.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';

/// A member as the repository would hand it back.
HouseholdMember testMember({
  String id = 'abc123',
  String displayName = 'rahat',
  String email = 'rahat@example.com',
}) => HouseholdMember(id: id, displayName: displayName, email: email);

class FakeMemberRepository implements MemberRepository {
  /// One per `watchMembers()` call, because `snapshots()` hands back a new
  /// stream each time and a retry has to be able to listen again.
  final _controllers = <StreamController<List<HouseholdMember>>>[];

  final upserted = <AppUser>[];

  Result<void, DataFailure> upsertResult = const Ok(null);
  Object? upsertThrows;

  int get watchCalls => _controllers.length;

  bool get hasListener =>
      _controllers.isNotEmpty && _controllers.last.hasListener;

  void emitMembers(List<HouseholdMember> members) =>
      _controllers.last.add(members);

  void emitError(Object error) => _controllers.last.addError(error);

  @override
  Stream<List<HouseholdMember>> watchMembers() {
    final controller = StreamController<List<HouseholdMember>>();
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<Result<void, DataFailure>> upsertCurrentMember(AppUser user) async {
    upserted.add(user);
    final thrown = upsertThrows;
    if (thrown != null) {
      throw thrown;
    }
    return upsertResult;
  }
}
