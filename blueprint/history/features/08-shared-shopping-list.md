# Feature: Shared shopping list

**From build-plan:** feature 8
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/shared-shopping-list`

## Goal

A shopping list on Home that every member adds to by hand and sees update live
on every device. Ticking an entry removes it. Saving a purchase removes every
entry that purchase covers, in the same batch that writes the spend, so after
shopping, the list holds only what is still missing.

## In scope

- A `shoppingList` collection with the planned fields, read and written only
  through a `ShoppingListRepository` in `lib/features/shopping_list/data/`.
- A Shopping list section on Home, below Running low: an add field, one row per
  entry, and loading, empty, and failure-with-retry states.
- Adding an entry. It is linked to a catalogue item automatically when its text
  names exactly one item.
- Ticking an entry deletes it for everyone (user decision, 2026-09-24).
- Saving a purchase deletes the entries it matches, atomically with the purchase
  write, offline included.

## Out of scope

- Auto-populating the list from running low or anything else. The plan says the
  list is created only by hand.
- Editing an entry's text, reordering entries, or an undo.
- Showing who added an entry. `addedByUserId` is stored, but nothing displays it.
- An item picker on the add form. Linking is by name only.
- Receipt scanning (features 9 to 11). A scanned purchase goes through the same
  commit, so it inherits the clearing with no extra work.
- Open findings F-02 to F-11, which belong to earlier features.

## Build loop

This runs under `/continuous`, which does not pause between steps. Each step
passes `flutter analyze` and `flutter test` before it is checked off.
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/shared-shopping-list`. The Continuous run then
makes the final feature commit and does the local squash merge.

## Build steps

- [x] **Step 1 - Entry model and matching rules** - add
  `lib/features/shopping_list/logic/shopping_entry.dart` (`ShoppingEntry`) and
  `lib/features/shopping_list/logic/shopping_match.dart`:
  `normalizeEntryText`, `validateEntryText`,
  `linkedItemId(text, items)` and
  `entriesClearedBy(entries, purchasedItems)`. *Done when:* unit tests cover
  normalization (case, surrounding and repeated whitespace), empty and
  whitespace-only text being refused, linking to exactly one item, no link when
  no item or several items match, clearing by linked id, clearing by name
  (including an item created on the purchase with an empty id), and
  non-matching entries being kept.
- [x] **Step 2 - Repository** - add `ShoppingListRepository`,
  `FirestoreShoppingListRepository` (`@LazySingleton`), and
  `shopping_entry_dto.dart`. Regenerate `injection.config.dart`, and pass the
  repository through `main.dart` and `app.dart` the way the other repositories
  are passed. Add `test/features/shopping_list/fake_shopping_list_repository.dart`.
  *Done when:* DTO tests cover the full write body and a defensive read of
  missing or wrongly typed fields; analyze and the whole suite pass.
- [x] **Step 3 - Shopping list cubit** - add `ShoppingListCubit` and
  `ShoppingListState` in `lib/features/shopping_list/presentation/`. The cubit
  watches entries and items, and has `add(text)`, `remove(entry)`, `retry()`, and
  a `close()` that cancels both subscriptions. *Done when:* cubit tests prove
  loaded, empty and failure states, retry resubscribing, `add` writing trimmed
  text with the right linked id, author and clock, `remove` deleting by id, a
  refused write being returned as a `DataFailure`, a thrown write being returned
  as `UnexpectedDataFailure` and reported through `addError`, an items stream
  failure not breaking the list, and both subscriptions cancelled on close.
- [x] **Step 4 - Home section** - add `ShoppingListSection` and provide the
  cubit from `HomePage`. *Done when:* widget tests prove each state renders, an
  empty add is refused with an inline error, a valid add clears the field and
  writes, ticking an entry removes it, a refused write shows its message, and
  retry resubscribes. The existing Home tests still pass. An Android emulator
  run (tier 3) shows an entry added on the device appearing in the list, and
  ticking removing it, with a clean log.
- [x] **Step 5 - Purchase clears matching entries** - `RecordPurchaseCubit`
  also watches the shopping list, without blocking readiness on it. On save it
  computes `entriesClearedBy` from the draft's line items and passes the ids to
  `PurchaseRepository.commit`, which deletes them in the purchase batch.
  *Done when:* cubit tests prove matching ids are passed, nothing is passed when
  nothing matches, the list not having reported yet passes an empty set, and a
  shopping list stream failure neither blocks nor fails the purchase screen.
  An Android emulator run (tier 3) shows an entry "milk" disappearing from Home
  after a purchase with a line for the item Milk is saved, with a clean log.

