import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/item_unit.dart';
import '../logic/stock_event.dart';

/// The body of a new `consumptionEvents` document.
///
/// [date] is passed in, not read here, so it can be the same client timestamp
/// as the item's new `baselineDate`. The two are one pair.
Map<String, Object?> stockEventToFirestore(
  StockEvent event, {
  required Timestamp date,
}) => {
  'itemId': event.itemId,
  'quantity': event.quantity,
  'unit': event.unit.key,
  'date': date,
  'userId': event.userId,
  'type': event.type.key,
  'note': event.note,
};

/// Reads a `consumptionEvents` document, or null when it cannot say what
/// happened: an event with no item, no known type or no date would only
/// mislead the history it is shown in.
StockEventRecord? stockEventFromFirestore(
  String id,
  Map<String, Object?> data,
) {
  final itemId = data['itemId'];
  final type = StockEventType.fromKey(
    data['type'] is String ? data['type'] as String : '',
  );
  final quantity = data['quantity'];
  final date = data['date'];
  if (itemId is! String ||
      itemId.isEmpty ||
      type == null ||
      quantity is! num ||
      date is! Timestamp) {
    return null;
  }
  final userId = data['userId'];
  final note = data['note'];
  return StockEventRecord(
    id: id,
    date: date.toDate(),
    event: StockEvent(
      itemId: itemId,
      type: type,
      quantity: quantity.toDouble(),
      unit: ItemUnit.fromKey(
        data['unit'] is String ? data['unit'] as String : '',
      ),
      userId: userId is String ? userId : '',
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    ),
  );
}
