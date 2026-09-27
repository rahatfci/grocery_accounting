import 'package:intl/intl.dart';

// Patterns spelled out rather than taken from a locale, as `formatPurchaseDate`
// is: the interface is English and no symbol data has to be initialised.
final DateFormat _dayMonth = DateFormat('dd/MM');
final DateFormat _weekday = DateFormat('EEEE');

/// `dd/MM`, for dates close enough that the year goes without saying.
String formatDayMonth(DateTime date) => _dayMonth.format(date);

/// The weekday's name: `Thursday`.
String weekdayName(DateTime date) => _weekday.format(date);

/// Whole calendar days from [date] to [now], counted on local dates so an
/// evening and the next morning are one day apart.
int daysBefore(DateTime date, DateTime now) {
  final from = DateTime(date.year, date.month, date.day);
  final to = DateTime(now.year, now.month, now.day);
  return (to.difference(from).inHours / Duration.hoursPerDay).round();
}

/// `Today`, `Yesterday`, or the day and month.
String relativeDay(DateTime date, {required DateTime now}) =>
    switch (daysBefore(date, now)) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => formatDayMonth(date),
    };
