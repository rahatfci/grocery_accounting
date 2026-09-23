import 'package:intl/intl.dart';

/// `MMMM yyyy`, spelled out rather than taken from the device locale, for the
/// same reason the purchase date format is: the interface is English, and no
/// date symbol data has to be initialised before the first frame.
final DateFormat _month = DateFormat('MMMM yyyy');

/// The first instant of the month [day] falls in, in local time.
///
/// Local, because a purchase date is written as a client timestamp from this
/// same clock. A window built in UTC would put a late-evening shop trip in the
/// wrong month for anyone east of Greenwich.
DateTime monthStart(DateTime day) => DateTime(day.year, day.month);

/// The first instant of the month after [month]. December rolls into January.
DateTime nextMonth(DateTime month) => DateTime(month.year, month.month + 1);

/// The first instant of the month before [month]. January rolls back into
/// December.
DateTime previousMonth(DateTime month) => DateTime(month.year, month.month - 1);

/// Whether the month after [month] is worth showing.
///
/// The current month is the last one: `validateDate` refuses a purchase in the
/// future, so a later month can only ever be empty.
bool canViewNextMonth(DateTime month, {required DateTime now}) =>
    monthStart(month).isBefore(monthStart(now));

String monthLabel(DateTime month) => _month.format(month);
