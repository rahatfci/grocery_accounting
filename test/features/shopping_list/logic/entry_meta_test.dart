import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/members/logic/household.dart';
import 'package:grocery_accounting/features/shopping_list/logic/entry_meta.dart';

import '../../members/fake_member_repository.dart';
import '../fake_shopping_list_repository.dart';

void main() {
  final now = DateTime(2026, 9, 26, 18);
  final household = Household.of([
    testMember(id: 'giulia', displayName: 'Giulia'),
  ], const AppUser(uid: 'me', email: 'rahat@example.com'));

  test('names who added it and when', () {
    final entry = testEntry(
      addedByUserId: 'giulia',
      addedAt: DateTime(2026, 9, 26, 8),
    );

    expect(
      entryMeta(entry, household: household, now: now),
      'Added by Giulia · Today',
    );
  });

  test('calls the signed-in member you', () {
    final entry = testEntry(
      addedByUserId: 'me',
      addedAt: DateTime(2026, 9, 25, 20),
    );

    expect(
      entryMeta(entry, household: household, now: now),
      'Added by you · Yesterday',
    );
  });

  test('names someone no longer in the household as unknown', () {
    final entry = testEntry(
      addedByUserId: 'gone',
      addedAt: DateTime(2026, 9, 20),
    );

    expect(
      entryMeta(entry, household: household, now: now),
      'Added by Unknown member · 20/09',
    );
  });
}
