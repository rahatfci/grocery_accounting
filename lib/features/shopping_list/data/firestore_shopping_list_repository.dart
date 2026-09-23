import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/shopping_entry.dart';
import 'shopping_entry_dto.dart';
import 'shopping_list_repository.dart';

@LazySingleton(as: ShoppingListRepository)
class FirestoreShoppingListRepository implements ShoppingListRepository {
  const FirestoreShoppingListRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('shoppingList');

  @override
  Stream<List<ShoppingEntry>> watchEntries() => _entries
      .orderBy('addedAt')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            shoppingEntryFromFirestore(doc.id, doc.data()),
        ],
      )
      .handleError(
        (Object error, StackTrace stackTrace) =>
            Error.throwWithStackTrace(dataFailureFromError(error), stackTrace),
      );

  @override
  Future<Result<void, DataFailure>> add(ShoppingEntry entry) async {
    try {
      await _entries.add(shoppingEntryToFirestore(entry));
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }

  @override
  Future<Result<void, DataFailure>> remove(String entryId) async {
    try {
      await _entries.doc(entryId).delete();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }
}
