import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/logic/auth_failure.dart';

void main() {
  group('authFailureFromCode', () {
    test(
      'treats every credential rejection as one indistinguishable failure',
      () {
        const codes = [
          'invalid-credential',
          'invalid-email',
          'user-not-found',
          'wrong-password',
        ];

        for (final code in codes) {
          expect(
            authFailureFromCode(code),
            const InvalidCredentials(),
            reason: '$code must not reveal whether the account exists',
          );
        }
      },
    );

    test('maps a disabled account', () {
      expect(authFailureFromCode('user-disabled'), const AccountDisabled());
    });

    test('maps rate limiting', () {
      expect(authFailureFromCode('too-many-requests'), const TooManyAttempts());
    });

    test('maps a failed network request', () {
      expect(
        authFailureFromCode('network-request-failed'),
        const NetworkUnavailable(),
      );
    });

    test('falls back to the unexpected failure for an unknown code', () {
      expect(
        authFailureFromCode('operation-not-allowed'),
        const UnexpectedAuthFailure(),
      );
      expect(authFailureFromCode(''), const UnexpectedAuthFailure());
    });

    test('never surfaces a raw Firebase code to the user', () {
      const codes = [
        'invalid-credential',
        'user-disabled',
        'too-many-requests',
        'network-request-failed',
        'some-code-firebase-adds-later',
      ];

      for (final code in codes) {
        expect(authFailureFromCode(code).message, isNot(contains(code)));
        expect(authFailureFromCode(code).message, isNotEmpty);
      }
    });
  });

  group('AuthFailure', () {
    test('compares by type, so distinct failures are never equal', () {
      expect(const InvalidCredentials(), isNot(const AccountDisabled()));
      expect(const InvalidCredentials(), const InvalidCredentials());
    });
  });
}
