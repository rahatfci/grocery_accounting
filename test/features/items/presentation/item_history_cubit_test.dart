import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/logic/item_history.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';
import 'package:grocery_accounting/features/items/presentation/item_history_cubit.dart';
import 'package:grocery_accounting/features/items/presentation/item_history_state.dart';

import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

void main() {
  late FakeItemRepository items;
  late FakePurchaseRepository purchases;

  setUp(() {
    items = FakeItemRepository();
    purchases = FakePurchaseRepository();
  });

  ItemHistoryCubit build() =>
      ItemHistoryCubit(items, purchases, itemId: 'rice');

  final used = StockEventRecord(
    id: 'e1',
    date: DateTime(2026, 9, 24),
    event: const StockEvent(
      itemId: 'rice',
      type: StockEventType.consumed,
      quantity: 0.2,
      unit: ItemUnit.kg,
      userId: 'u1',
    ),
  );

  test('asks for the item\'s events and purchases only', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(items.eventControllers.single.itemId, 'rice');
    expect(purchases.itemControllers.single.itemId, 'rice');
  });

  test('waits for the item, its events and its purchases', () async {
    final cubit = build();
    addTearDown(cubit.close);

    items.emitItems([testItem(id: 'rice')]);
    items.emitEvents([used]);
    await pumpEventQueue();
    expect(cubit.state, const ItemHistoryLoading());

    purchases.emitItemPurchases([
      testPurchase(
        date: DateTime(2026, 9, 20),
        lines: [testLine(itemId: 'rice')],
      ),
    ]);
    await pumpEventQueue();

    final state = cubit.state as ItemHistoryLoaded;
    expect(state.entries.map((entry) => entry.kind), [
      HistoryKind.use,
      HistoryKind.purchase,
    ]);
  });

  test('an item that has gone has no history', () async {
    final cubit = build();
    addTearDown(cubit.close);

    items.emitItems(const []);
    items.emitEvents([used]);
    purchases.emitItemPurchases(const []);
    await pumpEventQueue();

    expect(cubit.state, const ItemHistoryLoaded([]));
  });

  test('a failure is shown and can be retried', () async {
    final cubit = build();
    addTearDown(cubit.close);

    items.emitEventsError(const PermissionDenied());
    await pumpEventQueue();
    expect(cubit.state, const ItemHistoryFailure(PermissionDenied()));

    cubit.retry();

    expect(cubit.state, const ItemHistoryLoading());
    expect(items.eventControllers, hasLength(2));
  });
}
