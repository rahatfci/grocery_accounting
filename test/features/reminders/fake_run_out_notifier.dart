import 'dart:async';

import 'package:grocery_accounting/features/reminders/data/run_out_notifier.dart';
import 'package:grocery_accounting/features/reminders/logic/run_out_reminder.dart';

class FakeRunOutNotifier implements RunOutNotifier {
  /// Every plan handed over, in order.
  final calls = <List<RunOutReminder>>[];

  /// When set, the next call throws this once and then clears it.
  Object? throwsOnce;

  /// When set, a call waits on this before returning, so a test can hold one
  /// schedule in flight.
  Completer<void>? gate;

  int _inFlight = 0;

  /// The most calls ever running at the same time.
  int maxInFlight = 0;

  @override
  Future<void> replaceAll(List<RunOutReminder> reminders) async {
    calls.add(reminders);
    _inFlight++;
    if (_inFlight > maxInFlight) {
      maxInFlight = _inFlight;
    }
    try {
      await gate?.future;
    } finally {
      _inFlight--;
    }
    final thrown = throwsOnce;
    if (thrown != null) {
      throwsOnce = null;
      throw thrown;
    }
  }
}
