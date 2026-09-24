# Feature: Receipt capture

**From build-plan:** feature 9
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/receipt-capture`

## Goal

Photograph the scontrino, or pick it from the gallery, attach it to the
purchase being recorded, and keep it in the household's Supabase Storage bucket
(user decision, 2026-09-24, after Firebase Storage turned out to need the Blaze
plan). On a
phone the photo is kept on the device first and uploads whenever there is a
connection, so capturing in a shop with no signal loses nothing.

## In scope

- A capture button on Home, the largest action on the screen as the plan
  requires. It offers Take photo or Choose from gallery (user decision,
  2026-09-24), then opens Record a purchase with the photo attached.
- Record a purchase shows the attached photo, can replace or remove it, and can
  attach one to a purchase started by hand.
- Saving writes `receiptImagePath` on the purchase and stores the image at that
  Storage path.
- Phones (Android, iOS): the image is written to a durable local queue before
  the purchase is committed, and uploaded after. Home retries the queue when it
  opens and when the app resumes.
- Web: the image uploads straight away while saving, with no queue (user
  decision, 2026-09-24). If the upload fails, the purchase is saved without the
  photo, and the member is told.
- `path_provider` and `http` as direct dependencies, and `firebase_storage`
  removed (the user approved `path_provider` and chose Supabase, 2026-09-24),
  plus the iOS camera and photo library usage descriptions.

## Out of scope

- Reading the receipt (feature 10). `source` stays `manual` because a photo on
  its own prefills nothing.
- Attaching a photo to a purchase that is already saved, or viewing a stored
  photo afterwards. There is no purchase detail screen (user decision,
  2026-09-24).
- Deleting a stored photo. Nothing deletes purchases either.
- Android's `retrieveLostData` recovery, for when the OS kills the app while
  the camera is open. The member takes the photo again.
- Showing upload progress or the queue length.
- Open findings F-02 to F-12.

## Build loop

This runs under `/continuous`, which does not pause between steps. Each step
passes `flutter analyze` and `flutter test` before it is checked off.
`workflow.checkpointCommits` is `enabled`, so each passing step gets a
checkpoint commit on `feature/receipt-capture`. The Continuous run then makes
the final feature commit and does the local squash merge.

## Build steps

- [x] **Step 1 - Dependency, permissions, receipt rules** - add
  `path_provider: ^2.1.6` (the version already locked as a transitive
  dependency) and run `flutter pub get`. Add `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist`. Add
  `lib/features/receipts/logic/receipt.dart`: `receiptStoragePath(purchaseId)`,
  `purchaseIdFromPendingName(fileName)`, `receiptContentType(bytes)` and the
  `ReceiptPhoto` holder. *Done when:* unit tests cover the path shape, the
  pending name round trip (including rejecting foreign and hidden file names),
  and JPEG, PNG, HEIC and unknown content types. `pubspec.lock` changes only
  `path_provider` from transitive to direct.
- [x] **Step 2 - Picker and store** - add `ReceiptPicker` and
  `ImagePickerReceiptPicker` (the `image_picker` wrapper), and `ReceiptStore`
  and `SupabaseReceiptStore` (the phone queue and the web upload) in
  `lib/features/receipts/data/`, with `SupabaseConfig` in `lib/core/`. Register
  `http.Client` and `ImagePicker` in the DI modules, regenerate DI, and pass both through `main.dart` and
  `app.dart`. Add test fakes. *Done when:* unit tests cover the picker's
  mapping of a picked file, a cancel, a denied permission and any other
  failure, and the store's queue against a temporary directory with an injected
  uploader: keep writes the file, upload removes it on success and keeps it on
  failure, discard removes it, a second flush while one is running does
  nothing, and web mode uploads directly and never touches the disk.
- [x] **Step 3 - Draft and commit** - `PurchaseDraft` carries an optional
  `ReceiptPhoto`. `RecordPurchaseCubit` gains `attachReceipt` and
  `removeReceipt`, and its commit keeps the photo, commits with the path,
  discards the photo on a refusal, and starts the upload on success. The
  refusal window moves from the page into the cubit, so it covers the Firestore
  commit only. `PurchaseRepository` gains `newPurchaseId()`, and `commit` takes
  `purchaseId` and `receiptImagePath`. *Done when:* cubit tests cover a
  purchase with no photo (unchanged behaviour), a kept photo committed with
  its path and then uploaded, a failed keep saving without the photo and
  reporting it, a refused commit discarding the photo, a pending commit
  resolving as success after the window, and attach, replace and remove. The
  existing purchase tests still pass.
- [x] **Step 4 - Screens** - Record a purchase gets a Receipt section: an
  attach button that offers camera or gallery, a thumbnail once attached, and
  replace and remove actions. Home gets the capture button as its largest
  action, with Record a purchase kept as a secondary action, plus a
  `ReceiptUploadsCubit` that flushes the queue on open and on resume.
  Constructing `RecordPurchasePage` with a starting source picks from it as
  the screen opens, so every pick, including capture from Home, goes through
  `RecordPurchaseCubit` and an unexpected picker error is reported through
  `addError`. A cancelled or failed pick that was the capture itself returns
  to Home. *Done when:*
  widget tests cover capture opening the review screen with the photo, a
  cancelled pick doing nothing, a denied pick showing its message, attach,
  replace and remove on the review screen, the saved-without-photo message,
  and the queue flushing on Home open and on resume. The existing Home and
  purchase tests still pass.
- [x] **Step 5 - Device runs** - plugin, permission and native behaviour, so
  each platform is run on its own. Android emulator: gallery and camera
  capture, save online, and the object appearing at `receiptImagePath`. Airplane
  mode, save, relaunch online, and the queued photo uploading. iPhone (physical,
  since ML Kit rules out the simulator): the camera permission prompt, capture,
  and save. Chrome: gallery pick and save, with the object uploaded.
  *Done when:* each run is recorded in the Verification record with a clean
  log, and any platform that could not run is marked unverifiable.

## Files / areas

- New: `lib/features/receipts/logic/receipt.dart`,
  `lib/features/receipts/data/receipt_picker.dart`,
  `lib/features/receipts/data/image_picker_receipt_picker.dart`,
  `lib/features/receipts/data/receipt_store.dart`,
  `lib/features/receipts/data/supabase_receipt_store.dart`,
  `lib/core/supabase_config.dart`,
  `lib/features/receipts/presentation/receipt_uploads_cubit.dart`,
  `lib/features/receipts/presentation/receipt_source_sheet.dart`.
- Changed: `pubspec.yaml`, `pubspec.lock`, `ios/Runner/Info.plist`,
  `lib/core/di/injection.dart`, `lib/core/di/injection.config.dart`
  (generated), `lib/main.dart`, `lib/app.dart`,
  `lib/features/home/presentation/home_page.dart`,
  `lib/features/purchases/logic/purchase_draft.dart`,
  `lib/features/purchases/data/purchase_repository.dart`,
  `lib/features/purchases/data/firestore_purchase_repository.dart`,
  `lib/features/purchases/presentation/record_purchase_cubit.dart`,
  `lib/features/purchases/presentation/record_purchase_state.dart`,
  `lib/features/purchases/presentation/record_purchase_page.dart`.
- Tests: mirrors under `test/features/receipts/`, fakes for the picker and
  store, and updates to the purchase, Home and auth gate tests.
- Also changed: `blueprint/project-plan.md` and the overview, recording the
  switch to Supabase and the accepted weaker boundary, and `AGENTS.md`'s
  plugin note.
- Not changed: `storage.rules` and `firebase.json` still describe Firebase
  Storage, which is now unused. They are left alone rather than deleted, because
  deleting deployed config is outside this feature. Android needs no manifest
  change, because `image_picker` launches the system camera through an intent.

## Data / contracts

**Storage object.** `receipts/{purchaseId}` in the Supabase bucket
`Grocery Accounting` of project `rqxqpvlejismjmxgakcj`, where `purchaseId` is
the Firestore id of the purchase document. It is generated on the client by
`newPurchaseId()` before anything is written. It has no extension. The
`Content-Type` comes from `receiptContentType`: `image/jpeg`, `image/png` or
`image/heic`, sniffed from the leading bytes, otherwise
`application/octet-stream`.

**Upload.** `POST {url}/storage/v1/object/Grocery%20Accounting/receipts/{id}`,
with the publishable key as both `apikey` and `Authorization: Bearer`, the raw
bytes as the body, and no `x-upsert`. It never overwrites. One purchase has one
photo, so an object already there (409, or a 400 naming `Duplicate`) is the
same photo from an attempt whose reply was lost, and it counts as stored. That
makes the queue safe to repeat without an update policy on the bucket. Other
results: 2xx is stored, 401 or 403 is `PermissionDenied`. Storage sends some
refusals as HTTP 400 with the real status in a JSON `statusCode` field. A
missing bucket policy arrives that way as `403`, so a 400 is read from its body
first, and a client
exception, socket error or 30 second timeout is `ConnectionUnavailable`.
Anything else is `UnexpectedDataFailure`.

**Security (user decision, 2026-09-24).** The publishable key ships in the app
and the web build. The bucket's storage policies decide what it may do. The user
adds an insert policy for the bucket. Anyone holding the key could upload
there too. This is recorded in the plan as an accepted exception to "signed in
or nothing". The secret key is never used.

**`purchases.receiptImagePath`** holds that Storage path, or null. It is written
by the same commit as the rest of the purchase, and never changed after.

- Phones write the path at commit. The object may arrive later, because the
  queue uploads it.
- Web writes the path only when the upload has already succeeded. Otherwise it
  writes null, so web never records a path it has not stored.

**Image size.** `image_picker` with `maxWidth: 2000` and `imageQuality: 85`.
Feature 10 needs text that is still legible, and a phone photo would otherwise
be several MB. On iOS this also converts HEIC to JPEG.

**The phone queue.** Files live in
`getApplicationSupportDirectory()/pending_receipts/`, named `{purchaseId}.img`.
The name alone recovers the path. A hidden or foreign name is ignored, never
uploaded.

- `keep` writes the file before the commit starts. It is durable across
  restarts, and it is not in the user-visible documents folder.
- `flush` reads each pending file and uploads it with `putData` and the
  sniffed content type, the same call web uses, so one upload seam covers both.
  A receipt is about 500 KB, so reading it into memory costs nothing that
  matters. It deletes each file only after its upload succeeds, and leaves it for
  the next flush when the upload fails. Only one flush runs at a time.
- `discard` deletes the file when the commit is refused, so a refused purchase
  never uploads a photo.
- Flush triggers: after a successful commit, when Home opens (signed in, so the
  Storage rules pass), and when the app resumes.
- Each upload times out after 30 seconds. The queue retries on the next
  trigger, and on web the timeout bounds how long saving waits.

**Commit order.** Keep the photo, then commit the purchase with the path, then
start a flush. A failed keep (a disk error on a phone, or a failed upload on
web) commits the purchase without the photo, and the outcome says so. A refused
commit discards the photo. Offline, the Firestore future never completes. The
cubit treats a commit still pending after `refusalWindow` as succeeded, as the
page used to, and the queue picks the photo up later.

**Outcome.** `CommitSucceeded` gains `receiptSkipped` (a `DataFailure?`). When it
is set, the page pops and Home shows the SnackBar "Saved without the photo."
followed by the failure message.

**Picker errors.** `ReceiptPicker.pick(source)` returns
`Result<ReceiptPhoto?, ReceiptPickFailure>`. Null means the member cancelled.
`PlatformException` codes `camera_access_denied` and `photo_access_denied` map
to "Camera or photo access is off. Allow it in Settings to add receipts". Any
other exception maps to "Could not open the camera or gallery", and it is
reported through `addError` by the cubit that asked.

## Testing

- Unit: `receipt_test.dart`, `image_picker_receipt_picker_test.dart` (with a
  fake `ImagePicker` subclass), and `firebase_receipt_store_test.dart`. The
  store takes the directory and the upload function as constructor seams, so
  the queue is tested against a real temporary directory without Firebase.
- Cubit: `record_purchase_cubit_test.dart` extended,
  `receipt_uploads_cubit_test.dart`.
- Widget: `record_purchase_page_test.dart` extended, `home_page_test.dart`
  extended.

**Platform matrix.** Plugins, a permission and native storage are involved, so
each platform is run on its own, per the project's verification policy.

| Done-when | Android | iOS | Web |
| --- | --- | --- | --- |
| Gallery pick attaches and saves | pass (t3) | assumed | unverifiable |
| Camera capture attaches and saves | pass (t3) | pass (t3) | skip (file input) |
| Object stored at `receiptImagePath` | pass (t3) | pass (t3) | unverifiable |
| Offline save uploads later | pass (t3) | assumed | skip (no queue) |
| Camera permission prompt | assumed | pass (t3) | skip |

## Notes for the AI

- `logic/` stays pure Dart. Content type sniffing and path rules live there.
- No HTTP, `PlatformException` or `XFile` type leaves `data/`.
- `dart:io` is only used in the phone branch of `SupabaseReceiptStore`, behind
  `kIsWeb`. Web must compile, so check `flutter build web`.
- Provide the store and picker above `MaterialApp`, as the other repositories
  are.
- `ReceiptPhoto` holds the bytes but is not `Equatable`. Draft equality compares
  it by identity, so a keystroke never compares megabytes of bytes.
- Regenerate DI with `dart run build_runner build --delete-conflicting-outputs`.
- No em dashes in code comments, commits or docs.

## Spec critique

Checked before building. Changes made:

- Asked the user for the photo source, the attach point and web behaviour
  instead of guessing.
- Web records a path only after a successful upload, so a purchase never points
  at an object that was never stored.
- A refused commit discards the queued photo, so no orphan upload follows a
  purchase that does not exist.
- Bounded the upload retry time, so web saving cannot hang for 10 minutes and
  an offline phone upload fails fast, leaving the queue to retry.
- Moved the refusal window into the cubit, because it has to cover the
  Firestore commit only and not the web upload before it.
- Used a pending name that encodes the purchase id, so the queue needs no
  second index that could drift from the files.

## Open questions

- None blocking.

## Verification record

### First attempt, against Firebase Storage (superseded)

Android emulator `Pixel_10` (API 37), debug build, tier 3, 2026-09-24.

1. Home showed Capture receipt as the largest action, with Record a purchase
   below it as a secondary button.
2. Capture opened the Take photo / Choose from gallery sheet. Choose from
   gallery opened the system photo picker over the review screen. Picking the
   test image returned to Record a purchase with the thumbnail, Replace and
   Remove.
3. Saved shop `Test`, total 0,01 EUR, no lines. The screen closed. One second
   later `files/pending_receipts/1eJuDOY4nk152tXp9ERb.img` (74,617 bytes) was
   in the queue.
4. The upload failed. Storage returned `404 Object does not exist at location`
   and "The server has terminated the upload session" (`StorageException`,
   code -13010). The file stayed queued, as designed.

**Resolved by switching to Supabase (user decision, 2026-09-24).** The rest
of this entry records the original failure.

**Cause, established from outside the app.** An unauthenticated read of
`https://firebasestorage.googleapis.com/v0/b/grocery-accounting-993ed.firebasestorage.app/o`
returns `404 Not Found.`, which is the same response as for an invented bucket
name. An existing bucket would refuse the unauthenticated read instead. So
Cloud Storage has not been provisioned for this Firebase project, and the Storage
rules have nowhere to apply. Provisioning it is a Firebase console action and,
for new projects, generally requires the Blaze plan. `project-plan.md` section
8 assumes Spark with no payment method. This needs the user's decision.

