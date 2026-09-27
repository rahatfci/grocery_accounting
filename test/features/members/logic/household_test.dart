import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/members/logic/household.dart';

import '../fake_member_repository.dart';

void main() {
  const me = AppUser(uid: 'u3', email: 'rahat@example.com');

  test('always includes the signed-in member', () {
    final household = Household.of(const [], me);

    expect(household.members.single.id, 'u3');
    expect(household.nameOf('u3'), 'Rahat');
    expect(household.isCurrentUser('u3'), isTrue);
  });

  test('names and initials come from the member document', () {
    final household = Household.of([
      testMember(id: 'u1', displayName: 'Giulia'),
    ], me);

    expect(household.nameOf('u1'), 'Giulia');
    expect(household.initialsOf('u1'), 'GI');
  });

  test('someone who is not a member is named as unknown', () {
    final household = Household.of(const [], me);

    expect(household.nameOf('ghost'), unknownMemberName);
  });

  test('five members get five different colours', () {
    final household = Household.of([
      for (final id in ['u1', 'u2', 'u4', 'u5'])
        testMember(id: id, displayName: id),
    ], me);

    final tones = {
      for (final member in household.members) household.toneOf(member.id),
    };
    expect(tones, hasLength(5));
  });

  test('a colour follows the uid, not the name', () {
    final before = Household.of([
      testMember(id: 'u1', displayName: 'Zoe'),
      testMember(id: 'u2', displayName: 'Anna'),
    ], me);
    final renamed = Household.of([
      testMember(id: 'u1', displayName: 'Aaron'),
      testMember(id: 'u2', displayName: 'Anna'),
    ], me);

    expect(renamed.toneOf('u1'), before.toneOf('u1'));
    expect(renamed.toneOf('u2'), before.toneOf('u2'));
  });

  test('an outsider still gets a stable colour in range', () {
    final household = Household.of(const [], me);

    final tone = household.toneOf('stray-payer');
    expect(tone, household.toneOf('stray-payer'));
    expect(tone, inInclusiveRange(0, avatarToneCount - 1));
  });
}
