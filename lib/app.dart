import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/items/data/item_repository.dart';

class GroceryAccountingApp extends StatelessWidget {
  const GroceryAccountingApp({
    required this.authCubit,
    required this.itemRepository,
    super.key,
  });

  /// Resolved in `main`, so no widget reaches into the service locator.
  final AuthCubit authCubit;

  /// Also resolved in `main`. The catalogue builds its own cubit from this
  /// when it opens, rather than holding a Firestore subscription open from
  /// launch, before anyone has signed in.
  final ItemRepository itemRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: itemRepository,
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
