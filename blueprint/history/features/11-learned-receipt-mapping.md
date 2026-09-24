# Feature: Learned receipt mapping

**From build-plan:** feature 11
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/learned-receipt-mapping`

## Goal

A receipt line that a member matched to an item once resolves automatically
every time after. Saving a purchase learns an alias for each matched scanned
line, and reading a receipt applies the aliases, so the review screen arrives
with those lines already matched. Without this, scanning stays a chore.

## In scope

- The `aliases` collection with the planned fields, written in the purchase
  batch for every scanned line that is saved matched.
- Applying aliases to a reading: a line whose normalised wording has an alias
  for an item still in the catalogue arrives matched.
- The alias's default quantity and unit fill in only when the receipt did not
  print a quantity, as the plan intends. Quantities read off the receipt win.

## Out of scope

- A screen to list, edit or delete aliases. A wrong alias is corrected by
  matching the line differently on the next receipt, which overwrites it.
- Fuzzy matching. Only the exact normalised wording resolves.
- Per-shop aliases (see Data / contracts).
- Tuning the parser for particular chains.
- Open findings F-02 to F-14.

## Build loop

This runs under `/continuous`, which does not pause between steps. Each step
passes `flutter analyze` and `flutter test` before it is checked off.
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/learned-receipt-mapping`. The Continuous run then
makes the final feature commit and does the local squash merge.

## Build steps

- [x] **Step 1 - Alias rules** - add `ReceiptAlias`,
  `normalizeReceiptText` and `aliasDocumentId` in
  `lib/features/receipts/logic/receipt_alias.dart`, and `quantityRead` on
  `ScannedLine`. Add `learnedAliases(draft, resolveItemId)` and
  `lineFromReading(scanned, aliases, catalogue)` in
  `lib/features/purchases/logic/receipt_matching.dart`. *Done when:* unit tests
  cover normalisation, stable and distinct document ids, learning only from
  matched scanned lines (including an item created on the purchase), the last
  line winning when two share a wording, applying an alias, keeping a quantity
  the receipt printed, falling back to unmatched when the aliased item has been
  deleted or cannot be measured in the alias's unit, and `quantityRead` being
  set only by quantity rows.
- [x] **Step 2 - Storage** - add `alias_dto.dart`, `AliasRepository` and
  `FirestoreAliasRepository` (a watch of the whole collection) in
  `lib/features/receipts/data/`, and register and provide them as the other
  repositories are. `FirestorePurchaseRepository.commit` adds one `set` per
  learned alias to its batch. *Done when:* DTO tests cover the write body and a
  defensive read, and the whole suite passes.
- [x] **Step 3 - Apply on reading** - `RecordPurchaseCubit` watches aliases
  without blocking readiness, and builds prefilled lines through
  `lineFromReading`. *Done when:* cubit tests prove a known wording arrives
  matched, an unknown one arrives unmatched, an alias stream failure changes
  nothing and is reported, and the saved purchase leads to learned aliases.
- [x] **Step 4 - Device run** - Android emulator: read the generated test
  receipt, match one line, and save. Read the same receipt again, and the line
  arrives already matched. *Done when:* recorded in the Verification record
  with a clean log. iOS runs the same Dart with no new plugin, so it is
  assumed.

## Files / areas

- New: `lib/features/receipts/logic/receipt_alias.dart`,
  `lib/features/purchases/logic/receipt_matching.dart`,
  `lib/features/receipts/data/alias_dto.dart`,
  `lib/features/receipts/data/alias_repository.dart`,
  `lib/features/receipts/data/firestore_alias_repository.dart`.
- Changed: `lib/features/receipts/logic/receipt_reading.dart`,
  `lib/features/purchases/data/firestore_purchase_repository.dart`,
  `lib/features/purchases/presentation/record_purchase_cubit.dart`,
  `lib/features/purchases/presentation/record_purchase_page.dart`,
  `lib/main.dart`, `lib/app.dart`, `lib/core/di/injection.config.dart`
  (generated).
- Tests: mirrors of the new files, and updates to the purchase, Home and auth
  gate test harnesses for the new provider.
- No dependency or rules change: `firestore.rules` already covers every
  collection for signed-in members.

## Data / contracts

**`aliases/{aliasId}`**, the fields the plan names:

| Field | Type | Written as |
| --- | --- | --- |
| `rawTextNormalized` | string | `normalizeReceiptText(scannedText)` |
| `itemId` | string | The matched item's id, including one created on this purchase |
| `defaultQuantity` | double | The quantity the member saved on that line |
| `defaultUnit` | string | That line's unit key |
| `shopName` | string or null | The purchase's shop, trimmed, for diagnosis only |

