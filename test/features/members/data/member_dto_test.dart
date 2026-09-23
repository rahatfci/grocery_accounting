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
    test('writes only the fields a sign in refreshes', () {
      expect(memberToFirestore(member), {
        'displayName': 'rahat',
        'email': 'rahat@example.com',
      });
    });

    test('leaves createdAt alone, so a later sign in cannot move it', () {
      expect(memberToFirestore(member).containsKey('createdAt'), isFalse);
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

      expect(read.displayName, 'anna');
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
