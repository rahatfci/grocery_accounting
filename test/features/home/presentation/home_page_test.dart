import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/home_page.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_section.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/items/presentation/item_list_page.dart';
import 'package:grocery_accounting/features/members/data/member_repository.dart';
import 'package:grocery_accounting/features/purchases/data/purchase_repository.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_page.dart';
import 'package:grocery_accounting/features/reports/presentation/reports_page.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  FakeAuthRepository authRepository,
  FakeItemRepository itemRepository, {
  FakeMemberRepository? memberRepository,
  FakePurchaseRepository? purchaseRepository,
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
    // Home's own running low watch.
    expect(itemRepository.watchCalls, 2);
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
    // Items is watched once more by Home's running low section.
    expect(purchaseRepository.watchWindowCalls, 1);
    expect(itemRepository.watchCalls, 2);
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
      find.widgetWithText(FilledButton, 'Record a purchase'),
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

    await tester.tap(find.widgetWithText(FilledButton, 'Record a purchase'));
    await _pumpRouteTransition(tester);

    expect(find.byType(RecordPurchaseView), findsOneWidget);
    // The pushed screen built its own cubit and started watching both. Items
    // is watched once more by Home's running low section.
    expect(itemRepository.watchCalls, 2);
    expect(memberRepository.watchCalls, 1);
  });

  testWidgets('the review screen can be popped back to Home', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);
    await tester.tap(find.widgetWithText(FilledButton, 'Record a purchase'));
    await _pumpRouteTransition(tester);

    await tester.tap(find.byTooltip('Back'));
    await _pumpRouteTransition(tester);

    expect(find.byType(RecordPurchaseView), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Record a purchase'),
      findsOneWidget,
    );
  });

  testWidgets('shows running low from the catalogue', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    expect(find.byType(RunningLowSection), findsOneWidget);
    expect(itemRepository.watchCalls, 1);

    itemRepository.emitItems([
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
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: HomeView(user: testUser)),
      ),
    );
    // Half a kilo a day from 3 kg against a threshold of 2: not low at the
    // baseline, low three days later, with no write to the item between.
    itemRepository.emitItems([
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
}