**Data written by this run:** one purchase (`Test`, 0,01 EUR, 24/09/2026,
`receiptImagePath` `receipts/1eJuDOY4nk152tXp9ERb`) whose object does not
exist yet. Its photo is still queued on the emulator and will upload on the
next Home open or resume once Storage exists.

Camera capture, the offline run, iOS and Web: not run.

### Final runs, against Supabase Storage

Tier 3 throughout, 2026-09-24. Upload results were confirmed from outside the
app. Repeating the same object path with the publishable key returns `409
Duplicate` once an object exists, and it never overwrites, because the app and
the probe both omit upsert.

**Android emulator `Pixel_10` (API 37):**

1. Before the bucket policy existed, the upload was refused with HTTP 400 and
   `statusCode 403`, "new row violates row-level security policy". The photo
   stayed queued. This led to the fix that reads Storage refusals from the
   body.
2. After the user added the insert policy, a relaunch drained the photo queued
   since the first attempt (`1eJuDOY4nk152tXp9ERb`) when Home opened. The
   bucket then answered `Duplicate` for `receipts/1eJuDOY4nk152tXp9ERb`.
3. Offline camera: with airplane mode on, Capture receipt, Take photo, the
   emulator camera shutter and accept all worked, and the thumbnail was shown.
   Saving `Test`, 0,01 EUR closed the screen at once, and
   `stMSolsyjXjxka49QTcZ.img` (29,200 bytes) was queued.
