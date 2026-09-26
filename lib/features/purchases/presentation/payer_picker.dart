import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../members/logic/household.dart';

/// Who paid: one chip per member, scrolling sideways when they do not fit.
class PayerPicker extends StatelessWidget {
  const PayerPicker({
    required this.household,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Household household;
  final String selected;

  /// Null disables the chips, while the purchase is being saved.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final members = household.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Paid by',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.s8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
            itemBuilder: (context, index) {
              final member = members[index];
              return _PayerChip(
                name: member.displayName,
                initials: household.initialsOf(member.id),
                tone: household.toneOf(member.id),
                selected: member.id == selected,
                onTap: onChanged == null ? null : () => onChanged(member.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PayerChip extends StatelessWidget {
  const _PayerChip({
    required this.name,
    required this.initials,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String initials;
  final int tone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: selected
          ? const BorderSide(color: AppColors.brand, width: 2)
          : const BorderSide(color: AppColors.borderDefault),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.brandSubtle : AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s6, 0, AppSpace.s16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberAvatar(
                  initials: initials,
                  tone: tone,
                  size: AvatarSize.medium,
                ),
                const SizedBox(width: AppSpace.s8),
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMediumStrong.copyWith(
                    color: selected ? AppColors.brand : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
