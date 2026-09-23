import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/shopping_list/data/shopping_entry_dto.dart';

import '../fake_shopping_list_repository.dart';

void main() {
  group('shoppingEntryToFirestore', () {
    test('writes the full planned shape, with done always false', () {
      final entry = testEntry(
        text: 'Milk',
        itemId: 'milk',
        addedAt: DateTime(2026, 9, 20, 9),
      );

      expect(shoppingEntryToFirestore(entry), {
        'text': 'Milk',
        'itemId': 'milk',
        'addedByUserId': 'abc123',
        'addedAt': Timestamp.fromDate(DateTime(2026, 9, 20, 9)),
        'done': false,
      });
    });

    test('writes an unlinked entry with a null item id', () {
      expect(shoppingEntryToFirestore(testEntry())['itemId'], isNull);
    });

    test('never writes the document id into the body', () {
      expect(
        shoppingEntryToFirestore(testEntry(id: 'e9')).values,
        isNot(contains('e9')),
      );
    });
  });

  group('shoppingEntryFromFirestore', () {
    test('reads back what it wrote', () {
      final entry = testEntry(id: 'e7', itemId: 'milk');

      expect(
        shoppingEntryFromFirestore('e7', shoppingEntryToFirestore(entry)),
        entry,
      );
    });

    test('reads a document with every field missing', () {
      final entry = shoppingEntryFromFirestore('e1', const {});

      expect(entry.id, 'e1');
      expect(entry.text, '');
      expect(entry.itemId, isNull);
      expect(entry.addedByUserId, '');
      expect(entry.addedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('reads wrongly typed fields as absent', () {
      final entry = shoppingEntryFromFirestore('e1', const {
        'text': 42,
        'itemId': true,
        'addedByUserId': 7,
        'addedAt': '2026-09-20',
      });

      expect(entry.text, '');
      expect(entry.itemId, isNull);
      expect(entry.addedByUserId, '');
      expect(entry.addedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('reads an empty item id as unlinked', () {
      final entry = shoppingEntryFromFirestore('e1', const {'itemId': ''});

      expect(entry.itemId, isNull);
    });
  });
}
