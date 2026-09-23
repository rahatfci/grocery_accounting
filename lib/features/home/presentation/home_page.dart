import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/logic/app_user.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../items/data/item_repository.dart';
import '../../items/presentation/item_list_page.dart';
import '../../purchases/presentation/record_purchase_page.dart';
import '../../reports/presentation/reports_page.dart';
import 'running_low_cubit.dart';
import 'running_low_section.dart';

/// Home, owning the running low cubit for as long as someone is signed in.
/// Receipt capture and the shopping list are added by their own features.
class HomePage extends StatelessWidget {
  const HomePage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RunningLowCubit(context.read<ItemRepository>()),
      child: HomeView(user: user),
    );
  }
}

/// Home without its cubit, so a test can supply one.
@visibleForTesting
class HomeView extends StatelessWidget {
  const HomeView({required this.user, super.key});

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
        child: _RefreshOnResume(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          user.email ?? 'Signed in',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // The one action Home is built around. Receipt capture
                        // joins it in feature 9, with the shopping list below
                        // running low.
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
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 24),
                    sliver: RunningLowSection(),
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

/// Re-judges running low when the app comes back to the foreground.
///
/// Home stays mounted all day, and staples run down with no write to `items`,
/// so without this a phone left on Home overnight shows yesterday's list.
class _RefreshOnResume extends StatefulWidget {
  const _RefreshOnResume({required this.child});

  final Widget child;

  @override
  State<_RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<_RefreshOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => context.read<RunningLowCubit>().refresh(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
