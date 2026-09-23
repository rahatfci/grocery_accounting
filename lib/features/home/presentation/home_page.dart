import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/logic/app_user.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../items/presentation/item_list_page.dart';
import '../../purchases/presentation/record_purchase_page.dart';
import '../../reports/presentation/reports_page.dart';

/// The shell Home. Receipt capture, running low and the shopping list are
/// added by their own features.
class HomePage extends StatelessWidget {
  const HomePage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery Accounting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Catalogue',
            // Three screens do not justify a router package.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ItemListPage(user: user)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Spending',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.email ?? 'Signed in',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // The one action Home is built around. Receipt capture
                  // joins it in feature 9, with running low and the shopping
                  // list below.
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecordPurchasePage(user: user),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Record a purchase'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
