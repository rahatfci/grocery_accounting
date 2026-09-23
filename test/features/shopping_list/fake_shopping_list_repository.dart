import 'dart:async';

import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/shopping_list/data/shopping_list_repository.dart';
import 'package:grocery_accounting/features/shopping_list/logic/shopping_entry.dart';

/// An entry as the repository would hand it back: it already has a document
/// id.
ShoppingEntry testEntry({
  String id = 'e1',
  String text = 'Milk',
  String? itemId,
  String addedByUserId = 'abc123',
  DateTime? addedAt,
}) => ShoppingEntry(
  id: id,
  text: text,
  itemId: itemId,
  addedByUserId: addedByUserId,
  addedAt: addedAt ?? DateTime(2026, 9, 20, 9),
);

class FakeShoppingListRepository implements ShoppingListRepository {
  /// One per `watchEntries()` call, because `snapshots()` hands back a new
  /// stream each time and a retry has to be able to listen again.
  final _controllers = <StreamController<List<ShoppingEntry>>>[];

  final added = <ShoppingEntry>[];
  final removed = <String>[];

  Result<void, DataFailure> addResult = const Ok(null);
  Object? addThrows;

  Result<void, DataFailure> removeResult = const Ok(null);
  Object? removeThrows;

  /// When set, a write waits on this instead of returning at once.
  Completer<void>? writeGate;

  /// When set, every new watch reports this at once, so a screen that only
  /// needs the list to have answered can settle.
  List<ShoppingEntry>? initialEntries;

  int get watchCalls => _controllers.length;

  bool get hasListener =>
      _controllers.isNotEmpty && _controllers.last.hasListener;

  void emitEntries(List<ShoppingEntry> entries) =>
      _controllers.last.add(entries);

  void emitError(Object error) => _controllers.last.addError(error);

  @override
  Stream<List<ShoppingEntry>> watchEntries() {
    final controller = StreamController<List<ShoppingEntry>>();
    _controllers.add(controller);
    if (initialEntries case final entries?) {
      controller.add(entries);
    }
    return controller.stream;
  }

  @override
  Future<Result<void, DataFailure>> add(ShoppingEntry entry) async {
    added.add(entry);
    await writeGate?.future;
    final thrown = addThrows;
    if (thrown != null) {
      throw thrown;
    }
    return addResult;
  }

  @override
  Future<Result<void, DataFailure>> remove(String entryId) async {
    removed.add(entryId);
    await writeGate?.future;
    final thrown = removeThrows;
    if (thrown != null) {
      throw thrown;
    }
    return removeResult;
  }
}
