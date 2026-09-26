import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/account/presentation/account_page.dart';
import 'package:grocery_accounting/features/home/presentation/home_tab.dart';
import 'package:grocery_accounting/features/items/presentation/pantry_tab.dart';
import 'package:grocery_accounting/features/reports/presentation/spending_tab.dart';
import 'package:grocery_accounting/features/shell/presentation/app_navigation_bar.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_tab.dart';

import '../shell_harness.dart';

void main() {
  late ShellFakes fakes;

  setUp(() => fakes = ShellFakes());

  testWidgets('opens on Home with the four destinations', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    expect(find.byType(HomeTab), findsOneWidget);
    expect(find.byType(AppNavigationBar), findsOneWidget);
    for (final label in ['Home', 'Pantry', 'List', 'Spending']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
  });

  testWidgets('the navigation moves between the tabs', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    await tester.tap(find.bySemanticsLabel('List'));
    await tester.pumpAndSettle();
    expect(find.byType(ShoppingListTab), findsOneWidget);
    expect(find.byType(HomeTab), findsNothing);

    await tester.tap(find.bySemanticsLabel('Pantry'));
    await tester.pump();
    expect(find.byType(PantryTab), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Spending'));
    await tester.pump();
    expect(find.byType(SpendingTab), findsOneWidget);
  });

  testWidgets('back on another tab goes Home before leaving the app', (
    tester,
  ) async {
    usePhone(tester);
    await pumpShell(tester, fakes);
    await tester.tap(find.bySemanticsLabel('List'));
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(HomeTab), findsOneWidget);
  });

  testWidgets('a pushed screen covers the navigation, and back returns', (
    tester,
  ) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.byType(AppNavigationBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsNothing);
    expect(find.byType(AppNavigationBar), findsOneWidget);
  });

  testWidgets('a wide window puts the destinations on a rail', (tester) async {
    usePhone(tester, size: const Size(1200, 800));
    await pumpShell(tester, fakes);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(AppNavigationBar), findsNothing);
  });

  testWidgets('flushes queued receipts on open and again on resume', (
    tester,
  ) async {
    usePhone(tester);
    await pumpShell(tester, fakes);
    expect(fakes.store.flushes, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(fakes.store.flushes, 2);
  });
}
