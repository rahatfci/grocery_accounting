import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../core/data_failure.dart';
import '../logic/receipt_alias.dart';
import 'alias_dto.dart';
import 'alias_repository.dart';

@LazySingleton(as: AliasRepository)
class FirestoreAliasRepository implements AliasRepository {
  const FirestoreAliasRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<Map<String, ReceiptAlias>> watchAliases() => _firestore
      .collection('aliases')
      .snapshots()
      .map((snapshot) {
        final aliases = [
          for (final doc in snapshot.docs) ?aliasFromFirestore(doc.data()),
        ];
        return {for (final alias in aliases) alias.rawTextNormalized: alias};
      })
      .handleError(
        (Object error, StackTrace stackTrace) =>
            Error.throwWithStackTrace(dataFailureFromError(error), stackTrace),
      );
}
