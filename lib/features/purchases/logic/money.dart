import 'package:intl/intl.dart';

/// EUR as the household reads it on a receipt: a decimal comma, symbol last.
/// The interface is English, but a price is not prose.
final NumberFormat _euro = NumberFormat.currency(
  locale: 'it_IT',
  symbol: '€',
  decimalDigits: 2,
);

/// `dd/MM/yyyy`, spelled out rather than taken from a locale, so no date
/// symbol data has to be initialised before the first frame.
final DateFormat _day = DateFormat('dd/MM/yyyy');

String formatEuro(double amount) => _euro.format(amount);

/// An amount as a money field shows it: two decimals and a decimal comma,
/// the way a receipt prints it, and no symbol, since the field has its own.
String formatAmountInput(double amount) =>
    amount.toStringAsFixed(2).replaceAll('.', ',');

String formatPurchaseDate(DateTime date) => _day.format(date);

/// A difference in EUR with its sign always shown: `+42,10 €`, `−18,30 €`.
/// The minus is the typographic one, so it reads at the width of the plus.
String formatSignedEuro(double amount) {
  final magnitude = formatEuro(amount.abs());
  if (amount.abs() < 0.005) {
    return magnitude;
  }
  return amount > 0 ? '+$magnitude' : '−$magnitude';
}
