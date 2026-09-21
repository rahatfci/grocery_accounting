import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/item.dart';
import 'item_dto.dart';
import 'item_repository.dart';

@LazySingleton(as: ItemRepository)
class FirestoreItemRepository implements ItemRepository {
  const FirestoreItemRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('items');

  @override
  Stream<List<Item>> watchItems() => _items
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs) itemFromFirestore(doc.id, doc.data()),
        ],
      );

  @override
  Future<Result<void, DataFailure>> create(Item item) => _write(
    () => _items.add(
      newItemToFirestore(item, baselineDate: FieldValue.serverTimestamp()),
    ),
  );

  /// `update` rather than `set`: it touches only the keys it is given, so the
  /// baseline pair survives an edit untouched.
  @override
  Future<Result<void, DataFailure>> update(Item item) =>
      _write(() => _items.doc(item.id).update(itemToFirestore(item)));

  Future<Result<void, DataFailure>> _write(Future<void> Function() write) async {
    try {
      await write();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(dataFailureFromCode(e.code));
    }
  }
}
