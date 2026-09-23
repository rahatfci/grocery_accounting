import 'package:equatable/equatable.dart';

import '../logic/run_out_reminder.dart';

sealed class RunOutRemindersState extends Equatable {
  const RunOutRemindersState();

  @override
  List<Object?> get props => const [];
}

/// Before the first plan has been scheduled.
final class RunOutRemindersIdle extends RunOutRemindersState {
  const RunOutRemindersIdle();
}

/// [reminders] is what this device has scheduled. It may be empty.
final class RunOutRemindersScheduled extends RunOutRemindersState {
  const RunOutRemindersScheduled(this.reminders);

  final List<RunOutReminder> reminders;

  @override
  List<Object?> get props => [reminders];
}

/// The catalogue could not be read or the plan could not be scheduled. The
/// error itself went to `addError`.
final class RunOutRemindersFailure extends RunOutRemindersState {
  const RunOutRemindersFailure();
}
