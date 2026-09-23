import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/logic/app_user.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../items/data/item_repository.dart';
import '../../items/presentation/item_list_page.dart';
import '../../purchases/presentation/record_purchase_page.dart';
import '../../reminders/data/run_out_notifier.dart';
import '../../reminders/presentation/run_out_reminders_cubit.dart';
import '../../reports/presentation/reports_page.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/presentation/shopping_list_cubit.dart';
import '../../shopping_list/presentation/shopping_list_section.dart';
import 'running_low_cubit.dart';
import 'running_low_section.dart';

/// Home, owning the running low, run-out reminder and shopping list cubits for
/// as long as someone is signed in.
/// Receipt capture is added by its own feature.
class HomePage extends StatelessWidget {
  const HomePage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => RunningLowCubit(context.read<ItemRepository>()),
        ),
        BlocProvider(
          // Nothing reads its state, so without `lazy: false` it would never
          // be created and nothing would be scheduled.
          lazy: false,
          create: (context) => RunOutRemindersCubit(
            context.read<ItemRepository>(),
            context.read<RunOutNotifier>(),
          ),
        ),
        BlocProvider(
          create: (context) => ShoppingListCubit(
            context.read<ShoppingListRepository>(),
            context.read<ItemRepository>(),
            currentUser: user,
          ),
        ),
      ],
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
                        // joins it in feature 9.
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
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 24),
                    sliver: ShoppingListSection(),
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

/// Re-judges running low and the run-out reminders when the app comes back to
/// the foreground.
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
      onResume: () {
        context.read<RunningLowCubit>().refresh();
        context.read<RunOutRemindersCubit>().refresh();
      },
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
