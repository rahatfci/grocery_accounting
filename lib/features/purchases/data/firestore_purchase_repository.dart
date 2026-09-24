import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../items/data/item_dto.dart';
import '../../items/logic/stock.dart';
import '../../receipts/data/alias_dto.dart';
import '../../receipts/logic/receipt_alias.dart';
import '../logic/purchase.dart';
import '../logic/purchase_draft.dart';
import '../logic/receipt_matching.dart';
import 'purchase_dto.dart';
import 'purchase_repository.dart';

@LazySingleton(as: PurchaseRepository)
class FirestorePurchaseRepository implements PurchaseRepository {
  const FirestorePurchaseRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _firestore.collection('purchases');

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('items');

  @override
  Future<Result<void, DataFailure>> commit(
    PurchaseDraft draft, {
    required DateTime now,
    Set<String> clearEntryIds = const {},
    String? purchaseId,
    String? receiptImagePath,
  }) async {
    final targets = restockTargets(draft.lines);

    // `doc()` generates an id on the client, so an item created inline has one
    // before anything is written and the whole commit stays in a single batch
    // that also works offline.
    final documents = {
      for (final target in targets)
        restockKey(target.item): target.item.id.isEmpty
            ? _items.doc()
            : _items.doc(target.item.id),
    };

    final purchase = draft.toPurchase(
      resolveItemId: (item) => documents[restockKey(item)]?.id,
      receiptImagePath: receiptImagePath,
    );

    final batch = _firestore.batch();
    batch.set(_purchases.doc(purchaseId), purchaseToFirestore(purchase));

    // A client timestamp, not the server's: offline a server timestamp
    // resolves at sync time, which can be days after the stock number it is
    // paired with, and the pair has to stay consistent.
    final baselineDate = Timestamp.fromDate(now);

    for (final target in targets) {
      final document = documents[restockKey(target.item)];
      if (document == null) {
        continue;
      }
      if (target.item.id.isEmpty) {
        batch.set(
          document,
          newItemToFirestore(
            target.item,
            baselineDate: baselineDate,
            stockAtBaseline: target.quantity,
          ),
        );
      } else {
        // `update`, so the catalogue half of the document is untouched.
        batch.update(document, {
          'stockAtBaseline': restockedBaseline(
            target.item,
            target.quantity,
            now: now,
          ),
          'baselineDate': baselineDate,
        });
      }
    }

    // What this purchase teaches about its receipt lines, in the same batch,
    // so a purchase and its lesson cannot land apart. The id is derived from
    // the wording, so relearning overwrites instead of adding a duplicate.
    for (final alias in learnedAliases(
      draft,
      resolveItemId: (item) => documents[restockKey(item)]?.id,
    )) {
      batch.set(
        _firestore
            .collection('aliases')
            .doc(aliasDocumentId(alias.rawTextNormalized)),
        aliasToFirestore(alias),
      );
    }

    // Deleting an entry another device already removed is a no-op, so a
    // stale id cannot fail the purchase.
    for (final entryId in clearEntryIds) {
      batch.delete(_firestore.collection('shoppingList').doc(entryId));
    }

    try {
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }

  /// One range field with a matching `orderBy`, so Firestore serves this from
  /// the automatic single-field index and no composite index has to be
  /// deployed. Offline it reads the local cache, which holds whatever this
  /// device has already seen.
  @override
  Stream<List<Purchase>> watchPurchasesBetween({
    required DateTime from,
    required DateTime toExclusive,
  }) => _purchases
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('date', isLessThan: Timestamp.fromDate(toExclusive))
      .orderBy('date')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            purchaseFromFirestore(doc.id, doc.data()),
        ],
      )
      .handleError(
        (Object error, StackTrace stackTrace) =>
            Error.throwWithStackTrace(dataFailureFromError(error), stackTrace),
      );

  @override
  String newPurchaseId() => _purchases.doc().id;

  @override
  Future<Result<void, DataFailure>> setReceiptImagePath(
    String purchaseId,
    String receiptImagePath,
  ) async {
    try {
      await _purchases.doc(purchaseId).update({
        'receiptImagePath': receiptImagePath,
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }

  @override
  Future<Result<bool, DataFailure>> isItemReferenced(String itemId) async {
    try {
      final referencing = await _purchases
          .where('itemIds', arrayContains: itemId)
          .limit(1)
          .get();
      return Ok(referencing.docs.isNotEmpty);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }
}
