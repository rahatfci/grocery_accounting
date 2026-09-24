# Findings

> **Generated file.** The findings ledger: review findings raised by `/audit`
> against the work in progress, each with a durable ID, severity (P0-P3), and
> status. `/implement` marks repaired findings `fixed`, a later `/audit` pass
> moves them to `closed`, and `/complete` refuses to merge while any P0 or P1
> finding is `open` or `fixed`, then archives resolved findings with the work
> and resets this file.

### F-20 [P3] open - `Purchase.receiptImagePath` doc still says Firebase Storage

**File:** lib/features/purchases/logic/purchase.dart:66
**Found:** 2026-09-24 by /audit independent (scope: current; lens: quality)
**Why it matters:** The field doc reads "Firebase Storage path, filled in by
feature 9." Receipt photos go to Supabase Storage (`uploadReceiptToSupabase`,
lib/features/receipts/data/supabase_receipt_store.dart:29-68), and the path is
`receiptStoragePath(purchaseId)` in the Supabase `receipts` bucket, recorded at
commit on phones and linked after upload on web. This is the same stale wording
F-13 corrected in `ReceiptStore`, left in the model that carries the path. A
reader could look for the object in the Firebase bucket or reintroduce a Firebase
Storage dependency. Not a behaviour defect.
**Suggested fix:** Reword to say it is the object path in the Supabase Storage
receipts bucket (`receiptStoragePath`), null until the photo is stored or queued.
Comment only; no current requirement is lost.
**Resolution:**
