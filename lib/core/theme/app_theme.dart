import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// The light theme, built from the Figma tokens. The design is light only.
abstract final class AppTheme {
  static const String fontFamily = 'CenturyGothic';

  static ThemeData get light {
    const colors = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      primaryContainer: AppColors.brandSubtle,
      onPrimaryContainer: AppColors.brand,
      secondary: AppColors.inverseSecondary,
      onSecondary: AppColors.onBrand,
      secondaryContainer: AppColors.subtle,
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: AppColors.warning,
      onTertiary: AppColors.onBrand,
      tertiaryContainer: AppColors.warningSubtle,
      onTertiaryContainer: AppColors.warning,
      error: AppColors.negative,
      onError: AppColors.onBrand,
      errorContainer: AppColors.negativeSubtle,
      onErrorContainer: AppColors.negativeStrong,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.subtle,
      outline: AppColors.borderInput,
      outlineVariant: AppColors.borderSubtle,
      shadow: AppColors.shadow,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.inverse,
      onInverseSurface: AppColors.onBrand,
      inversePrimary: AppColors.brandMuted,
      surfaceTint: Colors.transparent,
    );
    final text = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      splashFactory: InkRipple.splashFactory,
      // Material Symbols are drawn at the 24 px optical size the Figma icons
      // come from, rather than the variable font's 48.
      iconTheme: const IconThemeData(
        color: AppColors.iconPrimary,
        size: 24,
        opticalSize: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.muted,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.onBrand.withValues(alpha: 0.9),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
          textStyle: text.labelLarge,
          iconSize: 20,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
          textStyle: text.labelLarge,
          iconSize: 20,
          side: const BorderSide(color: AppColors.borderDefault),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          iconSize: 18,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.iconPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 6,
        highlightElevation: 8,
        iconSize: 20,
        extendedTextStyle: text.labelLarge,
        extendedIconLabelSpacing: AppSpace.s8,
        extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 52),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      inputDecorationTheme: _inputTheme(text),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brand,
        selectionColor: AppColors.brand.withValues(alpha: 0.24),
        selectionHandleColor: AppColors.brand,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: AppColors.dataTrack,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: AppColors.scrim,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inverse,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.onBrand),
        actionTextColor: AppColors.brandMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandSubtle,
        selectedIconTheme: const IconThemeData(color: AppColors.brand),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.iconSecondary,
        ),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: AppColors.brand,
        ),
        unselectedLabelTextStyle: text.bodySmall?.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.brand,
        headerForegroundColor: AppColors.onBrand,
      ),
    );
  }

  static InputDecorationTheme _inputTheme(TextTheme text) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: 14,
      ),
      hintStyle: text.bodyLarge?.copyWith(color: AppColors.textPlaceholder),
      prefixStyle: text.bodyLarge?.copyWith(color: AppColors.textTertiary),
      helperStyle: text.bodySmall?.copyWith(color: AppColors.textTertiary),
      errorStyle: text.bodySmall?.copyWith(color: AppColors.negative),
      prefixIconColor: AppColors.iconSecondary,
      suffixIconColor: AppColors.iconSecondary,
      border: border(AppColors.borderInput),
      enabledBorder: border(AppColors.borderInput),
      disabledBorder: border(AppColors.borderSubtle),
      focusedBorder: border(AppColors.borderFocus, 2),
      errorBorder: border(AppColors.borderNegative),
      focusedErrorBorder: border(AppColors.borderNegative, 2),
    );
  }

  /// The 13 Figma text styles on the Material 3 roles each one names. Line
  /// heights are the design's, as a multiple of the size.
  static TextTheme _textTheme() {
    TextStyle style(
      double size,
      double lineHeight, {
      FontWeight weight = FontWeight.w700,
      double spacing = 0,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: AppColors.textPrimary,
      leadingDistribution: TextLeadingDistribution.even,
    );

    return TextTheme(
      displayLarge: style(48, 56, spacing: -1),
      displayMedium: style(44, 52, spacing: -1),
      displaySmall: style(40, 48, spacing: -0.8),
      headlineLarge: style(32, 40, spacing: -0.6),
      headlineMedium: style(28, 36, spacing: -0.4),
      headlineSmall: style(24, 32, spacing: -0.3),
      titleLarge: style(22, 28, spacing: -0.2),
      titleMedium: style(18, 24),
      titleSmall: style(14, 20),
      bodyLarge: style(16, 24, weight: FontWeight.w400),
      bodyMedium: style(14, 20, weight: FontWeight.w400),
      bodySmall: style(12, 16, weight: FontWeight.w400),
      labelLarge: style(16, 20, spacing: 0.1),
      labelMedium: style(12, 16, spacing: 0.1),
      labelSmall: style(11, 14, spacing: 0.8),
    );
  }
}

/// The design's "Strong" body styles, which Material 3 has no role for.
extension StrongText on TextTheme {
  TextStyle get bodyLargeStrong =>
      (bodyLarge ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);

  TextStyle get bodyMediumStrong =>
      (bodyMedium ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);
}
