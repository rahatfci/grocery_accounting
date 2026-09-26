import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/notes.dart';

/// How a purchase starts: from a photo, or typed in.
enum PurchaseStart { camera, gallery, manual }

/// Asks how to start a purchase. With [photoOnly], only the two photo
/// sources are offered, for adding or replacing the receipt of a purchase
/// already being reviewed. Null when dismissed.
Future<PurchaseStart?> showAddPurchaseSheet(
  BuildContext context, {
  bool photoOnly = false,
}) => showAppSheet<PurchaseStart>(
  context,
  builder: (_) => AddPurchaseSheet(photoOnly: photoOnly),
);

class AddPurchaseSheet extends StatelessWidget {
  const AddPurchaseSheet({this.photoOnly = false, super.key});

  final bool photoOnly;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      children: [
        SheetTitle(
          title: photoOnly ? 'Receipt photo' : 'Add a purchase',
          subtitle: Text(
            photoOnly
                ? 'Kept with the purchase once it is saved.'
                : 'Everything is reviewed before it touches the pantry.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Option(
              start: PurchaseStart.camera,
              icon: Symbols.photo_camera_rounded,
              title: 'Take a photo',
              subtitle: 'Best for a fresh receipt',
              highlighted: true,
            ),
            const SizedBox(height: AppSpace.s12),
            const _Option(
              start: PurchaseStart.gallery,
              icon: Symbols.photo_library_rounded,
              title: 'Choose from gallery',
              subtitle: 'A photo you already took',
            ),
            if (!photoOnly) ...[
              const SizedBox(height: AppSpace.s12),
              const _Option(
                start: PurchaseStart.manual,
                icon: Symbols.edit_rounded,
                title: 'Enter manually',
                subtitle: 'No receipt, or a handwritten one',
              ),
            ],
          ],
        ),
        InfoNote(
          text: kIsWeb
              ? 'On the web the photo is kept with the purchase, and the lines '
                    'are filled in by hand.'
              : 'Flatten the receipt and fill the frame. The text is read on '
                    'this phone, even with no signal.',
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.start,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
  });

  final PurchaseStart start;
  final IconData icon;
  final String title;
  final String subtitle;

  /// The way most receipts are added, so it is drawn as the default.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: highlighted ? AppColors.brandSubtle : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: highlighted
            ? const BorderSide(color: AppColors.borderFocus, width: 2)
            : const BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(start),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Row(
            children: [
              IconTile(
                icon: icon,
                size: 44,
                iconSize: 24,
                background: highlighted ? AppColors.brand : AppColors.subtle,
                color: highlighted ? AppColors.onBrand : AppColors.iconPrimary,
              ),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: RowText(
                  title: title,
                  subtitle: subtitle,
                  titleStyle: text.bodyLargeStrong,
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: AppColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
