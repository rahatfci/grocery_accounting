import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/data/firestore_item_repository.dart';

void main() {
  group('dataFailureFromError', () {
    test('maps a Firebase code through the shared mapping', () {
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
