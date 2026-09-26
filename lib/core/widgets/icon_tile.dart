import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// An icon on a rounded square, leading a row or a card.
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    this.size = 40,
    this.iconSize = 22,
    this.radius = AppRadius.md,
    this.background = AppColors.subtle,
    this.color = AppColors.iconPrimary,
    this.circle = false,
    super.key,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double radius;
  final Color background;
  final Color color;

  /// A circle rather than a rounded square.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
