# Feature: Large screen and web layout pass

**From build-plan:** feature 13
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/large-screen-and-web-layout-pass`

## Goal

Use the width on tablets and web, where spending and the pantry are reviewed
sitting down, instead of a phone column in the middle of the screen. The
catalogue becomes a table, and Home shows the shopping list beside what is
running low (user decision, 2026-09-24).

## In scope

- One shared breakpoint, 720 logical pixels, in `lib/core/`, reused by the
  Spending report, which already switches to two columns there.
- Catalogue at 720 and wider: a table with Name, Category, Stock, Daily use and
  Low below, one row per item, where tapping a row opens the item as the list
  does. Narrower: the current list, unchanged.
- Home at 720 and wider: two columns. Left: the account line, Capture receipt,
  Record a purchase and Running low. Right: the Shopping list. Narrower: the
  current single column, unchanged.
- The manual receipt path on web already exists (feature 9 uploads, feature 10
  leaves web to manual entry). This pass confirms it by test only, since the
  user chose not to run web.

## Out of scope

- Sorting or filtering the catalogue table. It keeps the list's order, by
  name.
- Changing the purchase form, which stays one centred column because it is a
  form.
- A web run (user decision, 2026-09-24): wide layouts are checked on the
  Android emulator in landscape instead, and web is recorded as assumed.
- Open findings F-02 to F-14.

## Build loop

This runs under `/continuous`, which does not pause between steps. Each step
passes `flutter analyze` and `flutter test` before it is checked off.
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/large-screen-and-web-layout-pass`. The Continuous
run then makes the final feature commit and does the local squash merge.

## Build steps

- [x] **Step 1 - Shared breakpoint and catalogue table** - add
  `lib/core/layout.dart` with `wideLayoutWidth`, and use it in the reports page.
  The catalogue uses a `LayoutBuilder`: at the breakpoint or wider it shows
  `_ItemTable`, with a header row and one tappable row per item, and below it
  the existing list. *Done when:* widget tests at 400 and 1000 logical pixels
  prove the list at phone width, and at wide width the table header, every
  column's value for an item, a long name ellipsised with no overflow, and a
  tap opening the item detail. The existing catalogue and reports tests still
  pass.
- [x] **Step 2 - Two-column Home** - `HomeView` uses a `LayoutBuilder`: at the
  breakpoint or wider, two scrolling columns inside a 1100 wide centred box;
  below it, the current single column. *Done when:* widget tests prove the
  shopping list beside running low at 1000 wide (the same top, larger left),
  the single column at 400, and the existing Home tests passing unchanged.
- [x] **Step 3 - Device run** - Android emulator locked to landscape (923dp
  wide): Home in two columns, and the catalogue as a table, with a row tap
  opening an item. Then back to portrait for a phone-width regression check.
  *Done when:* recorded in the Verification record with a clean log and no
  overflow stripes.

## Files / areas

- New: `lib/core/layout.dart`.
- Changed: `lib/features/items/presentation/item_list_page.dart`,
  `lib/features/home/presentation/home_page.dart`,
  `lib/features/reports/presentation/reports_page.dart`.
- Tests: extended `item_list_page_test.dart` and `home_page_test.dart`.

## Data / contracts

- None. No data, route or dependency changes.
- **Table columns.** Name (flex 3, one line with an ellipsis). Category (flex 2,
  the category label). Stock (current stock through `formatStock`, right
  aligned, in the error colour when below the threshold, matching Running
  low's rule). Daily use (`formatStock(dailyUsage)` plus `/day`, or a dash for
  a non-staple). Low below (`formatStock(lowThreshold)`).
- **Widths.** The table sits in a centred box at most 1100 wide. Home's columns
  do too, split evenly with a gap between them.

## Testing

- Widget: `item_list_page_test.dart` and `home_page_test.dart` at both widths.

**Platform matrix.** Substantial UI, so one platform.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Wide Home and catalogue table, landscape | pass (t3) | assumed | assumed (user skipped) |
| Phone width unchanged | pass (t3) | assumed | assumed |

## Notes for the AI

- Reuse `runningLow`'s rule for the stock colour, rather than a second
  comparison.
- Keep phone layouts byte-for-byte the same widgets, so the existing tests
  stay the regression net.
- No em dashes in code comments, commits or docs.

## Spec critique

Checked before building. Changes made:

- Asked the user which screens to change, and whether web could be run,
  instead of guessing.
- Reused the report's existing 720 breakpoint, so the whole app changes layout
  at one width.
- Left the purchase form alone: a form wider than 560 is harder to read, not
  easier.
- Kept phone widths untouched, so this pass cannot regress the phone, which is
  the main surface.

## Open questions

- None blocking.

## Verification record

Android emulator `Pixel_10` (API 37), debug build, tier 3, 2026-09-24.
Auto-rotate was turned off and the emulator locked to landscape (923dp wide)
for the run. The original setting (`accelerometer_rotation 1`,
`user_rotation 0`) was restored afterwards and read back.

1. Landscape Home: two columns. Left: the account line, Capture receipt,
   Record a purchase and the Running low heading. Right: Shopping list with
   its add field and empty state, level with the top of the left column.
2. Landscape catalogue: the table, with the header Name, Category, Stock,
   Daily use and Low below, and a row `bh`, Bakery, 5.9 kg, `-`, 0 kg. Tapping
   the row opened the `bh` detail screen.
3. Back in portrait, Home was the unchanged single column.
4. The log showed no Flutter exception, overflow or error box, and there were
   no overflow stripes on any screen.

iOS: assumed (same Dart, no plugin). Web: assumed (user decision, 2026-09-24).
Web's manual receipt path is unchanged since features 9 and 10, and is covered
by their tests.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":6280,"specSha256":"ca4a81fc32ff2db6bd8622cc171fbde49516f1d4c6a7b4ab091d109b3d34b757","branch":"refs/heads/feature/large-screen-and-web-layout-pass","head":"27482385b5bfa11006988a56ad51603c24c0f866","baseRef":"refs/heads/main","baseCommit":"965d7578dde6eb7f453471ff2c0ff9630be903ab","sourceTree":"e4d09b98d59cc78ddc8a49ce61e44f59f49cb220","absentOptional":[]} -->
