# Feature: Stock tracking

**From build-plan:** feature 5
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/stock-tracking`

## Goal

Make the pantry half of every item visible and correctable. Each item shows its
current stock, derived from the locked baseline formula, so staples visibly run
down day by day with nothing written daily. A member can log that something was
used, adjust stock up or down for an event, or recount it outright, and each of
those writes a fresh baseline pair plus a `consumptionEvents` audit record in one
atomic batch that also works offline.

This is what features 6 and 7 read. If the number here is wrong, running low and
run-out notifications lie.

## In scope

- Current stock on every catalogue row, from `currentStock` in
  `lib/features/items/logic/stock.dart`, never a stored live number.
- An item detail screen, opened by tapping a catalogue row: current stock, daily
  usage, low threshold, an Edit action that opens the existing form, and three
  stock actions - Log use, Adjust, Recount.
- One stock-event sheet serving all three actions: quantity, unit (only units
  convertible to the item's own), a direction choice for Adjust, optional note.
- Writing the event and the new baseline pair in one Firestore batch.
- Loading, failure-with-retry, and item-no-longer-exists states on the detail
  screen; validation, refused-write and unexpected-error feedback on the sheet.

## Out of scope

- A history view of `consumptionEvents`. See Open questions.
- Running low on Home (feature 6) and run-out notifications (feature 7).
- Backdating an event. Every event is stamped at the moment it is recorded.
- Editing or deleting a past event, or undoing one. A mistaken event is
  corrected by a recount.
- Any change to the purchase commit, which already restocks (feature 3).
- Any change to `firestore.rules`: the existing "signed in may read and write"
  rule already covers the new collection.

## Build loop

Run under `/autopilot`, which does not pause between steps. Each step must pass
`flutter analyze` and `flutter test` before it is checked, and
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/stock-tracking`. `/complete` makes the final
feature commit and merge.

## Build steps

- [x] **Step 1 - Stock event logic** - add
  `lib/features/items/logic/stock_event.dart`: `StockEventType` enum
  (`consumed`, `adjustment`, `recount`, each with a stable stored `key`),
  `StockEvent` (`Equatable`: `itemId`, `type`, `quantity`, `unit`, `userId`,
  `note`), `stockEventQuantityError(type, raw)` validation, and
  `baselineAfter(Item, StockEvent, {required DateTime now})` returning `double?`
  (null when the unit cannot be converted, via `convertToItemUnit`). Add
  `formatStock(double, ItemUnit)` to `stock.dart`. *Done when:*
  `test/features/items/logic/stock_event_test.dart` and the extended
  `stock_test.dart` cover every rule in Data / contracts, including the zero
  clamps, recount to zero, unit conversion, the unconvertible null, and each
  validation message; analyze clean, tests green.
- [x] **Step 2 - Persist a stock event** - add `stockEventToFirestore` to
  `lib/features/items/data/`, and `recordStockEvent(Item, StockEvent, {required
  DateTime now})` to `ItemRepository` and `FirestoreItemRepository`: one batch
  that sets a new `consumptionEvents` doc and updates only `stockAtBaseline` and
  `baselineDate` on the item. Unconvertible units return
  `Err(UnexpectedDataFailure())` without writing. Update
  `FakeItemRepository`. *Done when:* a DTO test pins every stored field and
  key, including signed adjustment quantity and a null note; analyze clean,
  tests green.
- [x] **Step 3 - Stock in the catalogue** - `ItemsCubit` takes an injectable
  clock (default `DateTime.now`), `ItemsLoaded` carries the `now` its stock was
  computed against, and the cubit gains `recordStockEvent`, catching and
  reporting unexpected errors like `save`. `ItemListPage` takes the signed-in
  `AppUser`; Home passes it. Each row shows `formatStock` of current stock.
  *Done when:* cubit tests cover the clock and `recordStockEvent` (ok, mapped
  failure, thrown error); a widget test shows a staple's stock decreased by the
  elapsed days and a non-staple unchanged; analyze clean, tests green.
- [x] **Step 4 - Item detail screen** - add
  `lib/features/items/presentation/item_detail_page.dart`. Tapping a row opens
  it instead of the form. It reads the item by id from `ItemsCubit` state and
  renders loading, failure with retry, "no longer in the catalogue", or the
  item: current stock, daily usage (or "Not a staple" when zero), low threshold,
  Edit in the app bar, and Log use / Adjust / Recount buttons (not yet wired).
  *Done when:* widget tests cover each of the four states and Edit opening the
  form prefilled; analyze clean, tests green.
