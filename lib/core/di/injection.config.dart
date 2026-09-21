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
import 'package:get_it/get_it.dart' as _i174;
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
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final firebaseModule = _$FirebaseModule();
    gh.lazySingleton<_i59.FirebaseAuth>(() => firebaseModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(() => firebaseModule.firestore);
    gh.lazySingleton<_i1028.ItemRepository>(
      () => _i549.FirestoreItemRepository(gh<_i974.FirebaseFirestore>()),
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
