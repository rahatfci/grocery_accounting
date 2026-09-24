import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/home_page.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_section.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/items/presentation/item_list_page.dart';
import 'package:grocery_accounting/features/members/data/member_repository.dart';
import 'package:grocery_accounting/features/purchases/data/purchase_repository.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_page.dart';
import 'package:grocery_accounting/features/reminders/data/run_out_notifier.dart';
import 'package:grocery_accounting/features/reminders/presentation/run_out_reminders_cubit.dart';
import 'package:grocery_accounting/features/reports/presentation/reports_page.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_reader.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_store.dart';
import 'package:grocery_accounting/features/receipts/presentation/receipt_uploads_cubit.dart';
import 'package:grocery_accounting/features/shopping_list/data/shopping_list_repository.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_cubit.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_section.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../../reminders/fake_run_out_notifier.dart';
import '../../receipts/fake_receipts.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  FakeAuthRepository authRepository,
  FakeItemRepository itemRepository, {
  FakeMemberRepository? memberRepository,
  FakePurchaseRepository? purchaseRepository,
  FakeRunOutNotifier? notifier,
  FakeShoppingListRepository? shoppingListRepository,
  FakeReceiptPicker? receiptPicker,
  FakeReceiptStore? receiptStore,
}) async {
  // The providers sit above MaterialApp exactly as they do in `app.dart`: a
  // pushed route is a sibling of `home`, so anything provided inside `home`
  // is invisible to it.
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ItemRepository>.value(value: itemRepository),
        RepositoryProvider<MemberRepository>.value(
          value: memberRepository ?? FakeMemberRepository(),
        ),
        RepositoryProvider<PurchaseRepository>.value(
          value: purchaseRepository ?? FakePurchaseRepository(),
        ),
        RepositoryProvider<RunOutNotifier>.value(
          value: notifier ?? FakeRunOutNotifier(),
        ),
        RepositoryProvider<ShoppingListRepository>.value(
          value: shoppingListRepository ?? FakeShoppingListRepository(),
        ),
        RepositoryProvider<ReceiptPicker>.value(
          value: receiptPicker ?? FakeReceiptPicker(),
        ),
        RepositoryProvider<ReceiptStore>.value(
          value: receiptStore ?? FakeReceiptStore(),
        ),
        RepositoryProvider<ReceiptReader>.value(value: FakeReceiptReader()),
      ],
      child: BlocProvider(
        create: (_) => AuthCubit(authRepository),
        child: const MaterialApp(home: HomePage(user: testUser)),
      ),
    ),
  );
}

/// The catalogue opens on an indeterminate spinner, which never stops
/// animating, so `pumpAndSettle` would time out. Pump the route transition
/// instead.
Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  // One more frame, so a popped route is unmounted and not just finished.
  await tester.pump();
}

ShoppingListCubit _shoppingListCubit(FakeItemRepository itemRepository) =>
    ShoppingListCubit(
      FakeShoppingListRepository(),
      itemRepository,
      currentUser: testUser,
    );

