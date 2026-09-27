import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_tag.dart';
import '../../items/presentation/items_cubit.dart';
import '../../items/presentation/items_state.dart';
import '../../members/logic/household.dart';
import '../../members/presentation/household_cubit.dart';
import '../../receipts/data/receipt_store.dart';
import '../../receipts/presentation/receipt_photo_page.dart';
import '../data/purchase_repository.dart';
import '../logic/money.dart';
import '../logic/purchase.dart';
import '../logic/purchase_labels.dart';
import '../logic/purchase_source.dart';
import 'purchase_detail_cubit.dart';
import 'purchase_detail_state.dart';

/// One saved purchase, read only: where, when, how much, who paid, the
/// receipt photo and every line.
class PurchaseDetailPage extends StatelessWidget {
  const PurchaseDetailPage({required this.purchaseId, super.key});

  final String purchaseId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PurchaseDetailCubit(
        purchases: context.read<PurchaseRepository>(),
        receipts: context.read<ReceiptStore>(),
        purchaseId: purchaseId,
      ),
      child: const PurchaseDetailView(),
    );
  }
}

/// The screen without its cubit, so a test can supply one.
@visibleForTesting
class PurchaseDetailView extends StatelessWidget {
  const PurchaseDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Purchase'),
      body: SafeArea(
        child: BlocBuilder<PurchaseDetailCubit, PurchaseDetailState>(
          builder: (context, state) => switch (state) {
            PurchaseDetailLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            PurchaseDetailFailure(:final failure) => LoadFailure(
              message: failure.message,
              onRetry: context.read<PurchaseDetailCubit>().retry,
            ),
            PurchaseDetailMissing() => const Padding(
              padding: EdgeInsets.all(AppSpace.page),
              child: Align(
                alignment: Alignment.topCenter,
                child: RowGroup(
                  children: [
                    NoteRow(
                      icon: Symbols.receipt_long_rounded,
                      text: 'This purchase is no longer recorded.',
                    ),
                  ],
                ),
              ),
            ),
            PurchaseDetailLoaded(:final purchase, :final photo) => _Details(
              purchase: purchase,
              photo: photo,
            ),
          },
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.purchase, required this.photo});

  final Purchase purchase;
  final PurchasePhoto photo;

  @override
  Widget build(BuildContext context) {
    final household = context.select(
      (HouseholdCubit cubit) => cubit.state.household,
    );
    // Null until the pantry has reported, when a line can only be shown as
    // it was saved.
    final names = context.select(
      (ItemsCubit cubit) => switch (cubit.state) {
        ItemsLoaded(:final items) => {
          for (final item in items) item.id: item.name,
        },
        ItemsEmpty() => const <String, String>{},
        ItemsLoading() || ItemsFailure() => null,
      },
    );
    final lines = linesSpendOnlyFirst(purchase.lines);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s8,
            AppSpace.page,
            AppSpace.s24,
          ),
          children: [
            _Header(purchase: purchase, household: household),
            if (photo is! NoPurchasePhoto) ...[
              const SizedBox(height: AppSpace.s16),
              _PhotoBlock(photo: photo),
            ],
            const SizedBox(height: AppSpace.s16),
            SectionHeader(
              title: 'Lines',
              count: lines.isEmpty ? null : lines.length,
            ),
            const SizedBox(height: AppSpace.s12),
            RowGroup(
              children: [
                if (lines.isEmpty)
                  const NoteRow(
                    icon: Symbols.receipt_long_rounded,
                    text: 'Only the spend was recorded.',
                  ),
                for (final line in lines)
                  _SavedLineRow(
                    line: line,
                    // Before the pantry reports, a matched line keeps the
                    // wording it was saved with.
                    itemName: switch (names) {
                      null => line.itemId == null ? null : line.rawText,
                      final names => names[line.itemId],
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.purchase, required this.household});

  final Purchase purchase;
  final Household household;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final payer = purchase.paidByUserId;
    final scanned = purchase.source == PurchaseSource.scanned;
    final shop = purchase.shopName.trim();

    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Symbols.storefront_rounded,
                size: 44,
                iconSize: 24,
                color: AppColors.iconSecondary,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.isEmpty ? 'Unknown shop' : shop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      purchaseDay(purchase.date),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              StatusTag(
                label: scanned ? 'Scanned' : 'Manual',
                tone: scanned ? Tone.brand : Tone.neutral,
                icon: scanned
                    ? Symbols.receipt_long_rounded
                    : Symbols.edit_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(formatEuro(purchase.total), style: text.headlineLarge),
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              MemberAvatar(
                initials: household.initialsOf(payer),
                tone: household.toneOf(payer),
                size: AvatarSize.small,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'Paid by ${household.nameOf(payer)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({required this.photo});

  final PurchasePhoto photo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Widget frame = switch (photo) {
      PurchasePhotoLoaded(:final bytes) => Semantics(
        button: true,
        label: 'Receipt photo',
        hint: 'Opens it full size',
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReceiptPhotoPage(bytes: bytes),
            ),
          ),
          child: Image.memory(
            bytes,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const _PhotoNote(
              icon: Symbols.broken_image_rounded,
              text: 'This photo cannot be shown.',
            ),
          ),
        ),
      ),
      PurchasePhotoFailed(:final message) => _PhotoNote(
        icon: Symbols.cloud_off_rounded,
        text: message,
        onRetry: context.read<PurchaseDetailCubit>().retryPhoto,
      ),
      PurchasePhotoLoading() ||
      NoPurchasePhoto() => const Center(child: CircularProgressIndicator()),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            height: 200,
            color: AppColors.muted,
            alignment: Alignment.center,
            child: frame,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Text(
            'Tap the photo to zoom. Kept in the household receipt bucket.',
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _PhotoNote extends StatelessWidget {
  const _PhotoNote({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppColors.iconSecondary),
          const SizedBox(height: AppSpace.s8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// A line as it was saved. Spend-only lines keep the review screen's red
/// edge, since they restocked nothing.
class _SavedLineRow extends StatelessWidget {
  const _SavedLineRow({required this.line, required this.itemName});

  final PurchaseLine line;
  final String? itemName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = savedLineTitle(line, itemName: itemName);
    final detail = savedLineDetail(line, itemName: itemName);
    final amount = Text(
      formatEuro(line.lineTotal),
      style: text.bodyLargeStrong,
    );

    if (line.itemId == null) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.negativeSubtle,
          border: Border(left: BorderSide(color: AppColors.negative, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s12,
          AppSpace.s16,
          AppSpace.s12,
        ),
        child: Row(
          children: [
            const Icon(
              Symbols.link_off_rounded,
              size: 22,
              color: AppColors.negative,
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLargeStrong,
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.negative,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            amount,
          ],
        ),
      );
    }

    return AppRow(
      leading: const Icon(
        Symbols.check_circle_rounded,
        size: 22,
        color: AppColors.positive,
      ),
      body: RowText(title: title, subtitle: detail),
      trailing: amount,
    );
  }
}
