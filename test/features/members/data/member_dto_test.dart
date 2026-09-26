import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/members/data/member_dto.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';

void main() {
  const member = HouseholdMember(
    id: 'abc123',
    displayName: 'rahat',
    email: 'rahat@example.com',
  );

  group('memberToFirestore', () {
    test('writes the name and the email', () {
      expect(memberToFirestore(member), {
        'displayName': 'rahat',
        'email': 'rahat@example.com',
      });
    });

    test('leaves createdAt alone, so a later sign in cannot move it', () {
      expect(memberToFirestore(member).containsKey('createdAt'), isFalse);
    });
  });

  group('memberRefreshToFirestore', () {
    test('keeps a name the household chose and refreshes the email', () {
      expect(
        memberRefreshToFirestore(
          email: 'rahat@example.com',
          existingDisplayName: 'Rahat A.',
        ),
        {'email': 'rahat@example.com'},
      );
    });

    test('replaces the name the app used to derive on its own', () {
      expect(
        memberRefreshToFirestore(
          email: 'rahat@example.com',
          existingDisplayName: 'rahat',
        ),
        {'email': 'rahat@example.com', 'displayName': 'Rahat'},
      );
    });

    test('names a document whose name is missing or not text', () {
      expect(
        memberRefreshToFirestore(
          email: 'rahat@example.com',
          existingDisplayName: 42,
        ),
        {'email': 'rahat@example.com', 'displayName': 'Rahat'},
      );
    });

    test('never touches createdAt', () {
      final refresh = memberRefreshToFirestore(
        email: 'rahat@example.com',
        existingDisplayName: null,
      );

      expect(refresh.containsKey('createdAt'), isFalse);
    });
  });

  test('newMemberToFirestore adds the createdAt it is given', () {
    final createdAt = Timestamp.fromDate(DateTime(2026, 9, 21, 10));

    expect(newMemberToFirestore(member, createdAt: createdAt), {
      'displayName': 'rahat',
      'email': 'rahat@example.com',
      'createdAt': createdAt,
    });
  });

  group('memberFromFirestore', () {
    test('round-trips a document written by the app', () {
      final data = newMemberToFirestore(
        member,
        createdAt: Timestamp.fromDate(DateTime(2026, 9, 21, 10)),
      );

      expect(memberFromFirestore('abc123', data), member);
    });

    test('derives a name for a document written without one', () {
      final read = memberFromFirestore('abc123', {'email': 'anna@example.com'});

      expect(read.displayName, 'Anna');
    });

    test(
      'renders a document with wrongly typed fields rather than failing',
      () {
        final read = memberFromFirestore('abc123', {
          'displayName': 42,
          'email': null,
        });

        expect(read.id, 'abc123');
        expect(read.displayName, 'Member');
        expect(read.email, isEmpty);
      },
    );
  });
}