- **Normalisation.** Upper case, runs of whitespace collapsed to one space,
  trimmed. Nothing else, so two lines that print differently stay distinct.
- **Document id.** `aliasDocumentId` is the unpadded base64url of the UTF-8
  normalised text. It is deterministic, so learning the same wording again
  overwrites the alias rather than adding a second one. It also never contains
  a `/`.
- **Household-wide, not per shop.** Reading happens as the photo is attached,
  usually before a shop is typed, so a per-shop lookup could rarely apply. The
  shop is stored only so a surprising mapping can be traced. This is recorded
  as a deliberate, reversible choice.
- **Learning.** At save, every line with `scannedText` and an item becomes an
  alias in the purchase batch, so the purchase and what it teaches cannot land
  apart, offline too. When two lines share a wording, the later one wins.
  Unmatched lines teach nothing.
- **Applying.** When a reading prefills lines, a line whose normalised text
  has an alias arrives matched to that item, but only while the item is still
  in the catalogue and the alias's unit can be converted into the item's unit.
  Otherwise the line arrives unmatched, as before. Quantity comes from the
  receipt when it printed one (`quantityRead`), and from the alias otherwise.
  The line keeps `scannedText`, so it teaches again on save.
- **Failures.** The purchase screen never waits on aliases. If the watch fails,
  the failure is reported through `addError`, readings apply no aliases, and
  saving still learns.

## Testing

- Unit: `receipt_alias_test.dart`, `receipt_matching_test.dart`,
  `alias_dto_test.dart`, and extended `receipt_reading_test.dart`.
- Cubit: extended `record_purchase_cubit_test.dart`.

**Platform matrix.**

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| A matched line is learned and applied next time | pass (t3) | assumed | skip (no reading) |

## Notes for the AI

- `logic/` stays pure Dart. `base64Url` and `utf8` come from `dart:convert`.
- The purchase repository writes aliases directly, as it already writes the
  shopping list deletions, so everything stays in one batch.
- No em dashes in code comments, commits or docs.

## Spec critique

Checked before building. Changes made:

- Wrote aliases inside the purchase batch, not afterwards, so learning is
  atomic and works offline.
- Chose a deterministic id, so relearning overwrites and no duplicate aliases
  can pile up.
- Made aliases household-wide, because at read time the shop is usually
  unknown.
- Ignored an alias whose item was deleted or whose unit no longer converts, so
  a stale alias degrades to an unmatched line, never a wrong restock.
- Let a receipt's printed quantity beat the alias's default.

## Open questions

- None blocking.

## Verification record

Android emulator `Pixel_10` (API 37), debug build, tier 3, 2026-09-24. The
emulator was cold-booted after the host disk was freed, and the generated test
receipt was pushed to its gallery again.

1. First read of the test receipt: all four lines arrived unmatched. Nothing
   had been learned; feature 10's earlier match of MELE GOLDEN predates
   aliases.
2. Matched MELE GOLDEN to the test item `bh` (0.45 kg). Removed LATTE and PANE,
   set shop `Test` and total 0,01, and saved with YOGURT BIANCO unmatched and
   `bh` matched. Back on Home.
3. Second read of the same receipt: MELE GOLDEN arrived already matched as
   `bh`, 0.45 kg (the receipt printed that weight, so it came from the
   receipt), with no Not matched mark. LATTE, YOGURT and PANE stayed unmatched.
   Left without saving.
4. The run log showed no Flutter exception, overflow or error box.

**Test data from this run:** one purchase (`Test`, 0,01 EUR, 20/09/2026,
source `scanned`, YOGURT BIANCO unmatched 2,58 and `bh` 0.45 kg 2,66) that
restocked `bh` by 0.45 kg, and one alias, `MELE GOLDEN` to `bh`, 0.45 kg,
shop `Test`. Its receipt photo is in the Supabase bucket.

iOS: assumed. The same Dart runs there, with no new plugin or permission.
Web: skip, because web never reads receipts.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":8994,"specSha256":"6cd19f7a4d4f68e48977475f14b9e9530a24e0213ff6d1ad598e21c92cdc306b","branch":"refs/heads/feature/learned-receipt-mapping","head":"cb5cc2f997fca7853320540a21fd9ea6364ca4b7","baseRef":"refs/heads/main","baseCommit":"a1e3348904a78f7e2d177e6db17c2988b1c4847e","sourceTree":"5a7600fc1de267522fe1f1ad2d51f529972a59b8","absentOptional":[]} -->