void main() {
  late FakeAuthRepository authRepository;
  late FakeItemRepository itemRepository;

  setUp(() {
    authRepository = FakeAuthRepository();
    itemRepository = FakeItemRepository();
  });

  testWidgets('offers a way into the catalogue', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    expect(find.byTooltip('Catalogue'), findsOneWidget);
  });

  testWidgets('the catalogue action pushes the catalogue', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    await tester.tap(find.byTooltip('Catalogue'));
    await _pumpRouteTransition(tester);

    expect(find.byType(ItemListPage), findsOneWidget);
    expect(find.text('Catalogue'), findsOneWidget);
    // The pushed screen built its own cubit and started watching, on top of
    // Home's running low, reminder and shopping list watches.
    expect(itemRepository.watchCalls, 4);
  });

  testWidgets('the catalogue can be popped back to Home', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);
    await tester.tap(find.byTooltip('Catalogue'));
    await _pumpRouteTransition(tester);

    await tester.tap(find.byTooltip('Back'));
    await _pumpRouteTransition(tester);

    expect(find.byType(ItemListPage), findsNothing);
    expect(find.byTooltip('Catalogue'), findsOneWidget);
  });

  testWidgets('offers a way into spending', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    expect(find.byTooltip('Spending'), findsOneWidget);
  });

  testWidgets('the spending action pushes the report', (tester) async {
    final memberRepository = FakeMemberRepository();
    final purchaseRepository = FakePurchaseRepository();
    await _pumpHome(
      tester,
      authRepository,
      itemRepository,
      memberRepository: memberRepository,
      purchaseRepository: purchaseRepository,
    );

    await tester.tap(find.byTooltip('Spending'));
    await _pumpRouteTransition(tester);

    expect(find.byType(ReportsView), findsOneWidget);
    // The pushed screen built its own cubit and started watching all three.
    // Items is also watched by Home's running low section, reminders and
    // shopping list.
    expect(purchaseRepository.watchWindowCalls, 1);
    expect(itemRepository.watchCalls, 4);
    expect(memberRepository.watchCalls, 1);
  });

  testWidgets('the report can be popped back to Home', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);
    await tester.tap(find.byTooltip('Spending'));
    await _pumpRouteTransition(tester);

    await tester.tap(find.byTooltip('Back'));
    await _pumpRouteTransition(tester);

    expect(find.byType(ReportsView), findsNothing);
    expect(find.byTooltip('Spending'), findsOneWidget);
  });

  testWidgets('signing out is still reachable', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    expect(authRepository.signOutCalls, 1);
  });

  testWidgets('leads with recording a purchase', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    expect(
      find.widgetWithText(OutlinedButton, 'Record a purchase'),
      findsOneWidget,
    );
  });

  testWidgets('recording a purchase pushes the review screen', (tester) async {
    final memberRepository = FakeMemberRepository();
    await _pumpHome(
      tester,
      authRepository,
      itemRepository,
      memberRepository: memberRepository,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Record a purchase'));
    await _pumpRouteTransition(tester);

    expect(find.byType(RecordPurchaseView), findsOneWidget);
    // The pushed screen built its own cubit and started watching both. Items
    // is also watched by Home's running low section, reminders and shopping
    // list.
    expect(itemRepository.watchCalls, 4);
    expect(memberRepository.watchCalls, 1);
  });

  testWidgets('the review screen can be popped back to Home', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Record a purchase'));
    await _pumpRouteTransition(tester);

    await tester.tap(find.byTooltip('Back'));
    await _pumpRouteTransition(tester);

    expect(find.byType(RecordPurchaseView), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Record a purchase'),
      findsOneWidget,
    );
  });

  testWidgets('shows running low from the catalogue', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    expect(find.byType(RunningLowSection), findsOneWidget);
    expect(itemRepository.watchCalls, 3);

    itemRepository.emitItemsToAll([
      testItem(lowThreshold: 2).copyWith(stockAtBaseline: 1, dailyUsage: 0),
    ]);
    await tester.pump();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Below 2 kg'), findsOneWidget);
  });

  testWidgets('re-judges running low when the app resumes', (tester) async {
    final baseline = DateTime(2026, 9, 1, 10, 30);
    var now = baseline;
    final cubit = RunningLowCubit(itemRepository, clock: () => now);
    addTearDown(cubit.close);
    final reminders = RunOutRemindersCubit(
      itemRepository,
      FakeRunOutNotifier(),
      clock: () => now,
    );
    addTearDown(reminders.close);
    final shoppingList = _shoppingListCubit(itemRepository);
    addTearDown(shoppingList.close);
    final uploads = ReceiptUploadsCubit(FakeReceiptStore());
    addTearDown(uploads.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: reminders),
          BlocProvider.value(value: shoppingList),
          BlocProvider.value(value: uploads),
        ],
        child: const MaterialApp(home: HomeView(user: testUser)),
      ),
    );
    // Half a kilo a day from 3 kg against a threshold of 2: not low at the
    // baseline, low three days later, with no write to the item between.
    itemRepository.emitItemsToAll([
      testItem(
        name: 'Pasta',
        dailyUsage: 0.5,
        lowThreshold: 2,
      ).copyWith(stockAtBaseline: 3, baselineDate: baseline),
    ]);
    await tester.pump();
    expect(find.text('Nothing is running low'), findsOneWidget);

    now = baseline.add(const Duration(days: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('1.5 kg'), findsOneWidget);
  });

  testWidgets('schedules run-out reminders from the catalogue', (tester) async {
    final notifier = FakeRunOutNotifier();
    await _pumpHome(tester, authRepository, itemRepository, notifier: notifier);
    final rice = testItem(
      dailyUsage: 1,
    ).copyWith(stockAtBaseline: 40, baselineDate: DateTime.now());

    itemRepository.emitItemsToAll([rice]);
    await tester.pump();

    expect(notifier.calls, hasLength(1));
    expect(notifier.calls.single.single.itemName, 'Rice');
  });

  testWidgets('re-plans run-out reminders when the app resumes', (
    tester,
  ) async {
    final baseline = DateTime(2026, 9, 1, 10, 30);
    var now = baseline;
    final notifier = FakeRunOutNotifier();
    final cubit = RunningLowCubit(itemRepository, clock: () => now);
    addTearDown(cubit.close);
    final reminders = RunOutRemindersCubit(
      itemRepository,
      notifier,
      clock: () => now,
    );
    addTearDown(reminders.close);
    final shoppingList = _shoppingListCubit(itemRepository);
    addTearDown(shoppingList.close);
    final uploads = ReceiptUploadsCubit(FakeReceiptStore());
    addTearDown(uploads.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: reminders),
          BlocProvider.value(value: shoppingList),
          BlocProvider.value(value: uploads),
        ],
        child: const MaterialApp(home: HomeView(user: testUser)),
      ),
    );
    // Runs out at 10:30 on 7 September, so the reminder is 09:00 on the 6th.
    itemRepository.emitItemsToAll([
      testItem(
        name: 'Pasta',
        dailyUsage: 0.5,
      ).copyWith(stockAtBaseline: 3, baselineDate: baseline),
    ]);
    await tester.pump();
    expect(notifier.calls.single, hasLength(1));

    now = DateTime(2026, 9, 6, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(notifier.calls, hasLength(2));
    expect(notifier.calls.last, isEmpty);
  });

  testWidgets('shows the shopping list below running low', (tester) async {
    final shoppingListRepository = FakeShoppingListRepository();
    await _pumpHome(
      tester,
      authRepository,
      itemRepository,
      shoppingListRepository: shoppingListRepository,
    );

    expect(find.byType(ShoppingListSection), findsOneWidget);
    expect(shoppingListRepository.watchCalls, 1);
    expect(
      tester.getTopLeft(find.text('Shopping list')).dy,
      greaterThan(tester.getTopLeft(find.text('Running low')).dy),
    );

    shoppingListRepository.emitEntries([testEntry(text: 'Milk')]);
    await tester.pump();

    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets('adds to the list as the signed-in member', (tester) async {
    final shoppingListRepository = FakeShoppingListRepository();
    await _pumpHome(
      tester,
      authRepository,
      itemRepository,
      shoppingListRepository: shoppingListRepository,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Add to the list'),
      'Bread',
    );
    await tester.tap(find.byTooltip('Add'));
    await tester.pump();

    expect(shoppingListRepository.added.single.addedByUserId, testUser.uid);
  });

  group('capturing a receipt', () {
    testWidgets('is the largest action on Home', (tester) async {
      await _pumpHome(tester, authRepository, itemRepository);

      final capture = find.widgetWithText(FilledButton, 'Capture receipt');
      final record = find.widgetWithText(OutlinedButton, 'Record a purchase');
      expect(capture, findsOneWidget);
      expect(
        tester.getSize(capture).height,
        greaterThan(tester.getSize(record).height),
      );
    });

    testWidgets('opens the review screen with the picked photo', (
      tester,
    ) async {
      final picker = FakeReceiptPicker();
      await _pumpHome(
        tester,
        authRepository,
        itemRepository,
        receiptPicker: picker,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Capture receipt'));
      await _pumpRouteTransition(tester);
      await tester.tap(find.text('Choose from gallery'));
      await _pumpRouteTransition(tester);

      expect(picker.sources, [ReceiptSource.gallery]);
      expect(find.byType(RecordPurchaseView), findsOneWidget);
    });

    testWidgets('dismissing the source sheet stays on Home', (tester) async {
      final picker = FakeReceiptPicker();
      await _pumpHome(
        tester,
        authRepository,
        itemRepository,
        receiptPicker: picker,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Capture receipt'));
      await _pumpRouteTransition(tester);
      await tester.tapAt(const Offset(10, 10));
      await _pumpRouteTransition(tester);

      expect(picker.sources, isEmpty);
      expect(find.byType(RecordPurchaseView), findsNothing);
    });

    testWidgets('a cancelled capture returns to Home', (tester) async {
      final picker = FakeReceiptPicker()..result = const Ok(null);
      await _pumpHome(
        tester,
        authRepository,
        itemRepository,
        receiptPicker: picker,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Capture receipt'));
      await _pumpRouteTransition(tester);
      await tester.tap(find.text('Take photo'));
      await _pumpRouteTransition(tester);
      await _pumpRouteTransition(tester);

      expect(picker.sources, [ReceiptSource.camera]);
      expect(find.byType(RecordPurchaseView), findsNothing);
      expect(find.text('Capture receipt'), findsOneWidget);
    });

    testWidgets('a denied capture returns to Home and says why', (
      tester,
    ) async {
      final picker = FakeReceiptPicker()
        ..result = const Err(ReceiptAccessDenied());
      await _pumpHome(
        tester,
        authRepository,
        itemRepository,
        receiptPicker: picker,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Capture receipt'));
      await _pumpRouteTransition(tester);
      await tester.tap(find.text('Take photo'));
      await _pumpRouteTransition(tester);
      await _pumpRouteTransition(tester);

      expect(find.byType(RecordPurchaseView), findsNothing);
      expect(find.text(const ReceiptAccessDenied().message), findsOneWidget);
    });
  });

  testWidgets('flushes queued receipts on open and on resume', (tester) async {
    final store = FakeReceiptStore();
    await _pumpHome(
      tester,
      authRepository,
      itemRepository,
      receiptStore: store,
    );
    await tester.pump();

    expect(store.flushes, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(store.flushes, 2);
  });
}
