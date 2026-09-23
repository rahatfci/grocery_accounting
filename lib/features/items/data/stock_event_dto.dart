import 'package:cloud_firestore/cloud_firestore.dart';

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
