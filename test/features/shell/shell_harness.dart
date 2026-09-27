import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/features/auth/logic/app_user.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/members/data/member_repository.dart';
import 'package:grocery_accounting/features/purchases/data/purchase_repository.dart';
import 'package:grocery_accounting/features/receipts/data/alias_repository.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_reader.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_store.dart';
import 'package:grocery_accounting/features/reminders/data/run_out_notifier.dart';
import 'package:grocery_accounting/features/reports/data/csv_sharer.dart';
import 'package:grocery_accounting/features/shell/presentation/app_navigation_bar.dart';
import 'package:grocery_accounting/features/shell/presentation/app_shell.dart';
import 'package:grocery_accounting/features/shopping_list/data/shopping_list_repository.dart';

import '../auth/fake_auth_repository.dart';
import '../items/fake_item_repository.dart';
import '../members/fake_member_repository.dart';
import '../purchases/fake_purchase_repository.dart';
import '../receipts/fake_receipts.dart';
import '../reminders/fake_run_out_notifier.dart';
import '../reports/fake_csv_sharer.dart';
import '../shopping_list/fake_shopping_list_repository.dart';

/// Every repository the signed-in app reads, faked. The collections answer
/// at once with nothing in them unless a test says otherwise.
class ShellFakes {
  final auth = FakeAuthRepository();
  final items = FakeItemRepository()..initialItems = const [];
  final members = FakeMemberRepository()..initialMembers = [testMember()];
  final purchases = FakePurchaseRepository()..initialPurchases = const [];
  final notifier = FakeRunOutNotifier();
  final shoppingList = FakeShoppingListRepository()..initialEntries = const [];
  final picker = FakeReceiptPicker();
  final store = FakeReceiptStore();
  final reader = FakeReceiptReader();
  final aliases = FakeAliasRepository();
  final sharer = FakeCsvSharer();

  List<RepositoryProvider<Object>> providers() => [
    RepositoryProvider<ItemRepository>.value(value: items),
    RepositoryProvider<MemberRepository>.value(value: members),
    RepositoryProvider<PurchaseRepository>.value(value: purchases),
    RepositoryProvider<RunOutNotifier>.value(value: notifier),
    RepositoryProvider<ShoppingListRepository>.value(value: shoppingList),
    RepositoryProvider<ReceiptPicker>.value(value: picker),
    RepositoryProvider<ReceiptStore>.value(value: store),
    RepositoryProvider<ReceiptReader>.value(value: reader),
    RepositoryProvider<AliasRepository>.value(value: aliases),
    RepositoryProvider<CsvSharer>.value(value: sharer),
  ];

  /// [child] with every repository and the session above it, the way the
  /// app provides them.
  Widget app(Widget child) => MultiRepositoryProvider(
    providers: providers(),
    child: BlocProvider(
      create: (_) => AuthCubit(auth),
      child: MaterialApp(theme: AppTheme.light, home: child),
    ),
  );
}

/// A phone the size the design is drawn at, unless a test asks for another.
void usePhone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpShell(
  WidgetTester tester,
  ShellFakes fakes, {
  AppUser user = testUser,
}) async {
  await tester.pumpWidget(fakes.app(AppShell(user: user)));
  await tester.pump();
}

/// Taps [label] on the bottom navigation, rather than any other control that
/// happens to share its name.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AppNavigationBar),
      matching: find.text(label),
    ),
  );
  // Tabs can open on a spinner, so settle a fixed time rather than forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