4. Force-stopped the app, turned airplane mode off, and cold-started it. After
   15 seconds the queue was empty, and the bucket answered `Duplicate` for
   `receipts/stMSolsyjXjxka49QTcZ`.
5. The device log showed no Flutter exception, overflow or crash.

**iPhone (physical, iOS 26.5, wireless):** the user drove the app while I
watched the log and the app container.

1. Capture receipt, then Take photo showed the camera permission prompt with
   the `NSCameraUsageDescription` text. The user allowed it, took a photo, and
   the thumbnail appeared (user report).
2. Saving `Test`, 0,01 EUR returned to Home (user report).
3. `xcrun devicectl device info files` showed
   `Library/Application Support/pending_receipts` created at save time (01:57)
   and empty afterwards. The queue deletes a file only after Storage accepts it,
   so the photo was stored. The purchase id was not visible from here, so no
   `Duplicate` check was possible for this one.
4. The run log showed no exception.

**Web:** not run (user decision, 2026-09-24): unverifiable. It shares
`uploadReceiptToSupabase` with the phones, which is covered by unit tests and
by the Android and iOS runs. The web-only branch (upload before commit, save
without the photo on failure) is covered only by tests. `flutter build web`
passes.

**Test data from these runs:** three more purchases (`Test`, 0,01 EUR,
24/09/2026) with receipt photos: two from the emulator and one from the iPhone.
Their objects are in the `Grocery Accounting` bucket under `receipts/`.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":19799,"specSha256":"0eb58082174f0ac811d7ccb0911da9b5888bcd15a2a4c2b0e1b2621d8d64fc0a","branch":"refs/heads/feature/receipt-capture","head":"46d93891a81ac6ec9d02ee38d99b5bf6bd5d5f59","baseRef":"refs/heads/main","baseCommit":"0cf74fb046835498669d97474b19baaa2b7d2584","sourceTree":"b0e9e5ca540911af2dde55b3a848b32b5b6d0b36","absentOptional":[]} -->

