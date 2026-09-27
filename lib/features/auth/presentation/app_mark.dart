import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';

/// The app icon tile: a basket on the seed green, or reversed on the splash.
class AppMark extends StatelessWidget {
  const AppMark({this.size = 56, this.reversed = false, super.key});

  final double size;

  /// White tile with a green basket, for the green splash.
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: reversed ? AppColors.surface : AppColors.brand,
          // 16 px on the 56 px tile, 26 px on the 88 px splash tile.
          borderRadius: BorderRadius.circular(size * 0.29),
        ),
        child: Icon(
          Symbols.shopping_basket_rounded,
          size: size * 0.56,
          color: reversed ? AppColors.brand : AppColors.onBrand,
        ),
      ),
    );
  }
}
