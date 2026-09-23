# Feature: Run out notifications

**From build-plan:** feature 7
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/run-out-notifications`

## Goal

Predict when each staple runs out from the locked stock formula, and schedule a
local notification on the phone ahead of that date, so the household hears
about the rice before the bag is empty rather than after. Like running low, the
prediction is calculated and never stored: a purchase, recount or consumption
event moves the baseline, and the next evaluation replaces every scheduled
reminder with the new plan.

## In scope

- A pure run-out date rule in `lib/features/items/logic/run_out.dart`.
- A pure reminder plan in `lib/features/reminders/logic/`: which items get a
  reminder, when it fires, and what it says.
- A `RunOutNotifier` interface in `lib/features/reminders/data/` and a
  `LocalRunOutNotifier` wrapping `flutter_local_notifications`, including the
  one-time plugin initialisation and permission request.
- Android manifest receivers and boot permission for scheduled notifications,
  and the iOS `AppDelegate` notification-centre delegate, as the plugin README
  requires.
- A `RunOutRemindersCubit` that watches the catalogue, rebuilds the plan on
  every emission and on resume, and replaces the scheduled reminders only when
  the plan changed.
- Home owns the cubit for as long as someone is signed in.

## Out of scope

- Any Home UI for reminders, including a "notifications are off" hint. A denied
  permission leaves reminders silently unshown by the OS; the app does not nag.
- A settings screen for lead time or reminder hour.
- Tapping a notification to open a specific item. A tap opens the app.
- Cancelling reminders on sign out. Every device belongs to a household member,
  and the next signed-in launch replaces the plan anyway.
- Web notifications. The plugin's web implementation throws on `zonedSchedule`,
  so web skips scheduling entirely.
- Exact alarms. Android uses inexact scheduling, so no `SCHEDULE_EXACT_ALARM`
  permission is requested.
- F-11 (catalogue `now` frozen at the last emission).

## Build loop

Run under `/autopilot`, which does not pause between steps. Each step must pass
`flutter analyze` and `flutter test` before it is checked, and
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/run-out-notifications`. `/complete` makes the
final feature commit and merge.

## Build steps

- [x] **Step 1 - Run-out rule and reminder plan** - add
  `runOutAt(Item item)` in `lib/features/items/logic/run_out.dart`, and
  `RunOutReminder` plus `runOutReminders(List<Item> items, {required DateTime
  now})` in `lib/features/reminders/logic/run_out_reminder.dart`.
  *Done when:* unit tests cover a staple with stock, a non-staple (no date), a
  staple already out, a non-finite or huge value, the 09:00 day-before rule, a
  reminder time already passed, ordering, the 64 cap, and the notification
  text.
- [x] **Step 2 - Notifier** - add `RunOutNotifier` and `LocalRunOutNotifier`
  (memoised initialisation with permission request, `cancelAll` then
  `zonedSchedule` per reminder with `AndroidScheduleMode.inexactAllowWhileIdle`,
  a no-op on web), register it with `injectable`, pass it from `main` through
  `GroceryAccountingApp` as a `RepositoryProvider`, add `timezone` as a direct
  dependency (already resolved in `pubspec.lock`), and apply the Android and
  iOS setup. *Done when:* a unit test proves a reminder maps to a
  `TZDateTime` at the same instant; `flutter analyze`, `flutter test` and
  `flutter build apk --debug` pass.
- [x] **Step 3 - Reminders cubit** - add `RunOutRemindersCubit` and its sealed
  state in `lib/features/reminders/presentation/`, with an injected clock,
  `refresh()`, serialised and deduplicated `replaceAll` calls, and a
  `close()` that cancels the subscription. *Done when:* cubit tests prove a
  first plan is scheduled, an unchanged plan is not rescheduled, a changed
  plan is, a notifier failure is reported through `addError` and retried on
  the next evaluation, a stream error is reported, refresh before data is a
  no-op, and close cancels the subscription.
- [x] **Step 4 - Home wiring and device proof** - `HomePage` provides the
  cubit next to `RunningLowCubit` and the resume listener refreshes both.
  *Done when:* home widget tests pass with a fake notifier; Android emulator
  (tier 3) shows the permission prompt, and after a staple is given a
  run-out date a few days out, `dumpsys alarm` lists the app's alarm at the
  expected 09:00 instant, with a clean log; iOS and web results recorded per
  the matrix.

## Files / areas

- New: `lib/features/items/logic/run_out.dart`,
  `lib/features/reminders/logic/run_out_reminder.dart`,
  `lib/features/reminders/data/run_out_notifier.dart`,
  `lib/features/reminders/data/local_run_out_notifier.dart`,
  `lib/features/reminders/presentation/run_out_reminders_cubit.dart`,
  `lib/features/reminders/presentation/run_out_reminders_state.dart`.
- Changed: `lib/main.dart`, `lib/app.dart`, `lib/core/di/injection.dart`,
  `lib/core/di/injection.config.dart` (generated),
  `lib/features/home/presentation/home_page.dart`, `pubspec.yaml`,
  `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift`.
- Tests: `test/features/items/logic/run_out_test.dart`,
  `test/features/reminders/logic/run_out_reminder_test.dart`,
  `test/features/reminders/data/local_run_out_notifier_test.dart`,
  `test/features/reminders/presentation/run_out_reminders_cubit_test.dart`,
  `test/features/reminders/fake_run_out_notifier.dart`,
  `test/features/home/presentation/home_page_test.dart` updated.

## Data / contracts

**Run-out instant.** For a staple (`dailyUsage > 0`):

```
runOutAt = baselineDate + (stockAtBaseline / dailyUsage) days
```

