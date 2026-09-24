# Feature: On device receipt reading

**From build-plan:** feature 10
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/on-device-receipt-reading`

## Goal

When a receipt photo is attached on Android or iOS, read it on the device with
ML Kit and prefill Record a purchase: the total, the date and one line per
priced receipt row. The member reviews and corrects before saving. Nothing is
written without passing that screen.

## In scope

- A pure parser in `lib/features/receipts/logic/` that turns recognised text
  lines, with their positions, into a total, a date and scanned lines. It uses
  only the generic patterns the plan names. Tuning per chain is deferred until
  real receipts are available (user decision, 2026-09-24).
- A `ReceiptReader` in `data/` that wraps `google_mlkit_text_recognition` (the
  Latin model) on Android and iOS, and reads nothing on web.
- Unmatched lines on the review screen: a scanned line has its receipt wording
  and no catalogue item. It is visibly marked. Tapping it opens the line sheet
  to match it to an item or to create one, and it can be removed.
- Saving is allowed with unmatched lines. They record spend with
  `itemId: null` and restock nothing (user decision, 2026-09-24). A purchase
  with any scanned content is saved with `source: scanned`.
- Reading shows progress in the Receipt section, and a failed read leaves the
  form as it was with a short message.

## Out of scope

- The alias table and automatic matching (feature 11).
- Per-chain rules for In's, Conad or Lidl, shop name detection, and discount,
  deposit or VAT rows. These rows are skipped, not turned into lines.
- Re-reading after the photo is replaced on a draft that already has content.
- Web reading. ML Kit does not exist there, so web keeps manual entry.
- Open findings F-02 to F-14. F-14 (a refused purchase can leave an uploaded
  photo) still needs a user decision for web.

## Build loop

This runs under `/continuous`, which does not pause between steps. Each step
passes `flutter analyze` and `flutter test` before it is checked off.
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/on-device-receipt-reading`. The Continuous run
then makes the final feature commit and does the local squash merge.

## Build steps

- [x] **Step 1 - Receipt parser** - add `receipt_reading.dart` in
  `lib/features/receipts/logic/`: `OcrLine` (text and box), `ReceiptReading`
  (total, date, `ScannedLine` list) and `parseReceipt(lines, {today})`.
  *Done when:* unit tests cover rebuilding rows from lines split into a
  description column and a price column, the `TOTALE` row winning over a
  `SUBTOTALE` row, a date in `dd/MM/yyyy`, `dd-MM-yy` and `dd.MM.yyyy`, a
  future or impossible date being ignored, priced rows becoming lines, the
  `2 x 1,29` and `0,450 kg x 5,90` quantity rows attaching to the right line,
  payment, change, VAT and discount rows being skipped, and empty or
  unreadable input giving an empty reading.
- [x] **Step 2 - Unmatched lines in the draft** - `PurchaseDraftLine.item`
  becomes nullable and gains `scannedText`. `PurchaseDraft` gains `scanned`.
  `restockTargets`, `validateDraft` and `toPurchase` handle unmatched lines:
  they restock nothing, need no unit check, and save with `itemId: null` and
  `rawText` from the receipt. *Done when:* the existing draft, validation and
  purchase tests still pass, and new tests cover an unmatched line's purchase
  line, the restock skipping it, the commit being valid, a matched scanned line
  keeping its receipt wording as `rawText`, and `source` following `scanned`.
- [x] **Step 3 - Reader** - `ReceiptReader` and `MlKitReceiptReader` in
  `lib/features/receipts/data/`. The reader writes the photo to a temporary
  file, runs `TextRecognizer`, maps each `TextLine` to an `OcrLine`, and deletes
  the file. On web it returns an empty reading without touching the plugin.
  Register `TextRecognizer` in DI and provide the reader in `main.dart` and
  `app.dart`. Add a fake. *Done when:* unit tests cover the mapping through an
  injected recognise function, the temporary file being deleted on success and
  on failure, a plugin failure becoming a `ReceiptReadFailure`, and web
  returning an empty reading.
- [x] **Step 4 - Prefill and review** - after a pick, `RecordPurchaseCubit`
  reads the photo only when the draft is still fresh (no lines and no total).
  It prefills the total, the date (unless it is in the future) and the scanned
  lines, and sets `scanned`. The screen shows "Reading receipt" progress,
  unmatched rows with a visible "Not matched" mark, matching through the line
  sheet (which keeps the receipt wording), and a SnackBar when a read fails or
  finds nothing. *Done when:* cubit and widget tests cover a fresh draft being
  prefilled, a draft with content not being overwritten, a failed or empty
  read, matching an unmatched line, removing one, and saving with unmatched
  lines. The existing purchase tests still pass.
