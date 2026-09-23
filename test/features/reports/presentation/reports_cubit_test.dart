import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/reports/presentation/reports_cubit.dart';
import 'package:grocery_accounting/features/reports/presentation/reports_state.dart';

import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';

/// Records what a cubit reports through `addError`, which is how an
/// unexpected failure is meant to leave the app rather than being swallowed.
class RecordingBlocObserver extends BlocObserver {
  final reported = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    reported.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  /// A fixed clock, so the current month is September 2026 in every test.
  final now = DateTime(2026, 9, 22, 18, 30);
  final september = DateTime(2026, 9);
  final august = DateTime(2026, 8);
  final july = DateTime(2026, 7);
  final october = DateTime(2026, 10);

  late FakePurchaseRepository purchases;
  late FakeItemRepository items;
  late FakeMemberRepository members;
  late RecordingBlocObserver observer;

  setUp(() {
    purchases = FakePurchaseRepository();
    items = FakeItemRepository();
    members = FakeMemberRepository();
    observer = RecordingBlocObserver();
    Bloc.observer = observer;
  });

  tearDown(() => Bloc.observer = RecordingBlocObserver());

  ReportsCubit build() => ReportsCubit(
    purchases: purchases,
    items: items,
    members: members,
    now: () => now,
  );

  /// Reports everything the screen needs, so a test can get to the loaded
  /// state in one line.
  Future<void> reportAll(ReportsCubit cubit, {List<Purchase>? window}) async {
    purchases.emitPurchases(window ?? [testPurchase()]);
    items.emitItems([testItem()]);
    members.emitMembers([testMember()]);
    await pumpEventQueue();
  }

  group('opening the screen', () {
    test('starts loading on the current month', () {
      final cubit = build();

      expect(cubit.state, ReportsLoading(month: september, canViewNext: false));

      cubit.close();
    });

    test('asks for a window covering the previous month and this one', () {
      final cubit = build();

      expect(purchases.windows.single.from, august);
      expect(purchases.windows.single.toExclusive, october);

      cubit.close();
    });

    test('stays loading until all three collections have reported', () async {
      final cubit = build();

      purchases.emitPurchases([testPurchase()]);
      await pumpEventQueue();
      expect(cubit.state, isA<ReportsLoading>());

      items.emitItems([testItem()]);
      await pumpEventQueue();
      expect(cubit.state, isA<ReportsLoading>());

      members.emitMembers([testMember()]);
      await pumpEventQueue();
      expect(cubit.state, isA<ReportsLoaded>());

      await cubit.close();
    });

    test('builds the report from all three collections', () async {
      final cubit = build();

      purchases.emitPurchases([
        testPurchase(
          total: 30,
          paidByUserId: 'one',
          lines: [testLine(itemId: 'i1', lineTotal: 12)],
        ),
      ]);
      items.emitItems([testItem(id: 'i1', category: 'produce')]);
      members.emitMembers([testMember(id: 'one', displayName: 'rahat')]);
      await pumpEventQueue();

      final state = cubit.state;
      expect(state, isA<ReportsLoaded>());
      final report = (state as ReportsLoaded).report;
      expect(report.monthTotal, 30);
      expect(report.byPerson.single.displayName, 'rahat');
      expect(report.byCategory.first.label, 'Produce');

      await cubit.close();
    });

    test('a month with nothing in it still loads', () async {
      final cubit = build();
      await reportAll(cubit, window: const []);

      final state = cubit.state;
      expect(state, isA<ReportsLoaded>());
      expect((state as ReportsLoaded).report.isEmpty, isTrue);

      await cubit.close();
    });
  });

