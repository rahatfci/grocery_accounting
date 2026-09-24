import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  test('stores one object per purchase under receipts/', () {
    expect(receiptStoragePath('p1AbC'), 'receipts/p1AbC');
  });

  group('pending names', () {
    test('round trip a Firestore id', () {
      const id = 'Xy12AbCdEf34GhIj56Kl';

      expect(purchaseIdFromPendingName(pendingReceiptName(id)), id);
    });

    test('ignore files the queue did not write', () {
      expect(purchaseIdFromPendingName('.DS_Store'), isNull);
      expect(purchaseIdFromPendingName('.img'), isNull);
      expect(purchaseIdFromPendingName('p1.jpg'), isNull);
      expect(purchaseIdFromPendingName('../p1.img'), isNull);
      expect(purchaseIdFromPendingName('p1.img.tmp'), isNull);
    });
  });

  group('receiptContentType', () {
    test('recognises JPEG', () {
      expect(
        receiptContentType(_bytes([0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
    });

    test('recognises PNG', () {
      expect(
        receiptContentType(_bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])),
        'image/png',
      );
    });

    test('recognises HEIC', () {
      final heic = _bytes([0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0]);

      expect(receiptContentType(heic), 'image/heic');
    });

    test('falls back for anything else, including too few bytes', () {
      expect(
        receiptContentType(_bytes([1, 2, 3, 4])),
        'application/octet-stream',
      );
      expect(receiptContentType(_bytes([0xFF])), 'application/octet-stream');
      expect(receiptContentType(Uint8List(0)), 'application/octet-stream');
      final mp4 = _bytes([0, 0, 0, 24, ...'ftypisom'.codeUnits]);
      expect(receiptContentType(mp4), 'application/octet-stream');
    });
  });
}
