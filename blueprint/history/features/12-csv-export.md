# Feature: CSV export

**From build-plan:** feature 12
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/csv-export`

## Goal

Export a month of purchases as a CSV file and share it, from the Spending
screen. The file opens correctly by double-click in Excel on an Italian system,
with one row per thing bought.

## In scope

- An Export action on the Spending screen for the month on screen, enabled once
  that month has loaded and has at least one purchase.
- A pure CSV builder in `lib/features/reports/logic/`: one row per purchase
  line, in Italian Excel format (user decisions, 2026-09-24).
- Sharing the file through `share_plus`, which is already installed. Phones get
  the system share sheet, and web falls back to a download.
- Loading, success and failure feedback, with no silent failure.

## Out of scope

- Exporting a range of months, or a custom set of columns.
- Importing CSV.
- Receipt photos in the export.
- Open findings F-02 to F-14.

## Build loop

This runs under `/continuous`, which does not pause between steps. Each step
passes `flutter analyze` and `flutter test` before it is checked off.
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/csv-export`. The Continuous run then makes the
final feature commit and does the local squash merge.

## Build steps

- [x] **Step 1 - CSV builder** - `purchases_csv.dart` in
  `lib/features/reports/logic/`: `monthCsv(month, purchases, items, members)`
  returning the text, and `monthCsvFileName(month)`. *Done when:* unit tests
  cover the header, one row per line in date order, a purchase with no lines
  still getting a row, a deleted item and an unmatched line (item and
  category empty, receipt text kept), decimal commas, `dd/MM/yyyy`, quoting of
  `;`, `"` and line breaks, the formula guard, purchases outside the month
  being left out, and CRLF line endings.
- [x] **Step 2 - Share** - `CsvSharer` and `SharePlusCsvSharer` in
  `lib/features/reports/data/`: UTF-8 with a BOM, `text/csv`, the file name,
  and a result that separates shared, dismissed and failed. Register and
  provide it as the other services are. `ReportsCubit.exportMonth()` builds the
  CSV from what it already holds. *Done when:* unit tests cover the bytes
  starting with the BOM, the cubit exporting only the month on screen, refusing
  when not loaded, and mapping a sharer failure to a message reported through
  `addError`.
- [x] **Step 3 - Screen** - an Export `IconButton` (tooltip "Export CSV") in the
  Spending app bar, disabled while loading, on failure, or for a month with no
  purchases. It shows progress while sharing, and a SnackBar on failure.
  *Done when:* widget tests cover the enabled and disabled states, a tap
  exporting the month on screen, and a failure message.
- [x] **Step 4 - Device runs** - `share_plus` is a plugin, so each mobile
  platform is run. Android emulator: Export opens the share sheet with the file
  named `grocery-2026-09.csv`. iPhone (user driven): the share sheet opens and
  the file can be saved to Files. Web: assumed, or run if the user signs in.
  *Done when:* recorded in the Verification record with a clean log.

## Files / areas

- New: `lib/features/reports/logic/purchases_csv.dart`,
  `lib/features/reports/data/csv_sharer.dart`,
  `lib/features/reports/data/share_plus_csv_sharer.dart`.
- Changed: `lib/features/reports/presentation/reports_cubit.dart`,
  `lib/features/reports/presentation/reports_page.dart`, `lib/main.dart`,
  `lib/app.dart`, `lib/core/di/injection.config.dart` (generated).
- Tests: mirrors of the new files, extended reports cubit and page tests, and
  the Home and auth gate harnesses for the new provider.
- No dependency change: `share_plus` is already a direct dependency.

## Data / contracts

**File.** `grocery-YYYY-MM.csv`, UTF-8 with a byte order mark, `text/csv`, CRLF
line endings, `;` separators. Nothing is written to Firestore.

**Columns** (English headers, as the interface is English):

