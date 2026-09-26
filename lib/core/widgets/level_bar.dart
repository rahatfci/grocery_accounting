import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// The Figma Stock bar: a level against a track. Also the spend bars.
class LevelBar extends StatelessWidget {
  const LevelBar({
    required this.value,
    required this.color,
    this.height = 6,
    this.trackColor = AppColors.dataTrack,
    super.key,
  });

  /// From 0 to 1. Anything outside is clamped; a non-number reads as empty.
  final double value;

  final Color color;
  final double height;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final level = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: trackColor),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: level,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
