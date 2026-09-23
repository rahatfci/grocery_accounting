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

String formatPurchaseDate(DateTime date) => _day.format(date);