| Header | Value |
| --- | --- |
| Date | Purchase date, `dd/MM/yyyy` |
| Shop | Shop name |
| Paid by | The payer's display name, or the raw id when the member is gone |
| Purchase total | The receipt total, repeated on each of its lines |
| Receipt text | The line's `rawText` |
| Item | The catalogue item's name, empty when unmatched or deleted |
| Category | The item's category label, empty when there is no item |
| Quantity | As saved, decimal comma, no trailing zeros |
| Unit | The unit label |
| Line total | Decimal comma, two decimals |
| Source | `manual` or `scanned` |

- **Rows.** One per purchase line, purchases in date order and lines in their
  saved order. A purchase with no lines gets one row with the line columns
  empty, so its spend is never lost. Only purchases dated inside the month are
  exported.
- **Amounts.** `12,50`: two decimals and a decimal comma, with no currency
  sign and no thousands separator, so Excel reads them as numbers.
- **Quoting.** A field containing `;`, `"`, CR or LF is wrapped in `"`, with
  inner `"` doubled.
- **Formula guard.** A text field (shop, receipt text, item, category, payer)
  starting with `=`, `+`, `-` or `@` gets a leading `'`, so a spreadsheet shows
  it as text instead of running it. Receipt text comes from OCR and from
  members' typing, so this is real untrusted input.
- **Sharing outcome.** Shared, dismissed (not an error) or failed. A failure
  shows "Could not share the export. Try again" and reports the cause through
  `addError`.

## Testing

- Unit: `purchases_csv_test.dart`, `share_plus_csv_sharer_test.dart` (the byte
  encoding, through a seam).
- Cubit and widget: extended `reports_cubit_test.dart` and
  `reports_page_test.dart`.

**Platform matrix.**

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Export opens the share sheet with the file | pass (t3) | pass (t3, user) | assumed (download fallback) |
| File content and format | tier 1 | tier 1 | tier 1 |

## Notes for the AI

- `logic/` stays pure Dart. Format numbers there, without `intl`'s currency
  formatter, which adds `€` and a space.
- Do not block the report on the export: build it from what the cubit already
  holds.
- No em dashes in code comments, commits or docs.

## Spec critique

Checked before building. Changes made:

- Asked the user for the row shape and the spreadsheet format instead of
  guessing.
- Added the formula guard, because receipt text is OCR output and member input.
- Gave a purchase with no lines its own row, so no spend disappears from the
  export.
- Kept the payer's raw id when the member is gone, rather than a blank.
- Disabled Export for an empty month, rather than sharing a header-only file.

## Open questions

- None blocking.

## Verification record

Tier 3, 2026-09-24.

**Android emulator `Pixel_10` (API 37):** the emulator had shut down and was
relaunched. Spending opened on September 2026 with Export enabled. Tapping it
opened the system share sheet, "Sharing 1 file", `grocery-2026-09.csv`. The
file `share_plus` handed over (`cache/share_plus/grocery-2026-09.csv`) was
pulled with `run-as` and checked. It starts with the UTF-8 BOM `EF BB BF`, uses
CRLF line endings and `;` separators, and has a header plus 10 rows with
`dd/MM/yyyy` dates and decimal commas (`0,45`, `2,66`). Unmatched lines have
empty Item and Category columns, matched ones show `bh` and Bakery. Dismissing
the sheet left the screen as it was. The log was clean.

**iPhone (physical, iOS 26.5), user driven:** Export opened the share sheet
with `grocery-2026-09.csv` (user report). The run log showed no exception.

**Web:** assumed. It uses `share_plus`'s download fallback, which was not run.

**Observed, not caused by this feature:** on this Firebase project the payer
of every September purchase has no `users` document, so the report shows
"Unknown member" and the export falls back to the raw user id, as specified.
That comes from how feature 3 mirrors members, and is left as it is.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":8011,"specSha256":"fb51bf27b7197ed0170877da078f6c3a95378e1043581e81b91b76f539c64ad3","branch":"refs/heads/feature/csv-export","head":"0d588e141b33251447a6dae7b09b98696d742b33","baseRef":"refs/heads/main","baseCommit":"88242174ea992673d92d510b64415c68fa1ad55e","sourceTree":"f18db4fbb812985f949b4bd0a673e4cfedef9a2d","absentOptional":[]} -->
