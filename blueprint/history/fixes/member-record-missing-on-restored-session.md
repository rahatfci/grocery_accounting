# Fix: Member record missing on a restored session

**Type:** Fix
**Status:** verified
**Branch:** `fix/member-record-missing-on-restored-session`

## The problem

Spending shows every purchase under "Unknown member", and the CSV export shows
a raw user id as the payer, because the signed-in account has no
`users/{uid}` document.

`AuthGate` writes that mirror document only in a `BlocConsumer` listener with
`listenWhen: current is AuthSignedIn && previous is! AuthSignedIn`. The auth
cubit is created in `main` before `runApp`, and Firebase restores a saved
session quickly. So by the time the gate first builds, the state is already
`AuthSignedIn`. A listener only hears changes after it subscribes, so it never
fires, and the mirror is never written. The mirror only happens on a fresh
sign-in through the form, and an account that stays signed in never gets
one.

Established on the Android emulator on 2026-09-24 with temporary debug prints:
the gate's first build logged `state=AuthSignedIn`, the listener never ran,
`upsertCurrentMember` was never called, and the `users` watch reported an
empty collection. The debug code was reverted.

## The fix

`AuthGate` becomes a `StatefulWidget`. In `initState`, if the cubit is already
`AuthSignedIn`, it mirrors that user. The listener keeps handling every later
transition into a session. The write stays fire and forget, as before.

It must not break anything:
- A rebuild while signed in still writes nothing.
- Sign out and back in still writes again.
- No session still writes nothing.
- A failed write still never blocks the gate.

The doc comment's claim that "the next sign in writes it again" is corrected.

This fixes the record for any account that opens the app. Purchases already
saved keep their `paidByUserId`, which is the same uid, so they resolve to the
member as soon as the document exists. No data migration is needed.

## Build steps

- [x] **Step 1 - Mirror an already restored session** - make `AuthGate`
  stateful, and mirror in `initState` when the state is already
  `AuthSignedIn`. *Done when:* a new widget test, with the cubit already
  signed in before the gate mounts, sees exactly one upsert. The existing gate
  tests pass unchanged. On the Android emulator, relaunching with the saved
  session makes the household list non-empty, and Spending names the member
  instead of "Unknown member", with a clean log.

## Verify

- `flutter analyze`, `flutter test`.
- Relaunch the app on the emulator with the saved session, then open Spending:
  the payer is named.

## Verification record

2026-09-24.

- The new widget test, with the cubit signed in before the gate mounts,
  failed against the old gate (expected one upsert, got none) and passes with
  the fix. The existing gate tests pass unchanged, and the whole suite passes
  707 tests. `flutter analyze` is clean.
- Android emulator `Pixel_10` (API 37), tier 3: the app was relaunched with the
  saved session. Spending for September 2026 now shows "Equal share across 1
  member" and the member `arrahat0003` for the whole month, where it
  previously showed "Unknown member". The mirror document was written on
  launch, and the log was clean.
- iOS and web: assumed. They share the Dart change.

Other household members get their record the next time they open the app.
Until then, a purchase they paid for still shows "Unknown member".


<!-- blueprint:completion {"schemaVersion":1,"specBytes":3383,"specSha256":"5a403167eb43a5ce9073260fb35ddaac2bde5f4112f41954415dd99b001f0ced","branch":"refs/heads/fix/member-record-missing-on-restored-session","head":"21a8e6d35a0c31e34b5abcb882154797bf973fd2","baseRef":"refs/heads/main","baseCommit":"f74c63e0ff9b80170e9aa3ea2f876f284ae7ce5d","sourceTree":"01c4e89abccc96401740e38e6978556cd9b4253e","absentOptional":[]} -->
