import 'package:flutter/material.dart';

/// Visual tokens for the app.
abstract final class AppTheme {
  static const Color seed = Color(0xFF244F3D);
  static const String fontFamily = 'CenturyGothic';

  static ThemeData get light => ThemeData(
    fontFamily: fontFamily,
    colorSchemeSeed: seed,
    appBarTheme: const AppBarTheme(
      backgroundColor: seed,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
    ),
  );
}
