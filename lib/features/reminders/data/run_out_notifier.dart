import '../logic/run_out_reminder.dart';

/// Schedules run-out reminders as local notifications on this device.
abstract interface class RunOutNotifier {
  /// Cancels everything scheduled and schedules [reminders] in its place.
  Future<void> replaceAll(List<RunOutReminder> reminders);
}
