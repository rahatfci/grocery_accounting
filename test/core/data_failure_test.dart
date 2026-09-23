import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';

void main() {
  group('dataFailureFromCode', () {
    test('maps permission-denied', () {
      expect(
        dataFailureFromCode('permission-denied'),
        const PermissionDenied(),
      );
      expect(
        dataFailureFromCode('permission-denied').message,
        'You do not have access to this data',
      );
    });

    test('maps unavailable', () {
      expect(dataFailureFromCode('unavailable'), const ConnectionUnavailable());
      expect(
        dataFailureFromCode('unavailable').message,
        'No connection. Check your network and try again',
      );
    });

    test('maps every other code to the unexpected failure', () {
      for (final code in [
        'aborted',
        'already-exists',
        'cancelled',
        'data-loss',
        'deadline-exceeded',
        'failed-precondition',
        'internal',
        'invalid-argument',
        'not-found',
        'out-of-range',
        'resource-exhausted',
        'unauthenticated',
        'unimplemented',
        'unknown',
        '',
      ]) {
        expect(
          dataFailureFromCode(code),
          const UnexpectedDataFailure(),
          reason: 'code "$code" should map to the unexpected failure',
        );
      }
      expect(
        dataFailureFromCode('unknown').message,
        'Something went wrong. Try again',
      );
    });

    test('never leaks the raw code into the message', () {
      expect(
        dataFailureFromCode('permission-denied').message,
        isNot(contains('permission-denied')),
      );
      expect(
        dataFailureFromCode('resource-exhausted').message,
        isNot(contains('resource-exhausted')),
      );
    });
  });

  group('dataFailureFromError', () {
    test('maps a Firebase error through the shared code mapping', () {
      expect(
        dataFailureFromError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        const PermissionDenied(),
      );
      expect(
        dataFailureFromError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        const ConnectionUnavailable(),
      );
    });

    test('maps anything that is not a Firebase error', () {
      expect(
        dataFailureFromError(StateError('nothing to do with Firestore')),
        const UnexpectedDataFailure(),
      );
    });

    test('never leaks the Firebase message to the user', () {
      final failure = dataFailureFromError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );

      expect(failure.message, isNot(contains('insufficient')));
      expect(failure.message, 'You do not have access to this data');
    });
  });
}