## Files / areas

- New: `lib/features/shopping_list/logic/shopping_entry.dart`,
  `lib/features/shopping_list/logic/shopping_match.dart`,
  `lib/features/shopping_list/data/shopping_list_repository.dart`,
  `lib/features/shopping_list/data/firestore_shopping_list_repository.dart`,
  `lib/features/shopping_list/data/shopping_entry_dto.dart`,
  `lib/features/shopping_list/presentation/shopping_list_cubit.dart`,
  `lib/features/shopping_list/presentation/shopping_list_state.dart`,
  `lib/features/shopping_list/presentation/shopping_list_section.dart`.
- Changed: `lib/main.dart`, `lib/app.dart`, `lib/core/di/injection.config.dart`
  (generated), `lib/features/home/presentation/home_page.dart`,
  `lib/features/purchases/data/purchase_repository.dart`,
  `lib/features/purchases/data/firestore_purchase_repository.dart`,
  `lib/features/purchases/presentation/record_purchase_cubit.dart`,
  `lib/features/purchases/presentation/record_purchase_page.dart`.
- Tests: mirrors of each new file under `test/features/shopping_list/`, plus
  updates to `home_page_test.dart`, `record_purchase_cubit_test.dart`,
  `record_purchase_page_test.dart` and `fake_purchase_repository.dart`.
- Not changed: `firestore.rules` already allows every authenticated read and
  write, which is the whole boundary the plan asks for. No index is needed,
  because one `orderBy` on a single field uses the automatic index.

## Data / contracts

**`shoppingList/{entryId}`**, the id generated by Firestore:

| Field | Type | Written as |
| --- | --- | --- |
| `text` | string | The typed text, trimmed. Never empty. |
| `itemId` | string or null | `linkedItemId(text, catalogue)` at add time |
| `addedByUserId` | string | The signed-in `AppUser.uid`, never typed |
| `addedAt` | timestamp | The client clock, so ordering holds offline |
| `done` | bool | Always `false` (see below) |

- **`done` is written but never read.** The user decided that ticking deletes
  the entry, which settles the overview's open question about the flag. It is
  still written as `false` so documents match the planned shape.
- **Reads are defensive**, like `purchaseFromFirestore`: a missing or wrongly
  typed field renders instead of breaking the list. An empty `itemId` reads as
  null, and an unreadable `addedAt` reads as the Unix epoch. Firestore's
  `orderBy` leaves out a document with no `addedAt` at all. Every write sets it,
  so that only affects a document written outside the app.
- **Order:** `orderBy('addedAt')`, oldest first, so the list reads in the order
  things were added.
- **Lifecycle:** entries are only created by `add` and only deleted by a tick
  or a purchase commit. Deleting an entry that is already gone is a no-op in
  Firestore, so two devices ticking the same entry, or a tick racing a
  purchase, are both harmless. Anything else follows last write wins, as the
  plan says.

**Matching (user decision, 2026-09-24).** `normalizeEntryText` trims, collapses
runs of whitespace to one space, and lowercases.

- `linkedItemId(text, items)`: the id of the one item whose normalized name
  equals the normalized text. Null when no item matches, or when several do,
  because a guessed link would be wrong half the time.
- `entriesClearedBy(entries, purchasedItems)`: the ids of entries where either
  `entry.itemId` is the non-empty id of a purchased item, or the entry's
  normalized text equals a purchased item's normalized name. A purchased item
  created on the purchase has an empty id, so it matches by name only.

**Clearing is atomic with the purchase.** `PurchaseRepository.commit` gains
`Set<String> clearEntryIds = const {}` and adds one `batch.delete` per id to the
batch that writes the purchase and the restock. It stays a batch, not a
transaction, so it still works offline. The ids come from the shopping list this
device last saw. An entry added on another device that has not synced yet is
not cleared, and stays until it is ticked. This is accepted: the failure mode is
an entry that stays on the list, never one that is lost by mistake.

**Purchase screen readiness is unchanged.** It still waits only for items and
members. If the shopping list has not reported yet, or its stream failed, the
purchase saves with no entries cleared. The failure is reported through
`addError` and is never shown on the purchase screen, because the purchase does
not depend on the list.