- [x] **Step 5 - Stock event sheet** - add
  `lib/features/items/presentation/stock_event_sheet.dart` and wire the three
  buttons to it. Quantity field labelled per type ("Amount used", "Amount",
  "Counted amount"), unit dropdown from `unitsFor(item)`, an Add / Remove
  segmented choice shown only for Adjust, optional Note. Save validates, calls
  `recordStockEvent` under the shared 600 ms refusal window, pops on success,
  and shows a `FailureMessage` on refusal that clears when a field changes. The
  refusal window moves to one shared constant used by the item form, the
  purchase page and this sheet. *Done when:* widget tests cover each type's
  submitted `StockEvent` (including a Remove adjustment stored negative and a
  converted unit), validation errors, a refused write staying open with the
  message, and the saving state disabling input; analyze clean, tests green.
- [x] **Step 6 - Device run** - on the Android emulator: open the catalogue,
  open an item, recount it, log use, adjust it both ways, and confirm the
  detail and catalogue stock follow. *Done when:* screenshots of the catalogue,
  the detail screen and the sheet with the keyboard up, and a run log with no
  exception, overflow or red box.

## Files / areas

- `lib/features/items/logic/stock.dart`, `stock_event.dart` (new)
- `lib/features/items/data/item_repository.dart`,
  `firestore_item_repository.dart`, `stock_event_dto.dart` (new)
- `lib/features/items/presentation/items_cubit.dart`, `items_state.dart`,
  `item_list_page.dart`, `item_detail_page.dart` (new),
  `stock_event_sheet.dart` (new), `item_form_page.dart` (refusal window only)
- `lib/features/purchases/presentation/record_purchase_page.dart` (refusal
  window only)
- `lib/core/refusal_window.dart` (new)
- `lib/features/home/presentation/home_page.dart` (pass the user)
- Matching tests under `test/features/items/` and the fake repository

## Data / contracts

**Stock rules.** `start = max(0, currentStock(item, now))`, and `q` is the event
quantity converted into the item's own unit:

| Type | Entered quantity | New `stockAtBaseline` |
| --- | --- | --- |
| `consumed` | greater than 0 | `max(0, start - q)` |
| `adjustment` | greater than 0, stored signed: Add positive, Remove negative | `max(0, start + q)` |
| `recount` | 0 or greater | `q` |

`start` clamps a negative derived stock at zero for the same reason
`restockedBaseline` does. The result clamps at zero because a kitchen cannot hold
negative rice: using more than the estimate means the estimate was low, and
zero is the honest new baseline. `baselineDate` is the same client `now` for the
item and the event, never a server timestamp, matching feature 3's reasoning:
offline a server timestamp resolves at sync time and breaks the pair.

**`consumptionEvents/{eventId}`**, id generated by `doc()` on the client:

- `itemId` (string) - the item's document id
- `quantity` (double) - as entered, in `unit`; signed for `adjustment`
- `unit` (string) - `ItemUnit.key` as entered, not the item's unit
- `date` (timestamp) - client `now`
- `userId` (string) - the signed-in `AppUser.uid`, passed down from Home
- `type` (string) - `consumed` | `adjustment` | `recount`
- `note` (string or null) - trimmed, empty stored as null

**Atomicity.** One `WriteBatch`: `set` the event, `update` the item with only
`stockAtBaseline` and `baselineDate`, so the catalogue half is never touched. A
batch, not a transaction, because a transaction fails offline. Concurrency is
last write wins, as the plan states: two members recording against the same item
at once each compute from the stock they saw. The item update fails with
`not-found` if the item was deleted elsewhere, which rejects the whole batch.

**Validation messages.** Empty: "Enter a number". Not a number: "Enter a valid
number". `consumed` or `adjustment` at or below zero: "Must be greater than zero".
`recount` below zero: "Cannot be negative".

**Display.** `formatStock` clamps negatives to zero, rounds to 2 decimals, drops
trailing zeros, and appends the unit label: `3.5 kg`, `0 pcs`, `12 g`.

## Testing

- Unit: `stock_event_test.dart` (rules, conversion, validation),
  `stock_test.dart` (`formatStock`), `stock_event_dto_test.dart`.
- Cubit: `items_cubit_test.dart` extended.
- Widget: `item_list_page_test.dart` extended, `item_detail_page_test.dart`,
  `stock_event_sheet_test.dart`, `home_page_test.dart` updated for the user.
- `FirestoreItemRepository` stays untested at the Firestore boundary, as with
  the other repositories; the DTO and the rules are the tested seam.