This is the instant `currentStock` reaches zero, derived from the same locked
formula, and it does not depend on `now`, so the plan only changes when a
baseline, usage or name changes. Null when `dailyUsage <= 0`, when either value
is non-finite, or when the result is more than 366 days after the baseline (a
guard against `Duration` overflow; a reminder a year out is not useful).

**Reminder.** One per item whose `runOutAt` is non-null and after `now`. It
fires at 09:00 local time on the calendar day before the run-out day. When that
moment is already at or before `now`, the item gets no reminder: it is about to
run out and is already on, or about to join, the Home running low list, and
firing immediately would repeat on every launch.

**Order and cap.** Soonest `remindAt` first, ties by name then input order.
At most 64 reminders, the iOS limit on pending local notifications.

**Text.** Title `<name> is running out`. Body
`Expected to run out on dd/MM/yyyy.` using the existing `dd/MM/yyyy`
formatter.

**Scheduling.** Replace, never patch: `cancelAll()` then schedule each reminder
with ids `0..n-1`. This app has no other notifications. The instant is passed as
a `TZDateTime` in UTC, so no time zone database or extra plugin is needed; the
local 09:00 is resolved by Dart's local `DateTime`, which already handles a DST
change between now and then.

**Nothing is written** to Firestore. No collection, field or index is added.

**Permission.** Requested once per launch on first scheduling: Android 13+
`POST_NOTIFICATIONS` through the plugin, iOS alert, badge and sound through the
Darwin initialisation settings. A denial is not an error.

## Testing

- Unit: `run_out_test.dart`, `run_out_reminder_test.dart`,
  `local_run_out_notifier_test.dart` (the UTC mapping helper only; the plugin
  itself is proven on device).
- Cubit: `run_out_reminders_cubit_test.dart` with `FakeItemRepository` and a
  fake notifier.
- Widget: `home_page_test.dart` updated, since Home now opens a second items
  watch and needs a `RunOutNotifier` provided.

**Platform matrix.** Plugin, permissions and native setup, so each platform is
run individually, per the project's escalation rule.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Permission prompt on first Home | tier 3 | tier 3 if the iPhone is reachable, else unverifiable | skip (not requested on web) |
| Reminder scheduled at the expected instant | tier 3 (`dumpsys alarm`) | tier 3 if reachable, else unverifiable | skip (not supported) |
| Home loads with no error from reminders | tier 3 | tier 3 if reachable | tier 3 |

## Notes for the AI

- `logic/` stays pure Dart: pass `now` in. `intl` is pure Dart and allowed.
- Reuse `formatPurchaseDate` for the date; do not add another formatter.
- Follow `RunningLowCubit` for stream errors: `addError`, then a failure state.
- A `PlatformException` from the plugin must not reach the widget tree.
- No em dashes in code comments, commits or docs.
- Device proof runs against the shared Firebase project. Give an existing test
  item a temporary daily usage through the edit form, and put every field back
  exactly as found afterwards. Do not create, delete or recount shared items
  just for evidence.

## Verification record

`flutter analyze` clean and `flutter test` 498 passing on every step.

**Android** - emulator `Pixel_10` (API 37, `Europe/Rome`), debug build, tier 3,
on the shared Firebase project, 2026-09-23:

1. First Home after install showed the system prompt "Allow Grocery
   Accounting di Quattro Nero to send you notifications?". Allowed, and
   `dumpsys package` then reports `POST_NOTIFICATIONS: granted=true`.
2. With no staples, `dumpsys alarm` listed no alarm for the app.
3. Gave test item `bh` (3 kg, baseline earlier today) a daily usage of
   0.1 kg. `dumpsys alarm` then listed one `RTC_WAKEUP` alarm for
   `ScheduledNotificationReceiver` at `origWhen=2026-10-22 09:00:00.000`
   (instant 1792652400000 = 09:00 CEST, 07:00 UTC), window +1h (inexact).
   The item runs out about 30 days after its baseline, on 23 October, so
   09:00 on the 22nd is the rule's answer.
4. Set the daily usage back to 0. The alarm left the live list and appears
   only in history as `Reason=alarm_cancelled`, proving the replace path.
5. The run log showed no exception, overflow or error from the app. Emulator
   Play Services noise ignored.

`bh` is back as found: 3 kg, not a staple, threshold 0 kg, category Bakery.
The two edits did not touch its baseline and wrote no `consumptionEvents`.

**iOS** - Rahat's iPhone, wireless: `flutter run` built through Xcode,
compiling the `AppDelegate` change, and installed the app. Flutter then could
not attach ("Flutter could not access the local network"), because the
terminal lacks the macOS Local Network permission. Runtime unverified: the
permission prompt and scheduling on iOS need a human on the phone. The user
waived iOS for this feature on 2026-09-23 ("check on web or android. dont need
to check ios this time"), so it is recorded as skipped, not passed.

**Web** - `flutter build web` passes. Not run: a fresh Chrome profile has no
session, and Home is behind sign-in. The web path is a `kIsWeb` early return.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Permission prompt on first Home | pass (t3) | skip (waived; build and install only) | skip (not requested on web) |
| Reminder scheduled at the expected instant | pass (t3) | skip (waived) | skip (not supported) |
| Home loads with no error from reminders | pass (t3) | skip (waived) | assumed (build only) |


<!-- blueprint:completion {"schemaVersion":1,"specBytes":11414,"specSha256":"9d2421c8a42c8b694278252811dc0fd9c7e9df20ed58905d8f3f4f7923047d23","branch":"refs/heads/feature/run-out-notifications","head":"89abb5bd54810b985b8bc7ed5d19268b00a91dae","baseRef":"refs/heads/main","baseCommit":"a31931b6b3a069e1cf4d393e95b95b0bd4aae7bb","sourceTree":"c9345ae05fe34017c799009ddb6c7ddbbaa0e0c1","absentOptional":[]} -->
