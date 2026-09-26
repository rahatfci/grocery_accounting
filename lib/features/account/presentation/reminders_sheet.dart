import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/notes.dart';
import '../../reminders/logic/run_out_reminder.dart';
import '../../reminders/presentation/run_out_reminders_cubit.dart';
import '../../reminders/presentation/run_out_reminders_state.dart';

/// Lists the run-out reminders this phone has scheduled.
Future<void> showRemindersSheet(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const RemindersSheet());

class RemindersSheet extends StatelessWidget {
  const RemindersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<RunOutRemindersCubit, RunOutRemindersState>(
      builder: (context, state) => SheetFrame(
        children: [
          SheetTitle(
            title: 'Run-out reminders',
            subtitle: Text(
              'A notification at $reminderHour:00 the day before a staple '
              'runs out, from the daily usage set in the pantry.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          switch (state) {
            RunOutRemindersScheduled(:final reminders)
                when reminders.isNotEmpty =>
              RowGroup(
                children: [
                  for (final reminder in reminders)
                    AppRow(
                      body: RowText(
                        title: reminder.itemName,
                        subtitle:
                            'Reminder ${formatDayMonth(reminder.remindAt)} · '
                            'runs out ${formatDayMonth(reminder.runsOutAt)}',
                      ),
                    ),
                ],
              ),
            RunOutRemindersFailure() => const InfoNote(
              icon: Symbols.warning_rounded,
              text:
                  'The reminders could not be set on this phone. They are '
                  'tried again when the app is next opened.',
            ),
            _ => const InfoNote(
              text:
                  'No staple is due to run out yet. Staples are the items '
                  'with a daily usage.',
            ),
          },
        ],
      ),
    );
  }
}
