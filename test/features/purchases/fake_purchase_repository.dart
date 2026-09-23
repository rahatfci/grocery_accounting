import 'dart:async';

import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/data/purchase_repository.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';

/// A purchase as the repository would hand it back: it already has a document
/// id, and its date is inside the month the report tests select.
Purchase testPurchase({
  String id = 'p1',
  DateTime? date,
  String shopName = 'Conad',
  double total = 20,
  String paidByUserId = 'abc123',
  String? receiptImagePath,
  PurchaseSource source = PurchaseSource.manual,
  List<PurchaseLine> lines = const [],
}) => Purchase(
  id: id,
  date: date ?? DateTime(2026, 9, 10, 18, 30),
  shopName: shopName,
  total: total,
  paidByUserId: paidByUserId,
  receiptImagePath: receiptImagePath,
  source: source,
  lines: lines,
);

/// One line of a purchase. [itemId] is nullable, as it is on the document: a
/// scanned line that was never matched carries none.
PurchaseLine testLine({
  String? itemId = 'abc123',
  String rawText = 'RISO 1KG',
  double quantity = 1,
  ItemUnit unit = ItemUnit.kg,
  double lineTotal = 5,
}) => PurchaseLine(
  itemId: itemId,
  rawText: rawText,
  quantity: quantity,
  unit: unit,
  lineTotal: lineTotal,
);

class FakePurchaseRepository implements PurchaseRepository {
  /// One per `watchPurchasesBetween()` call, because `snapshots()` hands back
  /// a new stream each time and changing the month has to be able to listen
  /// again.
  final _windowControllers = <StreamController<List<Purchase>>>[];

  /// The windows that were asked for, in order, so a test can prove that
  /// changing the month re-queried.
  final windows = <({DateTime from, DateTime toExclusive})>[];

  final committed = <PurchaseDraft>[];
  final commitClocks = <DateTime>[];
  final referenceChecks = <String>[];

  Result<void, DataFailure> commitResult = const Ok(null);
  Object? commitThrows;

  Result<bool, DataFailure> referenceResult = const Ok(false);
  Object? referenceThrows;

  /// When set, a call waits on this instead of returning at once, so a test
  /// can observe the saving state.
  Completer<void>? writeGate;

  int get watchWindowCalls => _windowControllers.length;

  bool get hasWindowListener =>
      _windowControllers.isNotEmpty && _windowControllers.last.hasListener;

  void emitPurchases(List<Purchase> purchases) =>
      _windowControllers.last.add(purchases);

  void emitPurchasesError(Object error) =>
      _windowControllers.last.addError(error);

  @override
  Stream<List<Purchase>> watchPurchasesBetween({
    required DateTime from,
    required DateTime toExclusive,
  }) {
    windows.add((from: from, toExclusive: toExclusive));
    final controller = StreamController<List<Purchase>>();
    _windowControllers.add(controller);
    return controller.stream;
  }

  @override
  Future<Result<void, DataFailure>> commit(
    PurchaseDraft draft, {
    required DateTime now,
  }) async {
    committed.add(draft);
    commitClocks.add(now);
    await writeGate?.future;
    final thrown = commitThrows;
    if (thrown != null) {
      throw thrown;
    }
    return commitResult;
  }

  @override
  Future<Result<bool, DataFailure>> isItemReferenced(String itemId) async {
    referenceChecks.add(itemId);
    await writeGate?.future;
    final thrown = referenceThrows;
    if (thrown != null) {
      throw thrown;
    }
    return referenceResult;
  }
}
