import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';

void main() {
  group('displayNameFromEmail', () {
    test('is the local part of the address, capitalised', () {
      expect(displayNameFromEmail('rahat@example.com'), 'Rahat');
    });

    test('keeps the rest of a dotted local part as it is', () {
      expect(displayNameFromEmail('anna.maria@example.com'), 'Anna.maria');
    });

    test('falls back for an account with no email', () {
      expect(displayNameFromEmail(null), 'Member');
      expect(displayNameFromEmail(''), 'Member');
      expect(displayNameFromEmail('@example.com'), 'Member');
    });
  });

  group('mirroredDisplayName', () {
    test('names a document that has no name yet', () {
      expect(
        mirroredDisplayName(stored: null, email: 'rahat@example.com'),
        'Rahat',
      );
      expect(
        mirroredDisplayName(stored: '  ', email: 'rahat@example.com'),
        'Rahat',
      );
    });

    test('capitalises the name earlier versions derived on their own', () {
      expect(
        mirroredDisplayName(stored: 'rahat', email: 'rahat@example.com'),
        'Rahat',
      );
    });

    test('keeps a name the household chose', () {
      expect(
        mirroredDisplayName(stored: 'Rahat A.', email: 'rahat@example.com'),
        isNull,
      );
      expect(
        mirroredDisplayName(stored: 'Giulia', email: 'g.rossi@example.com'),
        isNull,
      );
    });

    test('writes nothing when the name is already the derived one', () {
      expect(
        mirroredDisplayName(stored: 'Rahat', email: 'rahat@example.com'),
        isNull,
      );
    });

    test('keeps a local part that already starts with a capital', () {
      expect(
        mirroredDisplayName(stored: 'Luca', email: 'Luca@example.com'),
        isNull,
      );
    });
  });

  group('memberInitials', () {
    test('takes two letters of a single name', () {
      expect(memberInitials('Rahat'), 'RA');
      expect(memberInitials('giulia'), 'GI');
    });

    test('takes the first letter of each of two words', () {
      expect(memberInitials('Anna Maria'), 'AM');
      expect(memberInitials('anna.maria'), 'AM');
    });

    test('copes with a one letter name and an empty one', () {
      expect(memberInitials('X'), 'X');
      expect(memberInitials('   '), '?');
    });
  });

  group('payerOptions', () {
    const currentUser = AppUser(uid: 'abc123', email: 'rahat@example.com');

    test('offers the signed-in member when no document exists yet', () {
      final options = payerOptions(const [], currentUser);

      expect(options.single.id, 'abc123');
      expect(options.single.displayName, 'Rahat');
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
        'Rahat',
        'zoe',
      ]);
    });
  });
}