**Platform matrix.** Substantial UI, so one platform per the project's
verification policy. The sheet has a text field, which touches keyboard insets,
so the device run includes the keyboard.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Catalogue and detail show derived stock | tier 3 | assumed | assumed |
| Recount, use and adjust update stock | tier 3 | assumed | assumed |
| Sheet usable with the keyboard up | tier 3 | assumed | assumed |

## Notes for the AI

- `logic/` stays pure Dart: pass `now` in, never call `DateTime.now()` there.
- Reuse `convertToItemUnit` and `unitsFor` from
  `lib/features/purchases/logic/quantity_conversion.dart`; do not duplicate.
- Follow `ItemsCubit.save` for error handling: `addError` then
  `Err(UnexpectedDataFailure())`.
- The detail screen must not pop itself when the item disappears. A pop from
  its context would remove whatever route is on top, including the edit form
  mid-delete. It renders the gone state instead.
- No em dashes in code comments, commits or docs.

## Verification record

Android emulator `Pixel_10` (API 37), debug build, tier 3, on the shared
Firebase project against the existing test item `bh`, on 2026-09-23:

- Catalogue row showed derived stock (`0.06 kg`), detail matched.
- Recount 5 kg -> `5 kg`; Log use 1.5 kg -> `3.5 kg`; Adjust Add 0.5 kg ->
  `4 kg`; Adjust Remove 1 kg -> `3 kg`. Catalogue row followed (`3 kg`).
- Adjust without a direction was refused with "Choose add or remove".
- **Defect found and fixed during this step:** that error stayed on screen
  after Remove was chosen, because the validator read the direction captured
  in an earlier build. It now validates the field's own value; a widget test
  that failed before the fix pins it, and a relaunch confirmed it clears.
- Run log: no exception, overflow or red box. Two `Skipped frames` lines at
  debug cold start only; `GoogleApiManager` and Phenotype lines are the known
  unprovisioned Play Services noise.
- **Keyboard not proven.** The emulator showed its floating IME toolbar, not a
  full soft keyboard, so `viewInsets` handling in the sheet was not exercised.
  The sheet reuses the purchase line sheet's inset padding. iOS and Web are
  `assumed`.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Catalogue and detail show derived stock | pass (t3) | assumed | assumed |
| Recount, use and adjust update stock | pass (t3) | assumed | assumed |
| Sheet usable with the keyboard up | unverified (t3, no full IME) | assumed | assumed |

## Open questions

Neither blocks implementation.

- **`consumptionEvents` still has no reader.** This feature fixes the write
  shape to the plan's own fields and writes the collection for the first time.
  No build-plan feature displays it. Add a history view to the plan if the audit
  trail should be readable in the app.
- **Adjustment stores a signed quantity.** The plan names the field `quantity`
  without a sign rule; signed is the only way a Remove adjustment stays
  distinguishable from an Add in the audit trail without a new field.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":12544,"specSha256":"980bcab1f5d7cb027f13264fffc961271a819789288304f409e68c414a154c64","branch":"refs/heads/feature/stock-tracking","head":"6f3ea7abeba3cde9d1a60e9e40849e51a9ff1af8","baseRef":"refs/heads/main","baseCommit":"3781750e9b5761351dea54ba5906cefcbbdb24d3","sourceTree":"87a4ac3e63f509fcd9b11304584b12f89f5c4801","absentOptional":[]} -->

## Findings

### 5/F-10 [P1] closed - Non-finite quantities pass validation and poison the shared stock baseline

**File:** lib/features/items/logic/stock_event.dart:88
**Found:** 2026-09-23 by /audit independent (scope: current; lens: quality, security, tests)
**Why it matters:** `stockEventQuantityError` relies on `parseDecimal`, which is
`double.tryParse`, and Dart parses `NaN`, `Infinity` and `1e400` (as Infinity).
Both comparisons in the switch are false for NaN and for +Infinity, so the
function returns null and the sheet accepts the value. Confirmed with a scratch
Dart run: `NaN` and `Infinity` give `lt0=false le0=false`. A recount of `NaN` or
`Infinity`, an adding adjustment of `Infinity`, or any consumption of `NaN` then
makes `baselineAfter` return a non-finite value (the `after < 0` clamp is false
for NaN), and `recordStockEvent` writes it into the shared `items` document,
which Firestore accepts.