**Write outcomes.** `add` and `remove` return `Result<void, DataFailure>`.
Like the other screens, Home waits up to `refusalWindow` and then treats the
write as done, because offline the future only completes when the server
acknowledges it. A refusal inside the window shows its mapped message in a
`SnackBar`. The add field is cleared at once, and the entry appears through the
stream from the local cache.

**Display.** Heading "Shopping list". Add row: a `TextField` labelled
"Add to the list", submitting on the keyboard action and on an add `IconButton`
with the tooltip "Add". Empty text shows the inline error "Enter something to
buy", which clears on the next edit. Each row is a `ListTile` with a leading
`Checkbox` (semantic label `Got <text>`) and the entry text as plain `Text`,
up to 2 lines with an ellipsis. Only the checkbox removes the entry, not the
whole row, so a scroll tap does not delete anything. Empty state: "The list is
empty". Failure state: the mapped message and a Try again button.

## Testing

- Unit: `shopping_match_test.dart`, `shopping_entry_dto_test.dart`.
- Cubit: `shopping_list_cubit_test.dart`, `record_purchase_cubit_test.dart`
  (extended).
- Widget: `shopping_list_section_test.dart`, `home_page_test.dart` (Home now
  provides a third cubit and needs the fake repository),
  `record_purchase_page_test.dart` (providers only).

**Platform matrix.** Substantial UI and a data flow, but no plugin, permission
or native code, so one platform, per the project's verification policy. The add
field brings up the keyboard on Home, and keyboard insets are an escalation
trigger, so the Android run specifically checks that the field stays visible
while typing.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Added entry appears in the list | tier 3 | assumed | assumed |
| Ticking an entry removes it | tier 3 | assumed | assumed |
| Saving a purchase clears a matching entry | tier 3 | assumed | assumed |
| Keyboard does not hide the add field | tier 3 | assumed | assumed |

Live sync between two devices is Firestore's own snapshot behavior, and this
feature does not re-prove it. The single-device run proves the stream path.

## Notes for the AI

- `logic/` stays pure Dart. Pass `now` in, and never call `DateTime.now()`
  there.
- Follow `RunningLowCubit` for streams: `addError`, then a renderable failure
  state, and a new subscription on retry.
- No `DocumentSnapshot` leaves `data/`. Map errors with `dataFailureFromError`
  and `dataFailureFromCode`.
- Provide the repository above `MaterialApp`, as `app.dart` does for the
  others, so the pushed purchase route can read it.
- Regenerate DI with `dart run build_runner build --delete-conflicting-outputs`.
  Never hand-edit the generated file.
- No em dashes in code comments, commits or docs.

## Spec critique

Checked before building. Changes made:

- Settled matching and ticking with the user instead of guessing. The overview
  listed `done` as an open question.
- Made clearing part of the purchase batch, not a second write, so a saved
  purchase and a cleared list cannot land apart, and it works offline.
- Kept the purchase screen independent of the list stream, so a list failure
  cannot stop a spend from being recorded.
- Refused to link when several items share a name, instead of picking one.
- Only the checkbox deletes an entry, not the whole row, because a delete has
  no undo.
- Added the keyboard inset check, since the add field is the first text input
  on Home.

## Open questions

- None blocking.

## Verification record

Android emulator `Pixel_10` (API 37), debug build, tier 3, on the shared
Firebase project, 2026-09-24:

1. Step 4. Home on launch showed "Shopping list" below "Running low", with the
   add field and "The list is empty" from the real collection.
2. Step 4. Tapped the field and typed `Eggs`. With the keyboard up, the field
   stayed fully visible above it. Submitted with the keyboard action: the field
   cleared and `Eggs` appeared with a checkbox.
3. Step 4. Ticked `Eggs`. It disappeared, and the empty state returned.

4. Step 5, after a fresh install of the step 5 build. Added the entry `BH`.
   Recorded a purchase: shop `Test`, total 0,01 EUR, one line for the existing
   test item `bh` (1 kg, 0,01 EUR), paid by the signed-in member. On save the
   screen closed, and Home showed "The list is empty". The entry was cleared by
   a case-insensitive name match. The done-when named "milk" and Milk, but the
   test item `bh` was used instead so no new catalogue item was created.

