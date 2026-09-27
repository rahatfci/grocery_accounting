# Findings

> **Generated file.** The findings ledger: review findings raised by `/audit`
> against the work in progress, each with a durable ID, severity (P0-P3), and
> status. `/implement` marks repaired findings `fixed`, a later `/audit` pass
> moves them to `closed`, and `/complete` refuses to merge while any P0 or P1
> finding is `open` or `fixed`, then archives resolved findings with the work
> and resets this file.

### F-01 [P3] open - Saved summary emits after the review screen may have closed

**File:** lib/features/purchases/presentation/record_purchase_cubit.dart:368
**Found:** 2026-09-27 by /audit (scope: current; lens: quality; independent review)
**Why it matters:** `commit()` awaits the receipt keep, the Firestore commit and,
on the web, the upload in `confirm` (up to the 30 s `_uploadTimeout`). The
review screen's close button stays active while saving. If the member closes it
in that time, the cubit is closed and `_showSaved` calls `emit` on it, which
throws `StateError`. The `catch` in `commit()` then reports a spurious error,
calls `discard` on a purchase that was committed, and returns `CommitFailed`. In
practice `discard` is a no-op at that point (web already removed the held bytes,
phone already renamed the file), so no data is lost. The result is a misleading
error report and an outcome that contradicts what happened.
**Suggested fix:** Return early from `_showSaved` when `isClosed` (keeping
`_saved = true`), the same guard `_emitReady` and `_followUpload` already use.
Optionally add a cubit test that closes the cubit before a delayed commit
completes.
**Resolution:**
