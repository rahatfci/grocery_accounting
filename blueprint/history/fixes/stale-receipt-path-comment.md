# Fix: Stale receipt path comment

**Type:** Fix
**Status:** verified
**Branch:** `fix/stale-receipt-path-comment`
**Fixes:** F-20

## The problem

The doc on `Purchase.receiptImagePath`
(`lib/features/purchases/logic/purchase.dart:66`) says "Firebase Storage path,
filled in by feature 9". Receipt photos go to Supabase Storage, and "feature 9"
is build history rather than a description of the field.

## The fix

Reword the comment to say where the photo is stored, when it is null, and when
the path is recorded on phones and on web. Comment only; no behaviour change.

## Build steps

### [x] Step 1 - Reword the comment

**Done when:** `flutter analyze` is clean and `flutter test` passes.

## Verify

- `flutter analyze` and `flutter test`.
- No runtime change. Every platform is `assumed`.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":798,"specSha256":"60e0f8884da9398c447b061af0087ae8697d3f8b0e689adcbe07d3940e287d9f","branch":"refs/heads/fix/stale-receipt-path-comment","head":"6e6dbce9de51d7bd8358022dfa9025a2c5e9bfde","baseRef":"refs/heads/main","baseCommit":"5c8d8c461622001e1271112c7896cc4008dca2c9","sourceTree":"805f1b0a0df623bce660a6c8db576dc028e8edc4","absentOptional":[]} -->

## Findings

### stale-receipt-path-comment/F-20 [P3] closed - `Purchase.receiptImagePath` doc still says Firebase Storage

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
**Resolution:** Fixed 2026-09-24 by /implement on `fix/stale-receipt-path-comment`: the doc now says Supabase Storage, null when there is no photo, recorded with the purchase on phones and only after upload on web. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent current (fresh subagent, 5c8d8c4..6e6dbce): re-examined lib/features/purchases/logic/purchase.dart:66-69. No Firebase Storage or "feature 9" wording remains in lib/ or test/. Each claim matches the code: the path is `receiptStoragePath(purchaseId)` uploaded to the Supabase receipts bucket (supabase_receipt_store.dart:29-68, 238-242); on phones `queuesOffline` is true and the cubit passes the path to the purchase commit while the photo is only kept/queued (record_purchase_cubit.dart:252-267, supabase_receipt_store.dart:138); on web the commit gets null and `setReceiptImagePath` runs only after `confirm` uploaded (record_purchase_cubit.dart:300-316); null when no photo was kept. Comment-only change, no new defect.

## Independent review

**Status:** passed
**Target commit:** 6e6dbce9de51d7bd8358022dfa9025a2c5e9bfde
**Base commit:** 5c8d8c461622001e1271112c7896cc4008dca2c9
**Base ref:** main
**Spec hash:** 60e0f8884da9398c447b061af0087ae8697d3f8b0e689adcbe07d3940e287d9f
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-24T15:10:18Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-24T15:11:43Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Handoff

Review the active spec and the complete `5c8d8c461622001e1271112c7896cc4008dca2c9..6e6dbce9de51d7bd8358022dfa9025a2c5e9bfde` delta in a fresh
session or isolated subagent without the builder conversation. Run all Audit lenses from scratch.
Run Check when required above. Do not edit product code, accept findings, or
reuse the existing findings as the review scope.

## Commands

- `git rev-parse HEAD`, `git merge-base main HEAD`, `shasum -a 256 blueprint/context/current-feature.md`, `git status --porcelain --untracked-files=all`: pass (HEAD, merge base and spec hash match the request; only review.md differed before this pass)
- `flutter analyze`: pass (No issues found)
- `flutter test`: pass (736 tests, all passed)

## Evidence

- Delta is three files: the spec, the F-20 ledger entry, and a doc-comment rewrite at lib/features/purchases/logic/purchase.dart:66-69. No executable code changed.
- Comment claims verified against record_purchase_cubit.dart:252-267 (path passed at commit only when kept and `queuesOffline`), record_purchase_cubit.dart:300-316 (web links the path only after `confirm` uploaded), supabase_receipt_store.dart:138 (`queuesOffline => !_isWeb`) and receipt.dart:22 / supabase_receipt_store.dart:238-242 (Supabase object path).
- No remaining "Firebase Storage" or "feature 9" wording in lib/ or test/. No em dashes in the new comment.
- Security, performance, tests lenses: no reachable change; comment-only delta needs no new test, and the existing suite passes.

## Findings

- F-20 [P3] closed (re-examined, repair confirmed). No new findings.

## Remaining risk

- Check not required; no device run. Every platform is assumed per the spec.
- Integration tests and a combined Verify command are unavailable in this project.
- Pre-existing, outside this delta: on phones the path is committed before `confirm`; if the queue rename in `confirm` fails, the purchase points at an object that will never upload (the member is told via `receiptSkipped`). The new comment's "may still be queued" wording is consistent with this.