This run wrote real data to the shared project: one purchase (`Test`,
0,01 EUR, dated 24/09/2026) and a 1 kg restock of `bh`. Neither can be undone
from the app, and both show in the September report.

Across the run the log showed no Flutter exception, overflow or error box. The
only errors were the known emulator `GoogleApiManager`, Phenotype and App Check
noise. iOS and Web: assumed.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":14394,"specSha256":"56ba372fb4ba8d09849b2fa1f5cfa3ad25b0356b89451cb4d0de85bf36a67592","branch":"refs/heads/feature/shared-shopping-list","head":"8550cdb6d85d315e423789471047ced0462a21e2","baseRef":"refs/heads/main","baseCommit":"7a30e16b64fa8c0fe1566905e87de41f8731fafd","sourceTree":"3528dd0a934074084c7ef40819673b41f781c2e5","absentOptional":[]} -->

## Independent review

**Status:** passed
**Target commit:** 8550cdb6d85d315e423789471047ced0462a21e2
**Base commit:** 7a30e16b64fa8c0fe1566905e87de41f8731fafd
**Base ref:** main
**Spec hash:** 56ba372fb4ba8d09849b2fa1f5cfa3ad25b0356b89451cb4d0de85bf36a67592
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-23T23:00:46Z
**Workflow:** continuous
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-23T23:04:30Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Handoff

Review the active spec and the complete `7a30e16b64fa8c0fe1566905e87de41f8731fafd..8550cdb6d85d315e423789471047ced0462a21e2` delta in a fresh
session or isolated subagent without the builder conversation. Run all Audit lenses from scratch.
Run Check when required above. Do not edit product code, accept findings, or
reuse the existing findings as the review scope.

## Commands

- `git rev-parse HEAD`: pass, equals Target commit 8550cdb6d85d315e423789471047ced0462a21e2
- `git merge-base main HEAD`: pass, equals Base commit 7a30e16b64fa8c0fe1566905e87de41f8731fafd
- `shasum -a 256 blueprint/context/current-feature.md`: pass, equals Spec hash
- `git status --porcelain`: pass, only blueprint/context/review.md modified
- `flutter analyze`: pass, no issues found
- `flutter test`: pass, 556 tests passed
- `/check`: not run, not required by the request

## Evidence

- Reviewed all 26 non-spec files in `7a30e16..8550cdb` (27 in the diff, spec read as the contract): shopping_list logic, data, presentation; Home wiring; purchase repository, cubit and page; main.dart, app.dart, generated DI; all new and changed tests.
- Quality: logic/ is pure Dart; no Firebase type leaves data/; streams follow the RunningLowCubit pattern (addError, renderable failure, resubscribe on retry); every subscription is cancelled in close(); the TextEditingController is disposed; list rows are keyed by entry id; analyze is clean.
- Security: firestore.rules allows any authenticated read and write, which the spec and overview name as the whole boundary; addedByUserId comes from the signed-in AppUser, never typed; batch-deleted ids come only from Firestore document ids and empty ids are filtered by entriesClearedBy; no secrets in the delta.
- Performance: one orderBy on a single field (automatic index); list rendered with SliverList.builder; clearing is folded into the existing purchase batch, not a second round trip; no unbounded work beyond the household-sized list.
- Tests: matching rules, DTO read/write, cubit states, write outcomes, retry, close, section states and interactions, and purchase clearing are covered with concrete assertions; no skipped or focused tests found. One gap recorded as F-12 (P3).
- Spec conformance: display strings, checkbox-only removal, refusal window, atomic batch clearing and non-blocking purchase readiness match the verified spec.

## Findings

- F-12 [P3] open - the purchase screen's shopping list failure report through addError is never asserted.
- No P0 or P1 finding is open or fixed. Existing F-02 to F-11 were not re-examined as a checklist and were left unchanged.

## Remaining risk

- `FirestoreShoppingListRepository` and the new `batch.delete` loop in `FirestorePurchaseRepository` have no automated test, consistent with the project having no Firestore fake; covered only by the builder's recorded Android tier-3 run, which this review did not re-run.
- iOS and Web behaviour is assumed, not verified, per the spec's platform matrix.
- No combined Verify command and no integration_test harness exist for this project.
- Home now opens a third watch on the items collection (via ShoppingListCubit); not profiled, expected to be negligible at household catalogue size.
