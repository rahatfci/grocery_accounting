import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../account/presentation/account_page.dart';
import '../../auth/logic/app_user.dart';
import '../../items/data/item_repository.dart';
import '../../items/presentation/item_form_page.dart';
import '../../items/presentation/items_cubit.dart';
import '../../items/presentation/items_state.dart';
import '../../members/data/member_repository.dart';
import '../../members/presentation/household_cubit.dart';
import '../../members/presentation/household_state.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';
import '../../purchases/presentation/record_purchase_page.dart';
import '../../receipts/data/receipt_picker.dart';
import '../../reports/data/csv_sharer.dart';
import '../../reports/logic/spend_glance.dart';
import '../../reports/presentation/reports_cubit.dart';
import '../../reports/presentation/reports_state.dart';
import '../logic/greeting.dart';
import 'list_preview.dart';
import 'month_glance_card.dart';
import 'running_low_panel.dart';
import 'scan_hero.dart';

/// Home, built around one action: photograph the receipt.
///
/// Owns its own [ReportsCubit], always on the current month, for the glance.
/// Spending has another, which can move to other months.
class HomeTab extends StatelessWidget {
  const HomeTab({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportsCubit(
        purchases: context.read<PurchaseRepository>(),
        items: context.read<ItemRepository>(),
        members: context.read<MemberRepository>(),
        sharer: context.read<CsvSharer>(),
      ),
      child: HomeView(user: user),
    );
  }
}

/// Home without its glance cubit, so a test can supply one.
@visibleForTesting
class HomeView extends StatefulWidget {
  const HomeView({required this.user, super.key});

  final AppUser user;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    // Home stays mounted all day, so across midnight at the end of a month
    // the glance has to move on by itself.
    _listener = AppLifecycleListener(
      onResume: () => context.read<ReportsCubit>().showCurrentMonth(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  void _start(PurchaseStart start) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordPurchasePage(
          user: widget.user,
          startWith: switch (start) {
            PurchaseStart.camera => ReceiptSource.camera,
            PurchaseStart.gallery => ReceiptSource.gallery,
            PurchaseStart.manual => null,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstRun = context.select(
      (ItemsCubit cubit) => cubit.state is ItemsEmpty,
    );

    // Decided here rather than inside the card, so a household with nothing
    // spent does not leave an empty slot and its gap above the scan hero.
    final showGlance = context.select(
      (ReportsCubit cubit) => switch (cubit.state) {
        ReportsLoaded(:final report) => spendGlanceFor(
          report,
          user.uid,
        ).hasSpending,
        _ => true,
      },
    );

    final lead = [
      if (showGlance) MonthGlanceCard(memberId: user.uid),
      ScanHero(onStart: _start),
      if (firstRun) const _GettingStarted(),
    ];
    final follow = [RunningLowPanel(user: user), const ListPreview()];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Header(user: user),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= wideLayoutWidth
                  ? _WideHome(lead: lead, follow: follow)
                  : _Sections(children: [...lead, ...follow]),
            ),
          ),
        ],
      ),
    );
  }
}

/// A phone: one thumb-reachable column, the action near the top.
class _Sections extends StatelessWidget {
  const _Sections({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s8,
        AppSpace.page,
        AppSpace.s32,
      ),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s24),
      itemBuilder: (_, index) => children[index],
    );
  }
}

/// A tablet or web window: the money and the scan hero beside what is
/// running low and the list, so both read without scrolling one past the
/// other.
class _WideHome extends StatelessWidget {
  const _WideHome({required this.lead, required this.follow});

  final List<Widget> lead;
  final List<Widget> follow;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Sections(children: lead)),
            Expanded(child: _Sections(children: follow)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<HouseholdCubit, HouseholdState>(
      builder: (context, state) {
        final household = state.household;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s8,
            AppSpace.page,
            AppSpace.s8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greetingFor(DateTime.now()),
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      household.nameOf(user.uid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Account',
                child: Semantics(
                  button: true,
                  label: 'Account',
                  child: InkResponse(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountPage(user: user),
                      ),
                    ),
                    radius: 24,
                    child: MemberAvatar(
                      initials: household.initialsOf(user.uid),
                      tone: household.toneOf(user.uid),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The first-run card: the catalogue is empty, and it fills itself as
/// receipts are reviewed, so only the staples need adding by hand.
class _GettingStarted extends StatelessWidget {
  const _GettingStarted();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(
            icon: Symbols.inventory_2_rounded,
            size: 48,
            iconSize: 26,
            radius: AppRadius.lg,
            background: AppColors.brandSubtle,
            color: AppColors.brand,
          ),
          const SizedBox(height: AppSpace.s12),
          Text('Your pantry fills itself', style: text.titleMedium),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Every receipt you review adds its items. Start with the few '
            'staples that matter when they run out, like rice, milk and '
            'coffee.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: 'Add a staple',
            icon: Symbols.add_rounded,
            variant: AppButtonVariant.tonal,
            size: AppButtonSize.medium,
            onPressed: () => openItemForm(context),
          ),
        ],
      ),
    );
  }
}
