// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as _i163;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as _i612;
import 'package:grocery_accounting/core/di/injection.dart' as _i368;
import 'package:grocery_accounting/features/auth/data/auth_repository.dart'
    as _i123;
import 'package:grocery_accounting/features/auth/data/firebase_auth_repository.dart'
    as _i883;
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart'
    as _i829;
import 'package:grocery_accounting/features/items/data/firestore_item_repository.dart'
    as _i549;
import 'package:grocery_accounting/features/items/data/item_repository.dart'
    as _i1028;
import 'package:grocery_accounting/features/members/data/firestore_member_repository.dart'
    as _i807;
import 'package:grocery_accounting/features/members/data/member_repository.dart'
    as _i726;
import 'package:grocery_accounting/features/purchases/data/firestore_purchase_repository.dart'
    as _i716;
import 'package:grocery_accounting/features/purchases/data/purchase_repository.dart'
    as _i384;
import 'package:grocery_accounting/features/receipts/data/image_picker_receipt_picker.dart'
    as _i179;
import 'package:grocery_accounting/features/receipts/data/ml_kit_receipt_reader.dart'
    as _i1045;
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart'
    as _i472;
import 'package:grocery_accounting/features/receipts/data/receipt_reader.dart'
    as _i691;
import 'package:grocery_accounting/features/receipts/data/receipt_store.dart'
    as _i88;
import 'package:grocery_accounting/features/receipts/data/supabase_receipt_store.dart'
    as _i125;
import 'package:grocery_accounting/features/reminders/data/local_run_out_notifier.dart'
    as _i360;
import 'package:grocery_accounting/features/reminders/data/run_out_notifier.dart'
    as _i582;
import 'package:grocery_accounting/features/shopping_list/data/firestore_shopping_list_repository.dart'
    as _i575;
import 'package:grocery_accounting/features/shopping_list/data/shopping_list_repository.dart'
    as _i285;
import 'package:http/http.dart' as _i519;
import 'package:image_picker/image_picker.dart' as _i183;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final firebaseModule = _$FirebaseModule();
    final receiptsModule = _$ReceiptsModule();
    final notificationsModule = _$NotificationsModule();
    gh.lazySingleton<_i59.FirebaseAuth>(() => firebaseModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(() => firebaseModule.firestore);
    gh.lazySingleton<_i183.ImagePicker>(() => receiptsModule.imagePicker);
    gh.lazySingleton<_i612.TextRecognizer>(() => receiptsModule.textRecognizer);
    gh.lazySingleton<_i519.Client>(() => receiptsModule.httpClient);
    gh.lazySingleton<_i163.FlutterLocalNotificationsPlugin>(
      () => notificationsModule.notifications,
    );
    gh.lazySingleton<_i691.ReceiptReader>(
      () => _i1045.MlKitReceiptReader(gh<_i612.TextRecognizer>()),
    );
    gh.lazySingleton<_i285.ShoppingListRepository>(
      () =>
          _i575.FirestoreShoppingListRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i582.RunOutNotifier>(
      () => _i360.LocalRunOutNotifier(
        gh<_i163.FlutterLocalNotificationsPlugin>(),
      ),
    );
    gh.lazySingleton<_i472.ReceiptPicker>(
      () => _i179.ImagePickerReceiptPicker(gh<_i183.ImagePicker>()),
    );
    gh.lazySingleton<_i384.PurchaseRepository>(
      () => _i716.FirestorePurchaseRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i1028.ItemRepository>(
      () => _i549.FirestoreItemRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i726.MemberRepository>(
      () => _i807.FirestoreMemberRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i88.ReceiptStore>(
      () => _i125.SupabaseReceiptStore(gh<_i519.Client>()),
    );
    gh.lazySingleton<_i123.AuthRepository>(
      () => _i883.FirebaseAuthRepository(gh<_i59.FirebaseAuth>()),
    );
    gh.factory<_i829.AuthCubit>(
      () => _i829.AuthCubit(gh<_i123.AuthRepository>()),
    );
    return this;
  }
}

class _$FirebaseModule extends _i368.FirebaseModule {}

class _$ReceiptsModule extends _i368.ReceiptsModule {}

class _$NotificationsModule extends _i368.NotificationsModule {}
