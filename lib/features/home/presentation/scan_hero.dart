import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';

/// The one action Home is built around, and its largest element: photograph
/// the scontrino. The gallery and manual entry sit under it.
class ScanHero extends StatelessWidget {
  const ScanHero({required this.onStart, super.key});

  final ValueChanged<PurchaseStart> onStart;

  Future<void> _choose(BuildContext context) async {
    final start = await showAddPurchaseSheet(context);
    if (start != null) {
      onStart(start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: 'Scan a receipt, all the ways to add a purchase',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _choose(context),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.document_scanner_rounded,
                        size: 28,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan a receipt',
                            style: text.titleLarge?.copyWith(
                              color: AppColors.onBrand,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s4),
                          Text(
                            'Records the spend, restocks the pantry and ticks '
                            'off the list.',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.onBrand.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            AppButton(
              label: 'Take photo',
              icon: Symbols.photo_camera_rounded,
              variant: AppButtonVariant.tonal,
              expand: true,
              onPressed: () => onStart(PurchaseStart.camera),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpace.s8,
              children: [
                _HeroLink(
                  icon: Symbols.photo_library_rounded,
                  label: 'Choose from gallery',
                  onTap: () => onStart(PurchaseStart.gallery),
                ),
                _HeroLink(
                  icon: Symbols.edit_rounded,
                  label: 'Enter manually',
                  onTap: () => onStart(PurchaseStart.manual),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroLink extends StatelessWidget {
  const _HeroLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.onBrand),
            const SizedBox(width: AppSpace.s6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMediumStrong.copyWith(color: AppColors.onBrand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
