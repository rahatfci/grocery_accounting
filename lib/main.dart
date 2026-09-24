import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/error_reporting_bloc_observer.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/items/data/item_repository.dart';
import 'features/members/data/member_repository.dart';
import 'features/purchases/data/purchase_repository.dart';
import 'features/receipts/data/alias_repository.dart';
import 'features/receipts/data/receipt_picker.dart';
import 'features/receipts/data/receipt_reader.dart';
import 'features/receipts/data/receipt_store.dart';
import 'features/reports/data/csv_sharer.dart';
import 'features/reminders/data/run_out_notifier.dart';
import 'features/shopping_list/data/shopping_list_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Web defaults the on-disk cache to off, so offline capture needs this set
  // explicitly rather than relying on the mobile default. Without the multi-tab
  // manager only one browser tab holds the IndexedDB lease and every other tab
  // silently runs without persistence.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
  Bloc.observer = const ErrorReportingBlocObserver();
  configureDependencies();
  runApp(
    GroceryAccountingApp(
      authCubit: getIt<AuthCubit>(),
      itemRepository: getIt<ItemRepository>(),
      memberRepository: getIt<MemberRepository>(),
      purchaseRepository: getIt<PurchaseRepository>(),
      runOutNotifier: getIt<RunOutNotifier>(),
      shoppingListRepository: getIt<ShoppingListRepository>(),
      receiptPicker: getIt<ReceiptPicker>(),
      receiptStore: getIt<ReceiptStore>(),
      receiptReader: getIt<ReceiptReader>(),
      aliasRepository: getIt<AliasRepository>(),
      csvSharer: getIt<CsvSharer>(),
    ),
  );
}