Every member's catalogue then calls `formatStock` on it
(item_list_page.dart:205, item_detail_page.dart:108), and `formatStock`
(stock.dart:45) calls `.round()`, which throws `Unsupported operation:
Infinity or NaN toInt` (also confirmed). The row and the detail screen throw in
`build()`, so the Recount button that would repair the value is unreachable,
and the item edit form deliberately never writes `stockAtBaseline`. The
corruption has no in-app recovery, and features 6 and 7 read the same number.
Entry needs a pasted value or a hardware or web keyboard, so it is uncommon, but
web is a stated target and the path is concrete. The new `formatStock` also
turns pre-existing non-finite item fields (the item form's `validateRequiredAmount`
accepts `Infinity` for daily usage) into a render crash.

**Suggested fix:** In `stockEventQuantityError`, return 'Enter a valid number'
when `!parsed.isFinite`, with a unit test for `NaN`, `Infinity` and `1e400`. Make
`formatStock` total by treating a non-finite stock as zero (or a placeholder)
before rounding, with a test, so bad shared data renders rather than throws.
The same `isFinite` check belongs in the shared amount validators the item form
and purchase lines use, though those are outside this delta. No current
requirement is lost.
**Resolution:** fixed by autopilot repair on `feature/stock-tracking`. `stockEventQuantityError` now rejects any non-finite parse with "Enter a valid number"; `baselineAfter` resets a non-finite derived stock to zero before applying the event; `formatStock` renders a non-finite value as `Unknown` instead of throwing, so the detail screen and its Recount stay reachable. Tests: non-finite inputs for every event type, NaN stored stock in `baselineAfter`, `formatStock` on NaN and infinity, and a detail widget test with a NaN baseline. `flutter analyze` clean, `flutter test` 430 passed. Awaiting a fresh independent review to close. Not addressed: the item form's `validateRequiredAmount` (feature 2) accepts the same values for daily usage and threshold; the display guard now keeps that from crashing.
Closed 2026-09-23 by /audit independent (fresh subagent, claude-opus-5-5) at
3813c40. Re-examined `stock_event.dart:85-102`, `stock_event.dart:62-79` and
`stock.dart:47-53`: `NaN`, `Infinity`, `-Infinity` and `1e400` are now refused
with "Enter a valid number" (`stock_event_test.dart:189`), a non-finite derived
stock resets to zero in `baselineAfter` (`stock_event_test.dart:147`), and
`formatStock` returns `Unknown` for NaN and infinity (`stock_test.dart:129-130`,
`item_detail_page_test.dart:74`). The non-finite defect this entry describes is
gone and the repair introduced no new defect. A separate input class, finite but
huge values, still reaches the same crash and is tracked as F-12.

### 5/F-12 [P1] closed - Huge finite quantities still write a stock that `formatStock` cannot render

**File:** lib/features/items/logic/stock.dart:51
**Found:** 2026-09-23 by /audit independent (scope: current; lens: quality, security, tests)
**Why it matters:** `stockEventQuantityError` (stock_event.dart:85) accepts any
finite value, and `formatStock` multiplies by 100 before `round()`. A recount of
`1e307` (finite, non-negative, so valid) makes `baselineAfter` return `1e307`,
which `recordStockEvent` writes to the shared item. `formatStock(1e307)` then
computes `1e307 * 100`, which overflows to Infinity, and `round()` throws
`Unsupported operation: Infinity or NaN toInt` (confirmed with a scratch Dart
run, which also showed values from about `1e19` render as a wrong clamped
`92233720368547760`). That is exactly the F-10 outcome: the catalogue row
(item_list_page.dart:205) and the detail screen (item_detail_page.dart:108)
throw in `build()` for every member, the Recount button that would repair it is
inside the failing subtree, the edit form never writes `stockAtBaseline`, and a
purchase restock only adds to it. There is no in-app recovery.

A related path writes Infinity itself: a recount or Add adjustment of `1e306` kg
on an item measured in g passes validation, and `convertToItemUnit` multiplies
by 1000 to Infinity, which `baselineAfter` returns and the batch writes. That
one renders `Unknown` and a recount repairs it, but features 6 and 7 read the
stored number. Entry needs an exponent or a very long digit string, so reach is
the same as F-10's (web or a hardware keyboard).

