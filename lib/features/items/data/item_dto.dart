import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/item_unit.dart';

/// The `items` fields an edit is allowed to write.
///
/// `stockAtBaseline` and `baselineDate` are deliberately absent: they are the
/// pantry half, written once by [newItemToFirestore] and owned by the stock
/// features from then on. Rewriting them on an edit would reset an item's
/// stock every time someone corrected its name.
Map<String, Object?> itemToFirestore(Item item) => {
  'name': item.name,
  'unit': item.unit.key,
  'category': item.category,
  'avgPieceWeight': item.avgPieceWeight,
  'dailyUsage': item.dailyUsage,
  'lowThreshold': item.lowThreshold,
};

/// The full body of a new `items` document.
///
/// [baselineDate] is passed in rather than read here so this stays a pure map
/// conversion: the repository supplies `FieldValue.serverTimestamp()`, a test
/// supplies a `Timestamp`. A new item has no stock until a purchase restocks
/// it, so the baseline is zero.
Map<String, Object?> newItemToFirestore(
  Item item, {
  required Object baselineDate,
}) => {
  ...itemToFirestore(item),
  'stockAtBaseline': 0.0,
  'baselineDate': baselineDate,
};

/// Reads a document body into an [Item]. [id] is the document id, which is
/// never part of the body.
///
/// Every field is read defensively: these documents are shared, and a missing
/// or wrongly typed field must render rather than crash the list.
Item itemFromFirestore(String id, Map<String, Object?> data) => Item(
  id: id,
  name: _string(data['name'], fallback: ''),
  unit: ItemUnit.fromKey(_string(data['unit'], fallback: '')),
  category: _string(data['category'], fallback: BuiltInCategory.other.key),
  avgPieceWeight: _optionalDouble(data['avgPieceWeight']),
  dailyUsage: _double(data['dailyUsage']),
  lowThreshold: _double(data['lowThreshold']),
  stockAtBaseline: _double(data['stockAtBaseline']),
  baselineDate: _dateTime(data['baselineDate']),
);

String _string(Object? value, {required String fallback}) =>
    value is String && value.isNotEmpty ? value : fallback;

double _double(Object? value) => value is num ? value.toDouble() : 0;

double? _optionalDouble(Object? value) => value is num ? value.toDouble() : null;

/// A server timestamp reads back as null from the local cache until the server
/// acknowledges the write, so a still-pending baseline is approximated as now.
DateTime _dateTime(Object? value) =>
    value is Timestamp ? value.toDate() : DateTime.now();
