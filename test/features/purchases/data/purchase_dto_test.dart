import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/data/purchase_dto.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';

// Local, not UTC: `Timestamp.toDate()` returns local time, and `DateTime`
// equality compares the UTC flag as well as the instant.
final _date = DateTime(2026, 9, 21, 18, 30);

Purchase _purchase({
  String id = 'p1',
  String? receiptImagePath,
  PurchaseSource source = PurchaseSource.manual,
  List<PurchaseLine> lines = const [],
}) => Purchase(
  id: id,
  date: _date,
  shopName: 'Conad',
  total: 12.5,
  paidByUserId: 'u1',
  receiptImagePath: receiptImagePath,
  source: source,
  lines: lines,
);

const _rice = PurchaseLine(
  itemId: 'rice',
  rawText: 'Rice',
  quantity: 1,
  unit: ItemUnit.kg,
  lineTotal: 2.4,
);

const _unmatched = PurchaseLine(
  itemId: null,
  rawText: 'PASSATA 500G',
  quantity: 2,
  unit: ItemUnit.pcs,
  lineTotal: 1.8,
);

void main() {
  group('purchaseToFirestore', () {
    test('writes the whole document with stable enum keys', () {
      final data = purchaseToFirestore(_purchase(lines: const [_rice]));

      expect(data, {
        'date': Timestamp.fromDate(_date),
        'shopName': 'Conad',
        'total': 12.5,
        'paidByUserId': 'u1',
        'receiptImagePath': null,
        'source': 'manual',
        'lines': [
          {
            'itemId': 'rice',
            'rawText': 'Rice',
            'quantity': 1.0,
            'unit': 'kg',
            'lineTotal': 2.4,
          },
        ],
        'itemIds': ['rice'],
      });
    });

    test('never writes the document id into the body', () {
      expect(purchaseToFirestore(_purchase()).containsKey('id'), isFalse);
    });

    test('writes a purchase with no lines, which records spend only', () {
      final data = purchaseToFirestore(_purchase());

      expect(data['lines'], isEmpty);
      expect(data['itemIds'], isEmpty);
    });

    test('keeps an unmatched line out of itemIds', () {
      final data = purchaseToFirestore(
        _purchase(lines: const [_rice, _unmatched]),
      );

      expect(data['itemIds'], ['rice']);
      expect(data['lines'], hasLength(2));
    });

    test('writes the receipt path once a purchase has one', () {
      final data = purchaseToFirestore(
        _purchase(receiptImagePath: 'receipts/p1.jpg'),
      );

      expect(data['receiptImagePath'], 'receipts/p1.jpg');
    });
  });

  group('purchaseFromFirestore', () {
    test('round-trips a document the app wrote', () {
      final purchase = _purchase(lines: const [_rice, _unmatched]);

      expect(
        purchaseFromFirestore('p1', purchaseToFirestore(purchase)),
        purchase,
      );
    });

    test('round-trips a scanned purchase with a receipt', () {
      final purchase = _purchase(
        source: PurchaseSource.scanned,
        receiptImagePath: 'receipts/p1.jpg',
      );

      expect(
        purchaseFromFirestore('p1', purchaseToFirestore(purchase)),
        purchase,
      );
    });

    test('reads an unknown source key as manual', () {
      final data = purchaseToFirestore(_purchase())
        ..['source'] = 'imported-from-somewhere';

      expect(purchaseFromFirestore('p1', data).source, PurchaseSource.manual);
    });

    test(
      'reads a document with no lines field as a purchase with no lines',
      () {
        final data = purchaseToFirestore(_purchase())..remove('lines');

        expect(purchaseFromFirestore('p1', data).lines, isEmpty);
      },
    );

    test('skips an entry in lines that is not a map', () {
      final data = purchaseToFirestore(_purchase(lines: const [_rice]))
        ..['lines'] = [
          'nonsense',
          <String, Object?>{'rawText': 'Milk'},
        ];

      final lines = purchaseFromFirestore('p1', data).lines;

      expect(lines, hasLength(1));
      expect(lines.single.rawText, 'Milk');
      expect(lines.single.itemId, isNull);
      expect(lines.single.quantity, 0);
      expect(lines.single.unit, ItemUnit.kg);
    });

    test('renders wrongly typed fields rather than failing', () {
      final read = purchaseFromFirestore('p1', {
        'date': 'yesterday',
        'shopName': 42,
        'total': null,
        'paidByUserId': null,
        'receiptImagePath': '',
        'source': 7,
        'lines': 'not a list',
      });

      expect(read.id, 'p1');
      expect(read.shopName, isEmpty);
      expect(read.total, 0);
      expect(read.paidByUserId, isEmpty);
      expect(read.receiptImagePath, isNull);
      expect(read.source, PurchaseSource.manual);
      expect(read.lines, isEmpty);
    });

    test('reads an integer total as a double', () {
      final data = purchaseToFirestore(_purchase())..['total'] = 12;

      expect(purchaseFromFirestore('p1', data).total, 12.0);
    });
  });
}