## Independent review

**Status:** passed
**Target commit:** 46d93891a81ac6ec9d02ee38d99b5bf6bd5d5f59
**Base commit:** 0cf74fb046835498669d97474b19baaa2b7d2584
**Base ref:** main
**Spec hash:** 0eb58082174f0ac811d7ccb0911da9b5888bcd15a2a4c2b0e1b2621d8d64fc0a
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-23T23:59:11Z
**Workflow:** continuous
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-24T00:01:39Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Handoff

Review the active spec and the complete `0cf74fb046835498669d97474b19baaa2b7d2584..46d93891a81ac6ec9d02ee38d99b5bf6bd5d5f59` delta in a fresh
session or isolated subagent without the builder conversation. Run all Audit lenses from scratch.
Run Check when required above. Do not edit product code, accept findings, or
reuse the existing findings as the review scope.

## Commands

- `git rev-parse HEAD`: pass (equals Target commit)
- `git merge-base main HEAD`: pass (equals Base commit)
- `shasum -a 256 blueprint/context/current-feature.md`: pass (equals Spec hash)
- `git status --porcelain`: pass (only blueprint/context/review.md modified)
- `flutter analyze`: pass (No issues found)
- `flutter test`: pass (614 tests, all passed)

## Evidence

- Reviewed all 37 changed paths in `0cf74fb..46d9389`: receipts logic, picker, Supabase store and upload, record purchase cubit/state/page, Home capture and upload cubit, DI, app/main wiring, Info.plist, pubspec, and every added or changed test.
- Upload builds the URL from path segments (bucket name encoded), sends no `x-upsert`, maps 2xx and 409 (including a 400 body with statusCode 409) to stored, 401/403 to PermissionDenied, timeout/ClientException/SocketException to ConnectionUnavailable, as the spec requires.
- Queue writes via `.partial` then rename, and `purchaseIdFromPendingName` rejects hidden and foreign names, so flush never uploads half-written or stray files.
- Commit keeps the photo, commits with the path under `refusalWindow`, discards on refusal or throw, and flushes only after success; refusal window moved from the page into the cubit.
- Publishable key is the accepted, plan-recorded boundary (project-plan.md section on receipt photos); no secret or service key is present.
- Tests cover picker mapping, queue against a real temp directory, upload status mapping and 30s timeout, cubit commit paths, and Home and review screen widgets; no skipped or focused tests in the delta.

## Findings

- F-13 [P3] open - Receipt comments still describe Firebase Storage and overwriting uploads
- F-14 [P3] open - A refused purchase can still leave an uploaded receipt object

## Remaining risk

- Check was not required and was not run by the reviewer; device behaviour relies on the builder's recorded Android and iPhone runs.
- Web was not run on any device (spec marks it unverifiable); `flutter build web` was not rerun in this review.
- No combined Verify command and no integration test harness exist for this project.
- Bucket read and list policies live in Supabase and cannot be verified from code; whether receipt photos are readable with the shipped publishable key is unaudited.
- An unmapped transport error (for example a TLS HandshakeException) escapes `uploadReceiptToSupabase`; on phones it aborts that flush and is reported through `addError`, leaving the queue intact; not reproduced.
