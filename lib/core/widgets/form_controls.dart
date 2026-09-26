import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A field with its label above it, as every form in the design lays out.
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.child,
    this.helper,
    super.key,
  });

  final String label;
  final Widget child;

  /// A caption under the field, such as the unit a number is in.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final helper = this.helper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.s6),
        child,
        if (helper != null) ...[
          const SizedBox(height: AppSpace.s6),
          Text(
            helper,
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// One option of a [SegmentedPicker].
final class Segment<T> {
  const Segment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// The Figma Segmented control: a tinted track holding two to four options,
/// the selected one lifted onto white.
class SegmentedPicker<T> extends StatelessWidget {
  const SegmentedPicker({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<Segment<T>> segments;

  /// Null when nothing is chosen yet.
  final T? selected;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onChanged = this.onChanged;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final (index, segment) in segments.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpace.s4),
            Expanded(
              child: _SegmentButton(
                segment: segment,
                selected: segment.value == selected,
                style: text,
                onTap: onChanged == null
                    ? null
                    : () => onChanged(segment.value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final Segment<T> segment;
  final bool selected;
  final TextTheme style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = segment.icon;
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: selected ? AppShadows.segment : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpace.s6),
              ],
              Flexible(
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (selected ? style.bodyMediumStrong : style.bodyMedium)
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Figma Chip: a pill that is either chosen (dark) or not (outlined).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = true,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Whether a chosen pill carries a check, as the category pickers do.
  final bool showCheck;

  /// Shown before the label when not chosen, such as the add icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final icon = selected && showCheck ? Symbols.check_rounded : this.icon;
    final foreground = selected ? AppColors.onBrand : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.inverse : AppColors.surface,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : const BorderSide(color: AppColors.borderDefault),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: AppSpace.s6),
                ],
                Text(
                  label,
                  style: (selected ? text.bodyMediumStrong : text.bodyMedium)
                      ?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Figma Checkbox: 24 px, 7 px corners, filled with the brand when ticked.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.checked,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Semantics(
      container: true,
      checked: checked,
      label: semanticLabel,
      enabled: onChanged != null,
      child: InkResponse(
        onTap: onChanged == null ? null : () => onChanged(!checked),
        radius: 24,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.circular(7),
                border: checked
                    ? null
                    : Border.all(color: AppColors.borderInput, width: 2),
              ),
              child: checked
                  ? const Icon(
                      Symbols.check_rounded,
                      size: 18,
                      color: AppColors.onBrand,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
