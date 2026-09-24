import 'dart:async';
import 'dart:typed_data';

import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/receipts/data/alias_repository.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_reader.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_store.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_alias.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';

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
  final confirmed = <String>[];
  int flushes = 0;

  /// Phones by default; a test sets false to follow the web flow.
  @override
  bool queuesOffline = true;

  Result<void, DataFailure> confirmResult = const Ok(null);

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
  Future<Result<void, DataFailure>> confirm(String purchaseId) async {
    confirmed.add(purchaseId);
    return confirmResult;
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

class FakeReceiptReader implements ReceiptReader {
  /// What the next read returns.
  Result<ReceiptReading, ReceiptReadFailure> result = const Ok(
    ReceiptReading.empty,
  );

  final reads = <ReceiptPhoto>[];

  /// When set, a read waits on this, so a test can observe the progress.
  Completer<void>? gate;

  @override
  Future<Result<ReceiptReading, ReceiptReadFailure>> read(
    ReceiptPhoto photo, {
    required DateTime today,
  }) async {
    reads.add(photo);
    await gate?.future;
    return result;
  }
}

class FakeAliasRepository implements AliasRepository {
  final _controllers = <StreamController<Map<String, ReceiptAlias>>>[];

  int get watchCalls => _controllers.length;

  bool get hasListener =>
      _controllers.isNotEmpty && _controllers.last.hasListener;

  void emitAliases(List<ReceiptAlias> aliases) => _controllers.last.add({
    for (final alias in aliases) alias.rawTextNormalized: alias,
  });

  void emitError(Object error) => _controllers.last.addError(error);

  @override
  Stream<Map<String, ReceiptAlias>> watchAliases() {
    final controller = StreamController<Map<String, ReceiptAlias>>();
    _controllers.add(controller);
    return controller.stream;
  }
}
