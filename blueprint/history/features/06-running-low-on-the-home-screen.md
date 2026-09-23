# Feature: Running low on the home screen

**From build-plan:** feature 6
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/running-low`

## Goal

Show on Home, below the Record a purchase button, every item whose derived
stock is under its low threshold. The list is calculated from `items` with the
locked stock formula and never stored, so a purchase or recount that lifts an
item back over its threshold clears it with no cleanup, and a staple that runs
down overnight appears without anyone writing anything.

## In scope

- A pure `runningLow(items, now)` rule in `lib/features/items/logic/`.
- A `RunningLowCubit` that watches `ItemRepository.watchItems()` and applies the
  rule, with loading, loaded, nothing-low and failure-with-retry states.
- Re-evaluating against a fresh clock when the app resumes, so a Home left open
  in the background does not show yesterday's list.
- A Running low section on Home: one row per item with name, current stock and
  the threshold it is under.
- Home becomes scrollable, so a long list never overflows the phone.

## Out of scope

- Tapping a row to open the item detail. The catalogue already reaches it; a
  second entry point needs its own `ItemsCubit` wiring.
- Run-out dates and notifications (feature 7).
- Adding a low item to the shopping list (feature 8 has no auto-population, by
  the plan).
- F-11 (catalogue `now` frozen at the last emission). This feature fixes the
  same symptom for Home only; the catalogue stays as feature 5 left it.
- Any change to the item schema or to how thresholds are edited.

## Build loop

Run under `/autopilot`, which does not pause between steps. Each step must pass
`flutter analyze` and `flutter test` before it is checked, and
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/running-low`. `/complete` makes the final feature
commit and merge.

## Build steps

- [x] **Step 1 - Running low rule** - add
  `lib/features/items/logic/running_low.dart`: `LowStockItem` (`Equatable`:
  `item`, `stock`) and `runningLow(List<Item> items, {required DateTime now})`.
  *Done when:* unit tests cover under, equal to, and over the threshold; a
  zero threshold; a staple that ran past empty; a non-finite stock; the
  ordering rule; and an empty input.
- [x] **Step 2 - Running low cubit** - add `RunningLowCubit` and
  `RunningLowState` in `lib/features/home/presentation/`, with an injected
  clock, `retry()`, `refresh()` and a `close()` that cancels the subscription.
  *Done when:* cubit tests prove loaded, nothing-low, failure then retry,
  refresh against an advanced clock adding a newly low staple, refresh before
  any data being a no-op, and the subscription being cancelled on close.
- [x] **Step 3 - Home section** - `HomePage` provides the cubit and a
  `HomeView` renders the section, wrapped in a lifecycle listener that calls
  `refresh()` on resume. Home scrolls. *Done when:* widget tests prove each
  state renders, retry resubscribes, and the existing navigation tests still
  pass; Android emulator run (tier 3) shows the section with a real low item,
  and it clears once the item is no longer below its threshold, with a clean
  log.

## Files / areas

- New: `lib/features/items/logic/running_low.dart`,
  `lib/features/home/presentation/running_low_cubit.dart`,
  `lib/features/home/presentation/running_low_state.dart`,
  `lib/features/home/presentation/running_low_section.dart`.
- Changed: `lib/features/home/presentation/home_page.dart`.
- Tests: `test/features/items/logic/running_low_test.dart`,
  `test/features/home/presentation/running_low_cubit_test.dart`,
  `test/features/home/presentation/running_low_section_test.dart`,
  `test/features/home/presentation/home_page_test.dart` updated.

## Data / contracts

**Rule.** An item is running low when
`currentStock(item, now) < item.lowThreshold`, strictly, as the plan says
"below this". Consequences, all intended:

- A zero threshold never flags a non-staple at zero stock, so zero means "do
  not warn me".
- A staple past empty computes negative and is flagged even at a zero
  threshold, because it really is out.
