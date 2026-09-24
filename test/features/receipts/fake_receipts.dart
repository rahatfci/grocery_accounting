import 'dart:async';
import 'dart:typed_data';

import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_store.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt.dart';

/// A photo with a JPEG header, so it sniffs as one.
ReceiptPhoto testPhoto([int marker = 1]) =>
    ReceiptPhoto(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, marker]));

class FakeReceiptPicker implements ReceiptPicker {
  /// What the next pick returns. Null inside `Ok` is a cancel.
  Result<ReceiptPhoto?, ReceiptPickFailure> result = Ok(testPhoto());

  final sources = <ReceiptSource>[];

  @override
  Future<Result<ReceiptPhoto?, ReceiptPickFailure>> pick(
    ReceiptSource source,
  ) async {
    sources.add(source);
    return result;
  }
}

class FakeReceiptStore implements ReceiptStore {
  final kept = <({String purchaseId, ReceiptPhoto photo})>[];
  final discarded = <String>[];
  int flushes = 0;

  Result<void, DataFailure> keepResult = const Ok(null);
  Object? flushThrows;

  /// When set, `keep` waits on this, so a test can observe saving.
  Completer<void>? keepGate;

  @override
  Future<Result<void, DataFailure>> keep(
    String purchaseId,
    ReceiptPhoto photo,
  ) async {
    kept.add((purchaseId: purchaseId, photo: photo));
    await keepGate?.future;
    return keepResult;
  }

  @override
  Future<void> discard(String purchaseId) async => discarded.add(purchaseId);

  @override
  Future<int> flush() async {
    flushes++;
    final thrown = flushThrows;
    if (thrown != null) {
      throw thrown;
    }
    return 0;
  }
}
