import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/layout.dart';
import '../../auth/logic/app_user.dart';
import '../../home/presentation/home_tab.dart';
import '../../home/presentation/running_low_cubit.dart';
import '../../items/data/item_repository.dart';
import '../../items/presentation/items_cubit.dart';
import '../../items/presentation/pantry_tab.dart';
import '../../members/data/member_repository.dart';
import '../../members/presentation/household_cubit.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../receipts/data/receipt_store.dart';
import '../../receipts/presentation/receipt_uploads_cubit.dart';
import '../../reminders/data/run_out_notifier.dart';
import '../../reminders/presentation/run_out_reminders_cubit.dart';
import '../../reports/data/csv_sharer.dart';
import '../../reports/presentation/reports_cubit.dart';
import '../../reports/presentation/spending_tab.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/presentation/shopping_list_cubit.dart';
import '../../shopping_list/presentation/shopping_list_tab.dart';
import 'app_navigation_bar.dart';
import 'shell_cubit.dart';

/// Everything a signed-in member sees, owning the cubits that live for the
/// whole session.
///
/// Screens pushed from a tab go on this shell's own navigator, not the app's,
/// so they cover the navigation bar and can still read the session's cubits.
/// Signing out removes the shell, and every screen pushed inside it, at once.
class AppShell extends StatelessWidget {
  const AppShell({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ShellCubit()),
        BlocProvider(
          create: (context) => HouseholdCubit(
            context.read<MemberRepository>(),
            currentUser: user,
          ),
        ),
        BlocProvider(
          create: (context) => ItemsCubit(
            context.read<ItemRepository>(),
            context.read<PurchaseRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => RunningLowCubit(context.read<ItemRepository>()),
        ),
        BlocProvider(
          create: (context) => ShoppingListCubit(
            context.read<ShoppingListRepository>(),
            context.read<ItemRepository>(),
            currentUser: user,
          ),
        ),
        BlocProvider(
          // Spending's month. Created on the first visit to the tab, and
          // shared with the purchases list it opens.
          create: (context) => ReportsCubit(
            purchases: context.read<PurchaseRepository>(),
            items: context.read<ItemRepository>(),
            members: context.read<MemberRepository>(),
            sharer: context.read<CsvSharer>(),
          ),
        ),
        BlocProvider(
          // Nothing reads its state on Home, so without `lazy: false` it
          // would never be created and nothing would be scheduled.
          lazy: false,
          create: (context) => RunOutRemindersCubit(
            context.read<ItemRepository>(),
            context.read<RunOutNotifier>(),
          ),
        ),
        BlocProvider(
          // Created at once so photos queued offline start uploading as soon
          // as someone is signed in.
          lazy: false,
          create: (context) =>
              ReceiptUploadsCubit(context.read<ReceiptStore>()),
        ),
      ],
      child: _RefreshOnResume(child: _ShellNavigator(user: user)),
    );
  }
}

class _ShellNavigator extends StatefulWidget {
  const _ShellNavigator({required this.user});

  final AppUser user;

  @override
  State<_ShellNavigator> createState() => _ShellNavigatorState();
}

class _ShellNavigatorState extends State<_ShellNavigator> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // System back reaches the app's navigator first, which has nothing to
    // pop, so it is handed to this one while this one can handle it.
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
        onGenerateInitialRoutes: (_, _) => [
          MaterialPageRoute<void>(
            builder: (_) => ShellScaffold(user: widget.user),
          ),
        ],
      ),
    );
  }
}

/// The tabs, with the bottom navigation on a phone and a rail on a wide
/// window.
///
/// Each tab is built on its first visit and then kept, so switching back
/// keeps its scroll position and its month.
class ShellScaffold extends StatefulWidget {
  const ShellScaffold({required this.user, super.key});

  final AppUser user;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final _visited = <AppTab>{AppTab.home};

  Widget _tab(AppTab tab) {
    if (!_visited.contains(tab)) {
      return const SizedBox.shrink();
    }
    return switch (tab) {
      AppTab.home => HomeTab(user: widget.user),
      AppTab.pantry => PantryTab(user: widget.user),
      AppTab.list => ShoppingListTab(user: widget.user),
      AppTab.spending => const SpendingTab(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShellCubit, AppTab>(
      listener: (context, tab) => setState(() => _visited.add(tab)),
      builder: (context, selected) {
        final tabs = IndexedStack(
          index: selected.index,
          children: [for (final tab in AppTab.values) _tab(tab)],
        );
        final shell = context.read<ShellCubit>();

        // Back on any other tab goes Home first, rather than leaving the app.
        return PopScope(
          canPop: selected == AppTab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              shell.show(AppTab.home);
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= wideLayoutWidth
                ? _WideShell(
                    selected: selected,
                    onSelected: shell.show,
                    child: tabs,
                  )
                : Scaffold(
                    body: tabs,
                    bottomNavigationBar: AppNavigationBar(
                      selected: selected,
                      onSelected: shell.show,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// A tablet or web window: the same four destinations on a rail.
class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.selected,
    required this.onSelected,
    required this.child,
  });

  final AppTab selected;
  final ValueChanged<AppTab> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected.index,
            onDestinationSelected: (index) => onSelected(AppTab.values[index]),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1,
            destinations: [
              for (final tab in AppTab.values)
                NavigationRailDestination(
                  icon: Icon(tab.icon),
                  label: Text(tab.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Re-judges stock and the run-out reminders, and retries queued receipt
/// uploads, when the app comes back to the foreground.
///
/// Staples run down with no write to `items`, so without this a phone left
/// open overnight shows yesterday's numbers.
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
        context.read<ItemsCubit>().refresh();
        context.read<RunningLowCubit>().refresh();
        context.read<RunOutRemindersCubit>().refresh();
        context.read<ReceiptUploadsCubit>().flush();
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
