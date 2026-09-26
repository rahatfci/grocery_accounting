import 'package:flutter/painting.dart';

/// The Figma `Color` variables, one to one. Each semantic token resolves to a
/// primitive below, as it does in the design file.
///
/// Colour follows meaning for the household: [positive] is in the member's or
/// the household's favour, [negative] is against, [warning] is soon.
abstract final class AppColors {
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _navy900 = Color(0xFF0F1D33);
  static const Color _navy700 = Color(0xFF34425C);
  static const Color _navy600 = Color(0xFF4A5670);
  static const Color _navy500 = Color(0xFF6B7489);
  static const Color _navy400 = Color(0xFF8A93A6);
  static const Color _navy300 = Color(0xFFA3ABBC);
  static const Color _navy200 = Color(0xFFC8CEDA);
  static const Color _navy100 = Color(0xFFE2E6EE);
  static const Color _navy50 = Color(0xFFEEF0F4);
  static const Color _navy25 = Color(0xFFF5F6F8);
  static const Color _green800 = Color(0xFF1A3B2D);
  static const Color _green700 = Color(0xFF244F3D);
  static const Color _green600 = Color(0xFF1A7F55);
  static const Color _green200 = Color(0xFFBFDCCB);
  static const Color _green100 = Color(0xFFD8EDE1);
  static const Color _green50 = Color(0xFFE9F4EE);
  static const Color _red700 = Color(0xFFA82626);
  static const Color _red600 = Color(0xFFCF3434);
  static const Color _red50 = Color(0xFFFCEDED);
  static const Color _amber700 = Color(0xFF9A5B00);
  static const Color _amber500 = Color(0xFFD98E04);
  static const Color _amber50 = Color(0xFFFDF4E3);
  static const Color _blue700 = Color(0xFF2B4C9B);
  static const Color _blue50 = Color(0xFFE6EDFB);
  static const Color _purple700 = Color(0xFF5E3A9A);
  static const Color _purple50 = Color(0xFFF0E9FA);
  static const Color _rose700 = Color(0xFF9A2E5A);
  static const Color _rose50 = Color(0xFFFBE8EF);

  static const Color textPrimary = _navy900;
  static const Color textSecondary = _navy600;
  static const Color textTertiary = _navy500;
  static const Color textPlaceholder = _navy300;
  static const Color onBrand = _white;
  static const Color brand = _green700;
  static const Color positive = _green600;
  static const Color negative = _red600;
  static const Color negativeStrong = _red700;
  static const Color warning = _amber700;

  static const Color iconPrimary = _navy900;
  static const Color iconSecondary = _navy500;
  static const Color iconDisabled = _navy300;

  static const Color background = _navy25;
  static const Color surface = _white;
  static const Color subtle = _navy50;
  static const Color muted = _navy100;
  static const Color brandStrong = _green800;
  static const Color brandSubtle = _green50;
  static const Color brandMuted = _green200;
  static const Color positiveSubtle = _green50;
  static const Color negativeSubtle = _red50;
  static const Color warningSubtle = _amber50;
  static const Color inverse = _navy900;
  static const Color inverseSecondary = _navy700;

  /// Behind bottom sheets, at the 45% the design uses.
  static const Color scrim = Color(0x730F1D33);
  static const Color handle = _navy200;
  static const Color controlOff = _navy200;

  static const Color borderSubtle = _navy100;
  static const Color borderDefault = _navy200;
  static const Color borderInput = _navy400;
  static const Color borderFocus = _green700;
  static const Color borderNegative = _red600;

  static const Color dataTrack = _navy100;
  static const Color dataPrimary = _green700;
  static const Color dataSecondary = _navy200;
  static const Color dataPositive = _green600;
  static const Color dataNegative = _red600;
  static const Color dataWarning = _amber500;

  static const Color shadow = _navy900;

  /// Member avatar colour pairs, background then initials, in the order the
  /// design numbers them.
  static const List<({Color background, Color foreground})> avatars = [
    (background: _green100, foreground: _green700),
    (background: _blue50, foreground: _blue700),
    (background: _amber50, foreground: _amber700),
    (background: _purple50, foreground: _purple700),
    (background: _rose50, foreground: _rose700),
  ];
}
