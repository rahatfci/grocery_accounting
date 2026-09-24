import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/items/data/item_repository.dart';
import 'features/members/data/member_repository.dart';
import 'features/purchases/data/purchase_repository.dart';
import 'features/receipts/data/alias_repository.dart';
import 'features/receipts/data/receipt_picker.dart';
import 'features/receipts/data/receipt_reader.dart';
import 'features/receipts/data/receipt_store.dart';
import 'features/reminders/data/run_out_notifier.dart';
import 'features/shopping_list/data/shopping_list_repository.dart';

class GroceryAccountingApp extends StatelessWidget {
  const GroceryAccountingApp({
    required this.authCubit,
    required this.itemRepository,
    required this.memberRepository,
    required this.purchaseRepository,
    required this.runOutNotifier,
    required this.shoppingListRepository,
    required this.receiptPicker,
    required this.receiptStore,
    required this.receiptReader,
    required this.aliasRepository,
    super.key,
  });

  /// Resolved in `main`, so no widget reaches into the service locator.
  final AuthCubit authCubit;

  /// Also resolved in `main`. The catalogue builds its own cubit from this
  /// when it opens, rather than holding a Firestore subscription open from
  /// launch, before anyone has signed in.
  final ItemRepository itemRepository;

  /// Resolved in `main` as well. The auth gate writes the mirror document
  /// through it, and the purchase screen reads the payer list from it.
  final MemberRepository memberRepository;

  /// Resolved in `main` as well. The purchase screen writes through it, and
  /// the catalogue asks it whether an item can still be deleted.
  final PurchaseRepository purchaseRepository;

  /// Resolved in `main` as well. Home schedules run-out reminders through it.
  final RunOutNotifier runOutNotifier;

  /// Resolved in `main` as well. Home shows the list through it, and the
  /// purchase screen clears what a purchase covers.
  final ShoppingListRepository shoppingListRepository;

  /// Resolved in `main` as well. The purchase screen picks receipt photos
  /// through the picker and keeps them through the store; Home flushes the
  /// store's upload queue.
  final ReceiptPicker receiptPicker;
  final ReceiptStore receiptStore;

  /// Resolved in `main` as well. The purchase screen reads receipts through it.
  final ReceiptReader receiptReader;

  /// Resolved in `main` as well. The purchase screen applies learned receipt
  /// mappings from it.
  final AliasRepository aliasRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: itemRepository),
        RepositoryProvider.value(value: memberRepository),
        RepositoryProvider.value(value: purchaseRepository),
        RepositoryProvider.value(value: runOutNotifier),
        RepositoryProvider.value(value: shoppingListRepository),
        RepositoryProvider.value(value: receiptPicker),
        RepositoryProvider.value(value: receiptStore),
        RepositoryProvider.value(value: receiptReader),
        RepositoryProvider.value(value: aliasRepository),
      ],
      child: BlocProvider(
        create: (_) => authCubit,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Grocery Accounting di Quattro Nero',
          color: Colors.white,
          theme: AppTheme.light,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
