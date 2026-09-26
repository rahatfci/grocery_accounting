import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../receipts/logic/receipt.dart';
import '../../receipts/logic/receipt_reading.dart';
import '../logic/receipt_found.dart';

/// The receipt photo made small, or a stand-in where there is none yet.
class ReceiptThumbnail extends StatelessWidget {
  const ReceiptThumbnail({
    required this.photo,
    this.width = 44,
    this.height = 58,
    this.radius = AppRadius.sm,
    super.key,
  });

  final ReceiptPhoto? photo;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      photo == null
          ? Symbols.add_a_photo_rounded
          : Symbols.receipt_long_rounded,
      size: 22,
      color: AppColors.iconSecondary,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: AppColors.muted,
        alignment: Alignment.center,
        child: switch (photo) {
          final photo? => Image.memory(
            photo.bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            // Decoded at thumbnail size, not the full 2000 px photo.
            cacheHeight: (height * 3).round(),
            gaplessPlayback: true,
            excludeFromSemantics: true,
            // A photo that will not decode still shows that one is attached.
            errorBuilder: (_, _, _) => placeholder,
          ),
          null => placeholder,
        },
      ),
    );
  }
}

/// The top of the purchase details: what the photo is and what reading it
/// found, with the way to add or replace it.
class ReceiptStrip extends StatelessWidget {
  const ReceiptStrip({
    required this.photo,
    required this.readResult,
    required this.readFailed,
    required this.onPick,
    super.key,
  });

  final ReceiptPhoto? photo;
  final ReceiptReading? readResult;
  final bool readFailed;

  /// Adds or replaces the photo. Null while the purchase is being saved.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (title, detail) = switch ((photo, readResult)) {
      (null, _) => ('No receipt photo', 'Add one to keep it with the purchase'),
      // The web has nothing to read with, so an empty reading there says
      // nothing about the photo.
      (_, final reading?) when !kIsWeb => (
        'Receipt read',
        receiptFoundLabel(reading),
      ),
      _ when readFailed => (
        'Receipt attached',
        'Could not be read. Fill it in by hand',
      ),
      _ => ('Receipt attached', 'Kept with the purchase once it is saved'),
    };

    return Row(
      children: [
        ReceiptThumbnail(photo: photo),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMediumStrong,
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        AppButton(
          label: photo == null ? 'Add photo' : 'Replace',
          icon: photo == null
              ? Symbols.add_a_photo_rounded
              : Symbols.refresh_rounded,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onPick,
        ),
      ],
    );
  }
}

/// Shown while the photo is being read: the photo, what is happening and
/// that it happens on the phone.
class ReadingCard extends StatelessWidget {
  const ReadingCard({required this.photo, super.key});

  final ReceiptPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          ReceiptThumbnail(
            photo: photo,
            width: 72,
            height: 96,
            radius: AppRadius.md,
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Reading receipt...', style: text.titleMedium),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Finding the total, the date and each line. This happens '
                    'on your phone.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.full),
                    ),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: AppColors.brand,
                      backgroundColor: AppColors.dataTrack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
