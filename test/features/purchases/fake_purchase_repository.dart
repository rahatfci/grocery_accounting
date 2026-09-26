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
  final clearedEntryIds = <Set<String>>[];
  final commitIds = <String?>[];
  final receiptPaths = <String?>[];

  /// The ids `newPurchaseId` hands out, in order.
  int _nextId = 0;
  final referenceChecks = <String>[];

  Result<void, DataFailure> commitResult = const Ok(null);
  Object? commitThrows;

  Result<bool, DataFailure> referenceResult = const Ok(false);
  Object? referenceThrows;

  /// When set, a call waits on this instead of returning at once, so a test
  /// can observe the saving state.
  Completer<void>? writeGate;

  /// When set, every new window reports this at once, so a screen that only
  /// needs its month to have answered can settle.
  List<Purchase>? initialPurchases;

  int get watchWindowCalls => _windowControllers.length;

  bool get hasWindowListener =>
      _windowControllers.isNotEmpty && _windowControllers.last.hasListener;

  void emitPurchases(List<Purchase> purchases) =>
      _windowControllers.last.add(purchases);

  void emitPurchasesError(Object error) =>
      _windowControllers.last.addError(error);

  /// Fails every open window, whichever screen opened it.
  void emitPurchasesErrorToAll(Object error) {
    for (final controller in _windowControllers) {
      controller.addError(error);
    }
  }

  /// Reports [purchases] to every open window, as Firestore does for each
  /// listener.
  void emitPurchasesToAll(List<Purchase> purchases) {
    for (final controller in _windowControllers) {
      controller.add(purchases);
    }
  }

  @override
  Stream<List<Purchase>> watchPurchasesBetween({
    required DateTime from,
    required DateTime toExclusive,
  }) {
    windows.add((from: from, toExclusive: toExclusive));
    final controller = StreamController<List<Purchase>>();
    _windowControllers.add(controller);
    if (initialPurchases case final purchases?) {
      controller.add([
        for (final purchase in purchases)
          if (!purchase.date.isBefore(from) &&
              purchase.date.isBefore(toExclusive))
            purchase,
      ]);
    }
    return controller.stream;
  }

  @override
  Future<Result<void, DataFailure>> commit(
    PurchaseDraft draft, {
    required DateTime now,
    Set<String> clearEntryIds = const {},
    String? purchaseId,
    String? receiptImagePath,
  }) async {
    committed.add(draft);
    commitClocks.add(now);
    clearedEntryIds.add(clearEntryIds);
    commitIds.add(purchaseId);
    receiptPaths.add(receiptImagePath);
    await writeGate?.future;
    final thrown = commitThrows;
    if (thrown != null) {
      throw thrown;
    }
    return commitResult;
  }

  /// One per `watchPurchasesWithItem()` call.
  final itemControllers =
      <({String itemId, StreamController<List<Purchase>> controller})>[];

  /// When set, every new item watch reports this at once.
  List<Purchase>? initialItemPurchases;

  void emitItemPurchases(List<Purchase> purchases) =>
      itemControllers.last.controller.add(purchases);

  @override
  Stream<List<Purchase>> watchPurchasesWithItem(String itemId) {
    final controller = StreamController<List<Purchase>>();
    itemControllers.add((itemId: itemId, controller: controller));
    if (initialItemPurchases case final purchases?) {
      controller.add([
        for (final purchase in purchases)
          if (purchase.itemIds.contains(itemId)) purchase,
      ]);
    }
    return controller.stream;
  }

  /// One per `watchPurchase()` call.
  final purchaseControllers =
      <({String purchaseId, StreamController<Purchase?> controller})>[];

  /// What a new single-purchase watch reports at once, looked up by id.
  Map<String, Purchase> purchasesById = const {};

  /// When true, a new single-purchase watch reports nothing until told.
  bool holdPurchase = false;

  void emitPurchase(Purchase? purchase) =>
      purchaseControllers.last.controller.add(purchase);

  void emitPurchaseError(Object error) =>
      purchaseControllers.last.controller.addError(error);

  @override
  Stream<Purchase?> watchPurchase(String purchaseId) {
    final controller = StreamController<Purchase?>();
    purchaseControllers.add((purchaseId: purchaseId, controller: controller));
    if (!holdPurchase) {
      controller.add(purchasesById[purchaseId]);
    }
    return controller.stream;
  }

  @override
  String newPurchaseId() => 'new${++_nextId}';

  final linkedReceipts = <({String purchaseId, String path})>[];
  Result<void, DataFailure> linkResult = const Ok(null);

  @override
  Future<Result<void, DataFailure>> setReceiptImagePath(
    String purchaseId,
    String receiptImagePath,
  ) async {
    linkedReceipts.add((purchaseId: purchaseId, path: receiptImagePath));
    return linkResult;
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
