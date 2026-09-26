import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AvatarSize {
  small(24),
  medium(32),
  large(40),
  xLarge(56);

  const AvatarSize(this.dimension);

  final double dimension;
}

/// A member's initials on their colour pair.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    required this.initials,
    required this.tone,
    this.size = AvatarSize.large,
    this.outlined = false,
    super.key,
  });

  final String initials;

  /// Which of the five colour pairs, wrapped if out of range.
  final int tone;

  final AvatarSize size;

  /// A white ring, for avatars stacked over one another.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pair = AppColors.avatars[tone % AppColors.avatars.length];
    final style = switch (size) {
      AvatarSize.small || AvatarSize.medium => text.labelMedium,
      AvatarSize.large => text.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      AvatarSize.xLarge => text.titleLarge,
    };

    return ExcludeSemantics(
      child: Container(
        width: size.dimension,
        height: size.dimension,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pair.background,
          shape: BoxShape.circle,
          border: outlined
              ? Border.all(color: AppColors.surface, width: 2)
              : null,
        ),
        child: Text(
          initials,
          maxLines: 1,
          style: style?.copyWith(color: pair.foreground),
        ),
      ),
    );
  }
}
