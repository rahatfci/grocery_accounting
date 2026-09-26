import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/members/presentation/household_cubit.dart';
import 'package:grocery_accounting/features/members/presentation/household_state.dart';

import '../fake_member_repository.dart';

void main() {
  const me = AppUser(uid: 'abc123', email: 'rahat@example.com');
  late FakeMemberRepository repository;

  setUp(() => repository = FakeMemberRepository());

  test('can name the signed-in member before the list reports', () {
    final cubit = HouseholdCubit(repository, currentUser: me);
    addTearDown(cubit.close);

    expect(cubit.state, isA<HouseholdLoading>());
    expect(cubit.state.household.nameOf('abc123'), 'Rahat');
  });

  test('reports the members as they change', () async {
    final cubit = HouseholdCubit(repository, currentUser: me);
    addTearDown(cubit.close);

    repository.emitMembers([
      testMember(),
      testMember(id: 'u2', displayName: 'Giulia'),
    ]);
    await Future<void>.delayed(Duration.zero);

    final state = cubit.state;
    expect(state, isA<HouseholdLoaded>());
    expect(state.household.members, hasLength(2));
    expect(state.household.nameOf('u2'), 'Giulia');
  });

  test('a failure keeps the members already known and can retry', () async {
    final cubit = HouseholdCubit(repository, currentUser: me);
    addTearDown(cubit.close);
    repository.emitMembers([testMember(id: 'u2', displayName: 'Giulia')]);
    await Future<void>.delayed(Duration.zero);

    repository.emitError(const ConnectionUnavailable());
    await Future<void>.delayed(Duration.zero);

    final failed = cubit.state;
    expect(failed, isA<HouseholdFailure>());
    expect((failed as HouseholdFailure).failure, const ConnectionUnavailable());
    expect(failed.household.nameOf('u2'), 'Giulia');

    cubit.retry();

    expect(cubit.state, isA<HouseholdLoading>());
    expect(repository.watchCalls, 2);
  });

  test('closing cancels the subscription', () async {
    final cubit = HouseholdCubit(repository, currentUser: me);
    expect(repository.hasListener, isTrue);

    await cubit.close();

    expect(repository.hasListener, isFalse);
  });
}
