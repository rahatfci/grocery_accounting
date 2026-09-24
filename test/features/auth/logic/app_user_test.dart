import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/auth/logic/auth_failure.dart';

void main() {
  group('appUserFrom', () {
    test('no user from Firebase is no member', () {
      expect(appUserFrom(uid: null, email: null), isNull);
    });

    test('a user becomes a member with its uid and email', () {
      expect(
        appUserFrom(uid: 'abc123', email: 'rahat@example.com'),
        const AppUser(uid: 'abc123', email: 'rahat@example.com'),
      );
    });

    test('a user without an email is still a member', () {
      expect(
        appUserFrom(uid: 'abc123', email: null),
        const AppUser(uid: 'abc123', email: null),
      );
    });
  });

  group('signInResultFrom', () {
    test('a returned member is a session', () {
      const user = AppUser(uid: 'abc123', email: 'rahat@example.com');

      expect(
        signInResultFrom(user),
        isA<Ok<AppUser, AuthFailure>>().having((r) => r.value, 'value', user),
      );
    });

    test('an accepted sign in with no user is unexpected', () {
      expect(
        signInResultFrom(null),
        isA<Err<AppUser, AuthFailure>>().having(
          (r) => r.error,
          'error',
          const UnexpectedAuthFailure(),
        ),
      );
    });
  });
}
