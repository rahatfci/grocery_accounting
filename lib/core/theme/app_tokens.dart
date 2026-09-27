import 'package:flutter/painting.dart';

/// The Figma `Spacing` variables.
abstract final class AppSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// The side margin of every phone screen.
  static const double page = s20;
}

/// The Figma `Radius` variables.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;
}

/// The Figma effect styles.
abstract final class AppShadows {
  /// Resting cards.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0F1D33), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0D0F1D33), offset: Offset(0, 4), blurRadius: 16),
  ];

  /// The chosen option of a segmented control.
  static const List<BoxShadow> segment = [
    BoxShadow(color: Color(0x0D0F1D33), offset: Offset(0, 4), blurRadius: 8),
    BoxShadow(color: Color(0x0A0F1D33), offset: Offset(0, 1), blurRadius: 1),
  ];

  /// Bottom sheets and floating buttons.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x0F0F1D33), offset: Offset(0, 2), blurRadius: 6),
    BoxShadow(color: Color(0x1F0F1D33), offset: Offset(0, 12), blurRadius: 32),
  ];

  /// The bottom navigation and sticky action bars.
  static const List<BoxShadow> bar = [
    BoxShadow(color: Color(0x0F0F1D33), offset: Offset(0, -2), blurRadius: 16),
  ];
}