- [x] **Step 5 - Device runs** - ML Kit is a plugin, so each mobile platform
  is run. Android emulator: pick a generated test receipt image from the
  gallery and check the total, date and lines are prefilled, then match one
  line and save. iPhone (physical, user driven): photograph a real scontrino
  and record what was prefilled. *Done when:* both runs are recorded in the
  Verification record with a clean log, and the prefill results on the real
  receipt are written down as the input for later tuning.

## Files / areas

- New: `lib/features/receipts/logic/receipt_reading.dart`,
  `lib/features/receipts/data/receipt_reader.dart`,
  `lib/features/receipts/data/ml_kit_receipt_reader.dart`.
- Changed: `lib/core/di/injection.dart`, `injection.config.dart` (generated),
  `lib/main.dart`, `lib/app.dart`,
  `lib/features/purchases/logic/purchase_draft.dart`,
  `lib/features/purchases/logic/purchase_validation.dart`,
  `lib/features/purchases/presentation/record_purchase_cubit.dart`,
  `lib/features/purchases/presentation/record_purchase_state.dart`,
  `lib/features/purchases/presentation/record_purchase_page.dart`,
  `lib/features/purchases/presentation/purchase_line_sheet.dart`.
- Tests: mirrors under `test/features/receipts/`, and updates to the purchase,
  Home and auth gate tests for the new provider.
- No dependency changes: `google_mlkit_text_recognition` and `path_provider`
  are already direct dependencies.

## Data / contracts

**Purchase documents are unchanged in shape.** They use what the plan already
defines:

- `lines[].itemId` is null for an unmatched line.
- `lines[].rawText` is the receipt wording for any scanned line, matched or not,
  so a mis-mapping stays diagnosable. It is the item name for a line added by
  hand.
- `source` is `scanned` when the reading added a total, a date or any line,
  otherwise `manual`.
- `itemIds` already skips null ids, so the catalogue's delete check is
  unaffected.

**Parser rules (generic, to be tuned).**

- **Orientation.** When most lines are taller than they are wide, the photo
  was stored sideways. iOS stores an upright photo that way, with a rotation
  flag: ML Kit reads the words correctly but reports their boxes in the stored
  frame. The boxes are turned a quarter each way, both are parsed, and the
  reading with the higher score wins. The score is lines, plus 3 for a total,
  plus 2 for a date. This was found on the real iPhone run.
- **Rows.** Lines are grouped into rows when their vertical centres are within
  half the median line height. Rows are sorted top to bottom, and the text in a
  row left to right, joined with a space.
- **Money.** `-?\d{1,5}[.,]\d{2}` is a price, after joining a gap ML Kit
  sometimes reads after the decimal comma (`2, 58`). The last one in a row is that
  row's price, parsed with a decimal comma or point. `EUR`, `€` and a trailing
  `A`/`B`/`C` VAT letter are ignored.
- **Total.** The price on the first row whose text contains the word `TOTALE`
  and not `SUBTOTALE`, `SUB TOTALE` or `SUB-TOTALE`. With no such row, or when
  that row's price cannot be read, there is no total. A wrong total is worse
  than an empty one.
- **Date.** The first `dd/MM/yyyy`, `dd-MM-yy(yy)` or `dd.MM.yy(yy)` that is a
  real calendar date and not after `today`. Two digit years are 2000 plus the
  year.
- **Skipped rows.** Rows mentioning any of `TOTALE`, `SUBTOTALE`, `CONTANTI`,
  `RESTO`, `IVA`, `PAGAMENTO`, `CARTA`, `BANCOMAT`, `SCONTO`, `RESO`,
  `ARROTONDAMENTO`, `IMPORTO` or `ABBUONO`, or with a negative price, never
  become lines. Nor does anything from the total row down, even when its price
  was misread.
- **Lines.** Every other row whose text before the price has at least two
  letters becomes a line: `rawText` is that text, trimmed and without a
  trailing VAT rate column (`10%`, or `10x` as ML Kit often reads it),
  `quantity` is 1,
  `unit` is `pcs`, and `lineTotal` is the price.
- **Quantity rows.** `N x P` (`2 x 1,29`, `n.2 * 2,50`) and `Q kg x P`
  (`0,450 kg x 5,90`)
  set the quantity, and for kg the unit, of the next line below them. When no
  line follows, they set the line above. They never become lines themselves.

**Reading is best effort.** Anything the parser is unsure of is left empty for
the member. A reading never overwrites a total, a date or lines the member has
already entered. It runs once per fresh draft, not again when the photo is
replaced.

## Testing

- Unit: `receipt_reading_test.dart`, `ml_kit_receipt_reader_test.dart`,
  extended `purchase_draft_test.dart` and `purchase_validation_test.dart`.
- Cubit and widget: extended `record_purchase_cubit_test.dart` and
  `record_purchase_page_test.dart`.

**Platform matrix.**

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| A photo prefills total, date and lines | pass (t3) | pass (t3), total empty on the real receipt | skip (no ML Kit) |
| Unmatched lines are marked and can be matched | pass (t3) | assumed | assumed |
| Saving with unmatched lines records spend only | tier 1 | tier 1 | tier 1 |

