import 'package:cloud_firestore/cloud_firestore.dart';

import '../../items/logic/item_unit.dart';
import '../logic/purchase.dart';
import '../logic/purchase_source.dart';

/// The full body of a `purchases` document.
Map<String, Object?> purchaseToFirestore(Purchase purchase) => {
  'date': Timestamp.fromDate(purchase.date),
  'shopName': purchase.shopName,
  'total': purchase.total,
  'paidByUserId': purchase.paidByUserId,
  'receiptImagePath': purchase.receiptImagePath,
  'source': purchase.source.key,
  'lines': [for (final line in purchase.lines) _lineToFirestore(line)],
  // Denormalized from `lines` so the catalogue can ask whether an item is
  // still referenced. Firestore cannot query a field inside an array of maps,
  // so the ids have to be queryable on their own.
  'itemIds': purchase.itemIds,
};

Map<String, Object?> _lineToFirestore(PurchaseLine line) => {
  'itemId': line.itemId,
  'rawText': line.rawText,
  'quantity': line.quantity,
  'unit': line.unit.key,
  'lineTotal': line.lineTotal,
};

/// Reads a document body into a [Purchase]. [id] is the document id, which is
/// never part of the body.
///
/// Every field is read defensively: these documents are shared, and a missing
/// or wrongly typed field must render rather than break a report.
Purchase purchaseFromFirestore(String id, Map<String, Object?> data) =>
    Purchase(
      id: id,
      date: _dateTime(data['date']),
      shopName: _string(data['shopName']),
      total: _double(data['total']),
      paidByUserId: _string(data['paidByUserId']),
      receiptImagePath: _optionalString(data['receiptImagePath']),
      source: PurchaseSource.fromKey(_string(data['source'])),
      lines: _lines(data['lines']),
    );

List<PurchaseLine> _lines(Object? value) => value is List
    ? [
        for (final entry in value)
          if (entry is Map<Object?, Object?>) _lineFromFirestore(entry),
      ]
    : const [];

PurchaseLine _lineFromFirestore(Map<Object?, Object?> data) => PurchaseLine(
  itemId: _optionalString(data['itemId']),
  rawText: _string(data['rawText']),
  quantity: _double(data['quantity']),
  unit: ItemUnit.fromKey(_string(data['unit'])),
  lineTotal: _double(data['lineTotal']),
);

String _string(Object? value) => value is String ? value : '';

String? _optionalString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

double _double(Object? value) => value is num ? value.toDouble() : 0;

/// A purchase always writes a client timestamp, so an unreadable date means a
/// malformed document rather than a write still waiting on the server.
DateTime _dateTime(Object? value) =>
    value is Timestamp ? value.toDate() : DateTime.now();
