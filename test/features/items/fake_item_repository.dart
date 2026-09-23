import 'dart:async';

import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';

/// An item as the repository would hand it back: it already has a document id.
Item testItem({
  String id = 'abc123',
  String name = 'Rice',
  ItemUnit unit = ItemUnit.kg,
  String category = 'pantry',
  double? avgPieceWeight,
  double dailyUsage = 0.25,
  double lowThreshold = 2,
}) => Item(
  id: id,
  name: name,
  unit: unit,
  category: category,
  avgPieceWeight: avgPieceWeight,
  dailyUsage: dailyUsage,
  lowThreshold: lowThreshold,
  stockAtBaseline: 0,
  baselineDate: DateTime(2026, 9, 1, 10, 30),
);

/// An item as the form would build it before it has ever been written.
Item newTestItem({String name = 'Rice'}) => testItem(id: '', name: name);

class FakeItemRepository implements ItemRepository {
  /// One per `watchItems()` call, because `snapshots()` hands back a new
  /// stream each time and a retry has to be able to listen again.
  final _controllers = <StreamController<List<Item>>>[];

  Result<void, DataFailure> createResult = const Ok(null);
  Result<void, DataFailure> updateResult = const Ok(null);
  Object? createThrows;
  Object? updateThrows;

  Result<void, DataFailure> deleteResult = const Ok(null);
  Object? deleteThrows;

  Result<void, DataFailure> recordResult = const Ok(null);
  Object? recordThrows;

  final created = <Item>[];
  final updated = <Item>[];
  final deleted = <Item>[];

  /// Each recorded event with the item version and clock it was recorded
  /// against.
  final recorded = <({Item item, StockEvent event, DateTime now})>[];

  /// When set, a write waits on this instead of returning at once, so a test
  /// can observe the saving state.
  Completer<void>? writeGate;

  /// When set, every new watch reports this at once, so a screen that only
  /// needs the catalogue to have answered can settle.
  List<Item>? initialItems;

  int get watchCalls => _controllers.length;

  bool get hasListener =>
      _controllers.isNotEmpty && _controllers.last.hasListener;

  void emitItems(List<Item> items) => _controllers.last.add(items);

  /// Reports [items] to every watch, as Firestore does for each listener.
  void emitItemsToAll(List<Item> items) {
    for (final controller in _controllers) {
      controller.add(items);
    }
  }

  void emitError(Object error) => _controllers.last.addError(error);

  @override
  Stream<List<Item>> watchItems() {
    final controller = StreamController<List<Item>>();
    _controllers.add(controller);
    if (initialItems case final items?) {
      controller.add(items);
    }
    return controller.stream;
  }

  @override
  Future<Result<void, DataFailure>> create(Item item) async {
    created.add(item);
    await writeGate?.future;
    final thrown = createThrows;
    if (thrown != null) {
      throw thrown;
    }
    return createResult;
  }

  @override
  Future<Result<void, DataFailure>> delete(Item item) async {
    deleted.add(item);
    await writeGate?.future;
    final thrown = deleteThrows;
    if (thrown != null) {
      throw thrown;
    }
    return deleteResult;
  }

  @override
  Future<Result<void, DataFailure>> update(Item item) async {
    updated.add(item);
    await writeGate?.future;
    final thrown = updateThrows;
    if (thrown != null) {
      throw thrown;
    }
    return updateResult;
  }

  @override
  Future<Result<void, DataFailure>> recordStockEvent(
    Item item,
    StockEvent event, {
    required DateTime now,
  }) async {
    recorded.add((item: item, event: event, now: now));
    await writeGate?.future;
    final thrown = recordThrows;
    if (thrown != null) {
      throw thrown;
    }
    return recordResult;
  }
}
