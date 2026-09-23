import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_section.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';

import '../../items/fake_item_repository.dart';

void main() {
  final baseline = DateTime(2026, 9, 1, 10, 30);
  late FakeItemRepository repository;
  late RunningLowCubit cubit;

  setUp(() => repository = FakeItemRepository());

  // Built inside the test, so its subscription runs in the widget test's fake
  // async zone and `pump` delivers the stream's events.
  Future<void> pumpSection(WidgetTester tester) {
    cubit = RunningLowCubit(repository, clock: () => baseline);
    addTearDown(cubit.close);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CustomScrollView(slivers: [RunningLowSection()]),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a spinner under the heading while loading', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Running low'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says when nothing is running low', (tester) async {
    await pumpSection(tester);

    repository.emitItems([
      testItem().copyWith(stockAtBaseline: 5, baselineDate: baseline),
    ]);
    await tester.pump();

    expect(find.text('Nothing is running low'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists each low item with its stock and threshold', (
    tester,
  ) async {
    await pumpSection(tester);

    repository.emitItems([
      testItem(
        id: 'rice',
        name: 'Rice',
        lowThreshold: 2,
      ).copyWith(stockAtBaseline: 0.5, baselineDate: baseline),
      testItem(
        id: 'eggs',
        name: 'Eggs',
        unit: ItemUnit.pcs,
        lowThreshold: 6,
      ).copyWith(stockAtBaseline: 0, baselineDate: baseline),
    ]);
    await tester.pump();

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('0.5 kg'), findsOneWidget);
    expect(find.text('Below 2 kg'), findsOneWidget);
    expect(find.text('0 pcs'), findsOneWidget);
    expect(find.text('Below 6 pcs'), findsOneWidget);
    // Out of stock comes first.
    expect(
      tester.getTopLeft(find.text('Eggs')).dy,
      lessThan(tester.getTopLeft(find.text('Rice')).dy),
    );
  });

  testWidgets('a long name truncates rather than overflowing', (tester) async {
    await pumpSection(tester);

    repository.emitItems([
      testItem(
        name: 'Extra virgin olive oil from the cousin in Puglia, 5 L tin' * 3,
        lowThreshold: 2,
      ).copyWith(stockAtBaseline: 1, baselineDate: baseline),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the failure and retries on request', (tester) async {
    await pumpSection(tester);

    repository.emitError(const PermissionDenied());
    await tester.pump();

    expect(find.text(const PermissionDenied().message), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(repository.watchCalls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