  group('changing the month', () {
    test('showPreviousMonth loads the month before', () async {
      final cubit = build();
      await reportAll(cubit);

      cubit.showPreviousMonth();

      expect(cubit.state, ReportsLoading(month: august, canViewNext: true));

      await cubit.close();
    });

    test('showPreviousMonth re-queries the shifted window', () async {
      final cubit = build();
      await reportAll(cubit);

      cubit.showPreviousMonth();

      expect(purchases.windows.length, 2);
      expect(purchases.windows.last.from, july);
      expect(purchases.windows.last.toExclusive, september);

      await cubit.close();
    });

    test('the new month loads once its window reports', () async {
      final cubit = build();
      await reportAll(cubit);

      cubit.showPreviousMonth();
      purchases.emitPurchases([testPurchase(date: DateTime(2026, 8, 3))]);
      await pumpEventQueue();

      final state = cubit.state;
      expect(state, isA<ReportsLoaded>());
      expect(state.month, august);
      expect((state as ReportsLoaded).report.month, august);

      await cubit.close();
    });

    test('showNextMonth refuses to leave the current month', () async {
      final cubit = build();
      await reportAll(cubit);
      final before = cubit.state;

      cubit.showNextMonth();

      expect(cubit.state, before);
      expect(purchases.windows.length, 1);

      await cubit.close();
    });

    test('showNextMonth moves forward from an earlier month', () async {
      final cubit = build();
      await reportAll(cubit);

      cubit.showPreviousMonth();
      cubit.showNextMonth();

      expect(cubit.state.month, september);
      expect(cubit.state.canViewNext, isFalse);
      expect(purchases.windows.length, 3);

      await cubit.close();
    });

    test('the catalogue and the household are not re-subscribed', () async {
      final cubit = build();
      await reportAll(cubit);

      cubit.showPreviousMonth();

      expect(items.watchCalls, 1);
      expect(members.watchCalls, 1);

      await cubit.close();
    });
  });

  group('failures', () {
    test('a purchase stream failure keeps the month on screen', () async {
      final cubit = build();
      await reportAll(cubit);

      purchases.emitPurchasesError(const PermissionDenied());
      await pumpEventQueue();

      expect(
        cubit.state,
        ReportsFailure(
          failure: const PermissionDenied(),
          month: september,
          canViewNext: false,
        ),
      );

      await cubit.close();
    });

    test('a catalogue failure is a failure too', () async {
      final cubit = build();
      await reportAll(cubit);

      items.emitError(const ConnectionUnavailable());
      await pumpEventQueue();

      expect(cubit.state, isA<ReportsFailure>());

      await cubit.close();
    });

    test('a household failure is a failure too', () async {
      final cubit = build();
      await reportAll(cubit);

      members.emitError(const ConnectionUnavailable());
      await pumpEventQueue();

      expect(cubit.state, isA<ReportsFailure>());

      await cubit.close();
    });

    test('an unmapped error still renders', () async {
      final cubit = build();

      purchases.emitPurchasesError(StateError('nobody mapped this'));
      await pumpEventQueue();

      final state = cubit.state;
      expect(state, isA<ReportsFailure>());
      expect((state as ReportsFailure).failure, const UnexpectedDataFailure());

      await cubit.close();
    });

    test('a failure is reported, not just swallowed', () async {
      final cubit = build();

      purchases.emitPurchasesError(const PermissionDenied());
      await pumpEventQueue();

      expect(observer.reported, [const PermissionDenied()]);

      await cubit.close();
    });

    test('a failure on an earlier month keeps that month', () async {
      final cubit = build();
      await reportAll(cubit);

      cubit.showPreviousMonth();
      purchases.emitPurchasesError(const PermissionDenied());
      await pumpEventQueue();

      expect(cubit.state.month, august);
      expect(cubit.state.canViewNext, isTrue);

      await cubit.close();
    });

    test('retry subscribes to all three again', () async {
      final cubit = build();
      purchases.emitPurchasesError(const PermissionDenied());
      await pumpEventQueue();

      cubit.retry();

      expect(cubit.state, isA<ReportsLoading>());
      expect(purchases.windows.length, 2);
      expect(items.watchCalls, 2);
      expect(members.watchCalls, 2);

      await cubit.close();
    });

    test('retry recovers on the month that failed', () async {
      final cubit = build();
      await reportAll(cubit);
      cubit.showPreviousMonth();
      purchases.emitPurchasesError(const PermissionDenied());
      await pumpEventQueue();

      cubit.retry();
      await reportAll(cubit, window: const []);

      expect(cubit.state, isA<ReportsLoaded>());
      expect(cubit.state.month, august);

      await cubit.close();
    });
  });

  test('closing cancels every subscription', () async {
    final cubit = build();
    await reportAll(cubit);

    await cubit.close();

    expect(purchases.hasWindowListener, isFalse);
    expect(items.hasListener, isFalse);
    expect(members.hasListener, isFalse);
  });
}