- A non-finite stock or threshold is never flagged, by an explicit finiteness
  check: `formatStock` already shows such a stock as `Unknown` in the catalogue.

**Order.** Out of stock (`stock <= 0`) first, then by name, case-insensitive.
Ties keep input order.

**Nothing is written.** No collection, field or index is added. The cubit only
reads `watchItems()`.

**Freshness.** `now` is taken on every stream emission and on `refresh()`.
`refresh()` re-applies the rule to the last emitted items; before the first
emission, or in a failure state, it does nothing.

**Display.** Each row: item name (one line, ellipsis), trailing current stock
via `formatStock`, subtitle `Below <formatStock(threshold, unit)>`. Nothing
low: "Nothing is running low". Failure: the mapped `DataFailure.message` plus
Try again.

## Testing

- Unit: `running_low_test.dart`.
- Cubit: `running_low_cubit_test.dart`, driving `FakeItemRepository` with an
  injected clock.
- Widget: `running_low_section_test.dart` for the states and retry;
  `home_page_test.dart` updated, because Home now opens its own items watch, so
  the watch counts after pushing the catalogue, report and review screens each
  rise by one.

**Platform matrix.** Substantial UI (a new section and a scroll change), so one
platform per the project's verification policy. No plugins, permissions or
keyboard input are touched.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Section lists a real low item | tier 3 | assumed | assumed |
| Item leaving the low state clears it | tier 3 | assumed | assumed |

## Notes for the AI

- `logic/` stays pure Dart: pass `now` in, never call `DateTime.now()` there.
- Reuse `currentStock` and `formatStock`; do not duplicate the formula.
- Follow `ItemsCubit` for stream errors: `addError`, then a renderable failure
  state.
- Use `AppLifecycleListener` and dispose it; no timer.
- No em dashes in code comments, commits or docs.

## Verification record

Android emulator `Pixel_10` (API 37), debug build, tier 3, on the shared
Firebase project against the existing test item `bh` (3 kg, not a staple,
threshold 0 kg), on 2026-09-23:

1. Home on launch: "Running low" heading, "Nothing is running low". Correct,
   since a zero threshold never flags a non-staple.
2. Edited `bh` threshold to 5 kg, returned to Home: `bh`, "Below 5 kg", "3 kg"
   listed, delivered live through the stream.
3. Edited the threshold back to 0 kg, returned to Home: "Nothing is running
   low". The item cleared itself with nothing written for running low.

`bh` is left exactly as found. The clear was driven by a threshold edit rather
than a recount, so no audit records were added to `consumptionEvents`; a
restock lifting stock over the threshold goes through the same stream path and
is covered by `running_low_cubit_test.dart`. The run log showed no Flutter
exception, overflow or error box; only the known emulator `GoogleApiManager`
noise. Resume refresh is proven by the widget test driving a real lifecycle
change, not on device. iOS and Web: assumed.

## Spec critique

Red-teamed before building. Changes made:

- Pinned the rule to strict `<` and wrote out the zero-threshold, negative and
  non-finite cases, which were undefined.
- Added resume refresh: Home is the one screen that stays mounted all day, so
  without it the list would never pick up a staple crossing its threshold
  (the same defect as F-11).
- Added the scroll change, since a long list in the current centred `Column`
  would overflow.
- Moved row tap-through out of scope rather than half-wiring `ItemsCubit`.
- Named the existing Home tests whose watch counts change.

## Open questions

- None blocking.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":7836,"specSha256":"72f80384b47d63101e370ccf6439c47f991045ceeef7547aabf146da1a9fd267","branch":"refs/heads/feature/running-low","head":"22254e20e91cfef3302eedc6f5f5966b50525126","baseRef":"refs/heads/main","baseCommit":"5ac8ad5ad73776bd2110fc234576d8d23daf136c","sourceTree":"6fde6893ac01d91e9cee8230e486c543b8c8457c","absentOptional":[]} -->
