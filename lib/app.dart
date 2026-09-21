import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/auth/presentation/auth_gate.dart';

class GroceryAccountingApp extends StatelessWidget {
  const GroceryAccountingApp({required this.authCubit, super.key});

  /// Resolved in `main`, so no widget reaches into the service locator.
  final AuthCubit authCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => authCubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Grocery Accounting di Quattro Nero',
        color: Colors.white,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
