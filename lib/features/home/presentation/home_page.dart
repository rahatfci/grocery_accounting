import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/layout.dart';

import '../../auth/logic/app_user.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../items/data/item_repository.dart';
import '../../items/presentation/item_list_page.dart';
import '../../purchases/presentation/record_purchase_page.dart';
import '../../receipts/data/receipt_store.dart';
import '../../receipts/presentation/receipt_source_sheet.dart';
import '../../receipts/presentation/receipt_uploads_cubit.dart';
import '../../reminders/data/run_out_notifier.dart';
import '../../reminders/presentation/run_out_reminders_cubit.dart';
import '../../reports/presentation/reports_page.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/presentation/shopping_list_cubit.dart';
import '../../shopping_list/presentation/shopping_list_section.dart';
import 'running_low_cubit.dart';
import 'running_low_section.dart';

/// Home, owning the running low, run-out reminder, shopping list and receipt
/// upload cubits for as long as someone is signed in.
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
          // Nothing reads its state either. Created at once so photos queued
          // offline start uploading as soon as someone is signed in.
          lazy: false,
          create: (context) =>
              ReceiptUploadsCubit(context.read<ReceiptStore>()),
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
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= wideLayoutWidth
                ? _WideHome(user: user)
                : _NarrowHome(user: user),
          ),
        ),
      ),
    );
  }
}

/// A phone: one thumb-reachable column, the action first.
class _NarrowHome extends StatelessWidget {
  const _NarrowHome({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CustomScrollView(
          slivers: [
            _HomeActions(user: user),
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
    );
  }
}

/// A tablet or web window: the shopping list beside what is running low, so
/// both can be read without scrolling one past the other.
class _WideHome extends StatelessWidget {
  const _WideHome({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  _HomeActions(user: user),
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 24),
                    sliver: RunningLowSection(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            const Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(8, 24, 8, 24),
                    sliver: ShoppingListSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who is signed in, and the two ways to record a purchase.
class _HomeActions extends StatelessWidget {
  const _HomeActions({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      sliver: SliverList.list(
        children: [
          Text(
            user.email ?? 'Signed in',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // The one action Home is built around.
          _CaptureButton(user: user),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecordPurchasePage(user: user),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Record a purchase'),
          ),
        ],
      ),
    );
  }
}

/// Photograph or pick the scontrino, then review it as a purchase.
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.user});

  final AppUser user;

  Future<void> _capture(BuildContext context) async {
    final navigator = Navigator.of(context);
    final source = await showReceiptSourceSheet(context);
    if (source == null) {
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RecordPurchasePage(user: user, startWith: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _capture(context),
      icon: const Icon(Icons.photo_camera_outlined, size: 28),
      label: const Text('Capture receipt'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// Re-judges running low and the run-out reminders, and retries queued
/// receipt uploads, when the app comes back to the foreground.
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