## Notes for the AI

- `logic/` stays pure Dart. `OcrLine` holds plain numbers, not `dart:ui`
  `Rect`.
- `TextRecognizer` needs a file path for an encoded JPEG, which is why the
  reader writes a temporary file.
- Keep the existing `PurchaseLineSheet` flow. Matching is editing a line that
  starts with no item.
- No em dashes in code comments, commits or docs.

## Spec critique

Checked before building. Changes made:

- Asked the user what Save may do with unmatched lines, and whether to wait for
  real receipt samples, instead of guessing.
- Rebuilt rows from line positions, because ML Kit often reads the description
  and price columns of a receipt as separate blocks.
- Made reading never overwrite what the member typed, and run only on a fresh
  draft, so replacing a photo cannot duplicate lines.
- Kept the receipt wording as `rawText` even after matching, as the plan
  requires, so feature 11 can learn from it.
- Moved discounts, VAT and payment rows out of scope rather than guessing their
  meaning.

## Open questions

- None blocking. Parser accuracy on real receipts is unknown until tuned.

## Verification record

Tier 3, 2026-09-24.

**Android emulator `Pixel_10` (API 37), gallery pick of a generated receipt**
(rendered with headless Chrome: four products, a `2 x 1,29` row, a
`0,450 kg x 5,90` row, SUBTOTALE, TOTALE EURO 8,93, payment rows and a
`20/09/2026` date line):

1. First run: the date and total were right, but YOGURT BIANCO and PANE
   CASERECCIO were missing, and the empty Shop field was already flagged. A
   temporary debug print of ML Kit's lines showed two things. The description
   and price columns come back as separate lines, which row rebuilding already
   handled. Some prices come back as `2, 58`, with a gap after the comma, which
   it did not. Fixed, and that exact output is now a parser test. The flagged
   field came from setting the total field's text from code, which the form
   counted as the member typing. Fixed by giving the field a fresh controller.
2. Second run: date 20/09/2026, total 8,93, and all four lines unmatched and
   marked (YOGURT BIANCO 2 pcs, MELE GOLDEN 0.45 kg). "Lines 8,93 of 8,93"
   matched, and the Shop field was not flagged. Matched MELE GOLDEN to the
   test item `bh` through the line sheet, which kept the scanned quantity,
   unit and total. Removed two lines, set shop `Test` and total 0,01, and saved
   with one unmatched line (YOGURT BIANCO) and one matched line (`bh`, 0.45 kg).
   Back on Home, the log was clean.

**iPhone (physical, iOS 26.5), camera photo of a real restaurant receipt,
user driven:**

1. First run (user report): the total was wrong and lines were missing. A
   temporary debug print showed the cause. ML Kit reads the words correctly
   but returns their boxes in the photo's stored, sideways frame: the iOS
   picker keeps the pixels unrotated and records the rotation only in EXIF.
   Every line came back taller than wide, so rows were rebuilt across the
   receipt. The same output also showed `SUB-TOTALE` being taken as the total
   (the hyphen is a word boundary), a VAT-rate column (`10%`, read as `10x`)
   glued onto names, and `n.2 * 2,50` quantity rows. All four were fixed in the
   parser, with synthetic tests. The raw OCR text of the user's receipt was
   kept out of the repository.
2. Second run (user report): the lines were right, and the total was empty.
   ML Kit had misread the `TOTALE COMPLESSIVO` amount as `T0,00`, and the
   parser now leaves an unreadable total empty rather than taking the
   subtotal. There was no date in the recognised text. The run log was clean.

**Input for later tuning.** Real receipts need: a tolerant total (`T0,00` for
`70,00`), the date line (not recognised on this receipt), letter/digit
confusions in prices (`A0rto` for `Importo`), and restaurant layouts, where the
quantity row precedes its line. Chain-specific rules for In's, Conad and Lidl
are still untested, pending real receipts from those shops.

**Test data from these runs:** one more purchase (`Test`, 0,01 EUR,
20/09/2026, source `scanned`, lines YOGURT BIANCO unmatched 2,58 and `bh`
0.45 kg 2,66), which restocked `bh` by 0.45 kg. Its receipt photo is in the
Supabase bucket. The iPhone runs did not save.

Web: skip, since ML Kit does not exist there.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":14384,"specSha256":"15ce396f9e50327c866fb0f8de54359637373ab4a68b7423601f7993a1413e3a","branch":"refs/heads/feature/on-device-receipt-reading","head":"72855e597bc0cf94791df34d6924fe5551638a10","baseRef":"refs/heads/main","baseCommit":"8227d3d07b60bfad65932ae8f9ec7bc99d5fb1f1","sourceTree":"7be78e72a341ad3544a811c37eeb18266cfd644c","absentOptional":[]} -->
