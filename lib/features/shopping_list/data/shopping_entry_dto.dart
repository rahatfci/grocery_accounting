import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/shopping_entry.dart';

/// The full body of a `shoppingList` document.
///
/// `done` is always false. Ticking an entry deletes it, so the flag is never
/// read, but documents keep the planned shape.
Map<String, Object?> shoppingEntryToFirestore(ShoppingEntry entry) => {
  'text': entry.text,
  'itemId': entry.itemId,
  'addedByUserId': entry.addedByUserId,
  'addedAt': Timestamp.fromDate(entry.addedAt),
  'done': false,
};

/// Reads a document body into a [ShoppingEntry]. [id] is the document id,
/// which is never part of the body.
///
/// Read defensively: the list is shared, and one malformed document must
/// render rather than break it for everyone.
ShoppingEntry shoppingEntryFromFirestore(
  String id,
  Map<String, Object?> data,
) => ShoppingEntry(
  id: id,
  text: _string(data['text']),
  itemId: _optionalString(data['itemId']),
  addedByUserId: _string(data['addedByUserId']),
  addedAt: _dateTime(data['addedAt']),
);

String _string(Object? value) => value is String ? value : '';

String? _optionalString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Every write stamps a client timestamp, so an unreadable one means the
/// document was written outside the app.
DateTime _dateTime(Object? value) => value is Timestamp
    ? value.toDate()
    : DateTime.fromMillisecondsSinceEpoch(0);
