import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/data/item_dto.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';

// Local, not UTC: `Timestamp.toDate()` returns local time, and `DateTime`
// equality compares the UTC flag as well as the instant.
final _baseline = DateTime(2026, 9, 1, 10, 30);

Item _item({
  String id = 'abc123',
  String name = 'Rice',
  ItemUnit unit = ItemUnit.kg,
  String category = 'pantry',
  double? avgPieceWeight,
  double dailyUsage = 0.25,
  double lowThreshold = 2,
}) => Item(
  id: id,
  name: name,
  unit: unit,
  category: category,
  avgPieceWeight: avgPieceWeight,
  dailyUsage: dailyUsage,
  lowThreshold: lowThreshold,
  stockAtBaseline: 0,
  baselineDate: _baseline,
);

void main() {
  group('itemToFirestore', () {
    test('writes the catalogue half with stable enum keys', () {
      final data = itemToFirestore(
        _item(unit: ItemUnit.l, category: 'drinks', avgPieceWeight: 1.5),
      );

      expect(data, {
        'name': 'Rice',
        'unit': 'l',
        'category': 'drinks',
        'avgPieceWeight': 1.5,
        'dailyUsage': 0.25,
        'lowThreshold': 2.0,
      });
    });

    test('never carries the id or the baseline pair', () {
      final data = itemToFirestore(_item());

      expect(data.containsKey('id'), isFalse);
      expect(data.containsKey('stockAtBaseline'), isFalse);
      expect(data.containsKey('baselineDate'), isFalse);
    });

    test('keeps a null avgPieceWeight as an explicit null', () {
      final data = itemToFirestore(_item());

      expect(data.containsKey('avgPieceWeight'), isTrue);
      expect(data['avgPieceWeight'], isNull);
    });
  });

  group('newItemToFirestore', () {
    test('adds a zero baseline stock and the supplied baseline date', () {
      final data = newItemToFirestore(
        _item(),
        baselineDate: 'server-timestamp',
      );

      expect(data['stockAtBaseline'], 0.0);
      expect(data['baselineDate'], 'server-timestamp');
      expect(data['name'], 'Rice');
    });
  });

  group('itemFromFirestore', () {
    test('round-trips a created document', () {
      final original = _item(
        unit: ItemUnit.pcs,
        category: 'Baby food',
        avgPieceWeight: 0.2,
      );
      final data = newItemToFirestore(
        original,
        baselineDate: Timestamp.fromDate(_baseline),
      );

      final restored = itemFromFirestore('abc123', data);

      expect(restored, original);
    });

    test('round-trips a null avgPieceWeight', () {
      final original = _item();
      final data = newItemToFirestore(
        original,
        baselineDate: Timestamp.fromDate(_baseline),
      );

      final restored = itemFromFirestore('abc123', data);

      expect(restored.avgPieceWeight, isNull);
      expect(restored, original);
    });

    test('reads a stored timestamp back as local time', () {
      final restored = itemFromFirestore('abc123', {
        'name': 'Rice',
        'baselineDate': Timestamp.fromDate(_baseline.toUtc()),
      });

      expect(restored.baselineDate.isUtc, isFalse);
      expect(restored.baselineDate.isAtSameMomentAs(_baseline), isTrue);
    });

    test('carries the document id, which is never in the body', () {
      final data = newItemToFirestore(
        _item(),
        baselineDate: Timestamp.fromDate(_baseline),
      );

      expect(itemFromFirestore('other-id', data).id, 'other-id');
    });

    test('reads an int amount as a double', () {
      final restored = itemFromFirestore('abc123', {
        'name': 'Rice',
        'unit': 'kg',
        'category': 'pantry',
        'avgPieceWeight': 2,
        'dailyUsage': 0,
        'lowThreshold': 3,
        'stockAtBaseline': 1,
        'baselineDate': Timestamp.fromDate(_baseline),
      });

      expect(restored.avgPieceWeight, 2.0);
      expect(restored.dailyUsage, 0.0);
      expect(restored.lowThreshold, 3.0);
      expect(restored.stockAtBaseline, 1.0);
    });

    test('falls back rather than throwing on a malformed document', () {
      final restored = itemFromFirestore('abc123', const {
        'unit': 'not-a-unit',
        'dailyUsage': 'nonsense',
      });

      expect(restored.name, '');
      expect(restored.unit, ItemUnit.kg);
      expect(restored.category, 'other');
      expect(restored.avgPieceWeight, isNull);
      expect(restored.dailyUsage, 0.0);
      expect(restored.lowThreshold, 0.0);
    });

    test('approximates a still-pending server timestamp as now', () {
      final restored = itemFromFirestore('abc123', const {
        'name': 'Rice',
        'baselineDate': null,
      });

      expect(
        restored.baselineDate.difference(DateTime.now()).abs(),
        lessThan(const Duration(seconds: 5)),
      );
    });
  });
}