**Suggested fix:** Refuse implausible magnitudes at the boundary and never write
a non-finite baseline. In `stockEventQuantityError`, add an upper bound (for
example "Too large" above `1e9`) with tests for `1e307` and `1e306`. In
`FirestoreItemRepository.recordStockEvent`, return
`Err(UnexpectedDataFailure())` when `baselineAfter` is not finite, the same way
it refuses an unconvertible unit. Make `formatStock` total for any double, for
example by returning `Unknown` when `(stock * 100)` is not finite or its
magnitude exceeds the int range, with a test for `1e307`. No current
requirement is lost.
**Resolution:** fixed by autopilot repair on `feature/stock-tracking`, first attempt. `formatStock` no longer scales or converts to int: it uses `toStringAsFixed(2)` and trims zeros, so any finite double renders (exponent form from 1e21) and non-finite reads `Unknown`. `baselineAfter` returns null when the result is not finite, so the repository refuses the write before anything reaches the item. No upper bound was added to validation: the plans set no limit and inventing one is a product decision. Tests: overflowing recount into g and overflowing adjustment return null; `formatStock` on 1e307, a 20-digit value and small values; a detail widget test with a 1e307 baseline. `flutter analyze` clean, `flutter test` 433 passed. Awaiting a fresh independent review to close.
Closed 2026-09-23 by /audit independent (fresh subagent, claude-opus-5-5) at
6f3ea7a. Re-examined `stock.dart:47-60` and `stock_event.dart:62-83`.
`formatStock` no longer multiplies or calls `round()`; a scratch Dart run of the
same logic rendered `1e307`, `double.maxFinite`, `1e19`, `9.99e20`, `1e21` and a
20-digit value without throwing, and non-finite input reads `Unknown`, so no
stored double can take down the catalogue row or the detail screen (tests at
`stock_test.dart:129-134` and `item_detail_page_test.dart:82`). `baselineAfter`
returns null for a non-finite result (`stock_event_test.dart:165`), and
`FirestoreItemRepository.recordStockEvent` already refuses a null baseline
before building the batch, so an overflowing kg-to-g entry no longer writes
Infinity. The original defect is gone and the repair introduced no new one.
Not adding a magnitude cap is a product call, not a defect: any finite stored
value now renders and a recount repairs it.

## Independent review

**Status:** passed
**Target commit:** 6f3ea7abeba3cde9d1a60e9e40849e51a9ff1af8
**Base commit:** 3781750e9b5761351dea54ba5906cefcbbdb24d3
**Base ref:** main
**Spec hash:** 980bcab1f5d7cb027f13264fffc961271a819789288304f409e68c414a154c64
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** runtime default (exact model not known until reviewer starts)
**Requested execution:** automatic
**Requested at:** 2026-09-23T18:33:58Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-23T18:36:10Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Commands

- `flutter analyze`: pass (no issues)
- `flutter test`: pass (433 tests)
- `git rev-parse HEAD`, `git merge-base main HEAD`, `shasum -a 256 blueprint/context/current-feature.md`, `git status --porcelain --untracked-files=all`: pass (freshness confirmed)
- scratch `dart run` of the `formatStock` logic on extreme values: pass (no throw from `1e-300` to `double.maxFinite`)

## Evidence

- Freshness: HEAD equals target, `main` merge base equals base, raw spec SHA-256 matches, spec tracked, only `review.md` and `findings.md` differ.
- Full delta reviewed: 8 commits, 23 files (stock logic, stock event DTO and repository batch, cubit clock, catalogue stock, detail page, stock event sheet, shared refusal window, tests).
- Spec contracts checked: stock rules and clamps, signed adjustment, client timestamp pair in one `WriteBatch`, only `stockAtBaseline` and `baselineDate` updated, validation messages, `formatStock` display rule, detail page not popping on a gone item.
- `firestore.rules` unchanged; its signed-in wildcard covers `consumptionEvents` as the spec states.
- No skipped, focused or placeholder tests found under `test/`.

## Findings

- F-12 closed (repair verified at 6f3ea7a)
- F-11 re-examined, still open at P2 (non-blocking)
- No new findings

## Remaining risk

- F-11 [P2] open: displayed stock stays at the last stream emission's instant until the stream re-emits.
- Earlier-feature findings F-02 to F-06, F-08, F-09 (P2/P3) remain open, and F-07 remains fixed; this review did not re-examine them.
- A stock event whose result overflows to a non-finite baseline is refused as `UnexpectedDataFailure` ("Something went wrong. Try again") rather than a validation message; reachable only with exponent-sized input.
- `FirestoreItemRepository.recordStockEvent` has no test at the Firestore boundary, by the spec's decision; the DTO and `baselineAfter` are the tested seam.
- No device run in this review; Check was not required. The spec's own record leaves the sheet with a full soft keyboard unverified, and iOS and Web assumed.
- No combined Verify command and no integration test runner exist for this project.
