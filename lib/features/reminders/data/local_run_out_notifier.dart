import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:timezone/timezone.dart' as tz;

import '../logic/run_out_reminder.dart';
import 'run_out_notifier.dart';

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'run_out',
    'Running out',
    channelDescription: 'A reminder the day before a staple runs out',
  ),
  iOS: DarwinNotificationDetails(),
);

@LazySingleton(as: RunOutNotifier)
class LocalRunOutNotifier implements RunOutNotifier {
  LocalRunOutNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Initialisation, including the permission prompt, runs once per launch.
  Future<void>? _initialized;

  @override
  Future<void> replaceAll(List<RunOutReminder> reminders) async {
    // The web plugin throws on `zonedSchedule`, so web has no reminders.
    if (kIsWeb) {
      return;
    }
    await _ensureInitialized();
    // This app shows no other notifications, so everything pending is ours.
    await _plugin.cancelAll();
    for (final (id, reminder) in reminders.indexed) {
      await _plugin.zonedSchedule(
        id: id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: toScheduledDate(reminder.remindAt),
        notificationDetails: _details,
        // Inexact needs no exact alarm permission, and a reminder a day
        // ahead does not need to land on the minute.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _ensureInitialized() async {
    try {
      await (_initialized ??= _initialize());
    } catch (_) {
      // Let the next call try again rather than replaying the failure.
      _initialized = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13 and later need the runtime permission. Darwin asks during
    // `initialize`. A denial is the member's choice, not an error.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}

/// The same instant as [remindAt], in UTC.
///
/// UTC needs no time zone database. The local 09:00 was already resolved by
/// `DateTime`, so only the instant has to survive the platform channel.
@visibleForTesting
tz.TZDateTime toScheduledDate(DateTime remindAt) =>
    tz.TZDateTime.from(remindAt, tz.UTC);
