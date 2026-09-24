# Fix: Refused purchases leave uploaded receipt photos

**Type:** Fix
**Status:** verified
**Branch:** `fix/refused-purchases-leave-uploaded-receipt-photos`
**Fixes:** F-14

## The problem

A purchase that Firestore refuses can still leave its receipt photo in the
Supabase bucket. The publishable key cannot delete objects, so these orphans
are permanent.

- **Web:** `keep` uploads the photo before the purchase is committed, and
  `discard` does nothing there. Each retry after a refusal generates a new
  purchase id and uploads another copy.
- **Phones:** `keep` puts the file straight into the upload queue. A flush that
  is already running (from an earlier save, or Home resuming) can upload it
  before the commit is refused, and `discard` then removes only the local copy.

## The fix

Nothing uploads until its purchase has been accepted (user decision for web,
2026-09-24: upload after saving).

- **`ReceiptStore` gains `confirm(purchaseId)`**, called once the commit has
  succeeded or passed the refusal window, and `queuesOffline`.
- **Phones:** `keep` writes `{id}.img.new`, a name `flush` ignores. `confirm`
  renames it to `{id}.img`, which puts it in the queue. `discard` deletes the
  unconfirmed file. The purchase still records `receiptImagePath` at commit,
  as the queue guarantees the upload.
- **Web:** `keep` holds the bytes in memory and uploads nothing. `confirm`
  uploads them, and `discard` drops them. The purchase is committed without
  `receiptImagePath`. After a successful upload, the path is written to the
  purchase with the new `PurchaseRepository.setReceiptImagePath`, a
  single-field update. So web still never records a path it has not stored.
  When the upload or that update fails, the purchase stays saved without the
  photo, and the member sees "Saved without the photo".

It must not break anything:
- The offline phone queue: an offline commit that passes the refusal window is
  confirmed at once.
- The retry of queued photos.
- A purchase with no photo.
- Every existing receipt test.

**Accepted edge:** if the phone app is killed in the half second between
saving and confirming, the `.img.new` file is never uploaded, and that
purchase keeps a path with no object. That is rare, and it loses one photo.
It never leaks an orphan.

## Build steps

- [x] **Step 1 - Store: keep, confirm, discard** - the phone queue writes and
  ignores `.img.new` until it is confirmed. The web store holds the bytes until
  confirmed. *Done when:* store tests prove that a kept photo is not flushed
  before confirm and is flushed after, that discard removes an unconfirmed
  photo, that web uploads nothing on keep, uploads on confirm and returns the
  mapped failure, and that web discard drops the bytes.
- [x] **Step 2 - Commit order** - `RecordPurchaseCubit` keeps, commits,
  confirms, and on web sets the path after the upload.
  `FirestorePurchaseRepository.setReceiptImagePath` updates one field. *Done
  when:* cubit tests prove a refused commit confirms and uploads nothing on
  either platform, the phone path is written at commit and confirmed after,
  the web path is set only after a successful upload, and a failed web upload
  or path update reports "Saved without the photo". The existing purchase and
  receipt tests pass.
- [x] **Step 3 - Device check** - Android emulator: capture and save a
  purchase, then check the queue empties and the object exists. *Done when:*
  recorded with a clean log. Web is covered by tests only, since the user
  skips web runs.

## Verify

- `flutter analyze`, `flutter test`, `flutter build web`.
- Android: save a purchase with a photo, and the photo uploads.

## Verification record

2026-09-24.

- Store tests: a kept photo is not flushed until confirmed, including a flush
  already running while a second purchase keeps its photo and is refused.
  Discard drops an unconfirmed photo. Web keeps without uploading, uploads on
  confirm, and uploads nothing after a discard.
- Cubit tests on both platforms: a refused purchase confirms and uploads
  nothing. The phone path is written at commit and confirmed after. Web
  commits with no path, uploads, then links the path. A failed web upload, or a
  refused link, reports "Saved without the photo".
- `flutter analyze` clean, `flutter test` 719 passed, `flutter build web`
  passed.
- Android emulator `Pixel_10` (API 37), tier 3, after another cold boot:
  captured the generated receipt from the gallery. MELE GOLDEN arrived matched
  to `bh` through the learned alias. Removed all lines, set shop `Test` and
  total 0,01, and saved. At 0.3 s, during the commit, the queue held only
  `KaefFCVryHeFM8ms99Hf.img.new`. 8 s later the queue was empty, and the bucket
  answered `409 Duplicate` for `receipts/KaefFCVryHeFM8ms99Hf`. The log was
  clean.
- Web: covered by tests only (user decision, 2026-09-24).

**Test data from this run:** one more purchase (`Test`, 0,01 EUR, 20/09/2026,
no lines) with its receipt photo in the bucket.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":4985,"specSha256":"7dcd7db99342c27a1bcb712345e434288e405490d50738a007b9ce581648a193","branch":"refs/heads/fix/refused-purchases-leave-uploaded-receipt-photos","head":"655da07699c155e5735aac2d86edbdf29b1fce13","baseRef":"refs/heads/main","baseCommit":"e30d96f6ef13be0d0e795b64fbf1ba40dd73db99","sourceTree":"b01f3bbb2dce0fba697b32cbfd7a2a41d04132f7","absentOptional":[]} -->
