import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';

void main() {
  group('displayNameFromEmail', () {
    test('is the local part of the address', () {
      expect(displayNameFromEmail('rahat@example.com'), 'rahat');
    });

    test('keeps a dotted local part as it is', () {
      expect(displayNameFromEmail('anna.maria@example.com'), 'anna.maria');
    });

    test('falls back for an account with no email', () {
      expect(displayNameFromEmail(null), 'Member');
      expect(displayNameFromEmail(''), 'Member');
      expect(displayNameFromEmail('@example.com'), 'Member');
    });
  });

  group('payerOptions', () {
    const currentUser = AppUser(uid: 'abc123', email: 'rahat@example.com');

    test('offers the signed-in member when no document exists yet', () {
      final options = payerOptions(const [], currentUser);

      expect(options.single.id, 'abc123');
      expect(options.single.displayName, 'rahat');
      expect(options.single.email, 'rahat@example.com');
    });

    test('does not repeat the signed-in member', () {
      final options = payerOptions(const [
        HouseholdMember(
          id: 'abc123',
          displayName: 'rahat',
          email: 'rahat@example.com',
        ),
      ], currentUser);

      expect(options, hasLength(1));
    });

    test('sorts by display name, whatever the case', () {
      final options = payerOptions(const [
        HouseholdMember(id: 'z', displayName: 'zoe', email: 'z@example.com'),
        HouseholdMember(id: 'a', displayName: 'Anna', email: 'a@example.com'),
      ], currentUser);

      expect(options.map((member) => member.displayName), [
        'Anna',
        'rahat',
        'zoe',
      ]);
    });
  });
}
