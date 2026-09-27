import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';

/// The app icon tile: a basket on the seed green.
class AppMark extends StatelessWidget {
  const AppMark({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand,
          // 16 px on the 56 px tile.
          borderRadius: BorderRadius.circular(size * 0.29),
        ),
        child: Icon(
          Symbols.shopping_basket_rounded,
          size: size * 0.56,
          color: AppColors.onBrand,
        ),
      ),
    );
  }
}
