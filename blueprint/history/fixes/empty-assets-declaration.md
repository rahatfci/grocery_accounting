# Fix: Empty assets declaration breaks a fresh clone

**Type:** Fix
**Status:** verified
**Branch:** `fix/empty-assets-declaration`

## The problem

`pubspec.yaml` declares `assets: - assets/`, but the folder is empty. Git
tracks no empty folders, so a fresh clone has no `assets/`, and `flutter build`
fails with "unable to find directory entry in pubspec.yaml". Any CI, and anyone
cloning the repository from GitHub, hits it. `AGENTS.md` lists it under Known
issues.

## The fix

Remove the `assets:` declaration. Nothing in `lib/` or `test/` loads an asset
(no `AssetImage`, `Image.asset` or `rootBundle`), and the fonts are declared
separately under `fonts:`, which stays. A feature that adds an asset declares
it then. Remove the matching Known issues entry from `AGENTS.md`.

It must not break the `CenturyGothic` font declarations, the build on any
platform, or the test suite.

`blueprint/project-plan.md` section 10 still lists this defect. The plans
belong to the user, so they are left alone.

## Build steps

- [x] **Step 1 - Drop the declaration** - remove `assets:` and `- assets/`
  from `pubspec.yaml`, run `flutter pub get`, and remove the Known issues
  bullet from `AGENTS.md`. *Done when:* a fresh clone of the branch into a
  temporary directory builds with `flutter build web` and passes
  `flutter analyze`. The existing suite passes, and `pubspec.lock` is
  unchanged.

## Verify

- Clone the repository into a temporary directory without an `assets/` folder,
  run `flutter pub get` and `flutter build web`, and it succeeds.
- `flutter analyze` and `flutter test` in the working copy.

## Verification record

2026-09-24. Reproduced first: a fresh local clone of `main` had no `assets/`,
and `flutter build web` printed "Error: unable to find directory entry in
pubspec.yaml: .../assets/". After the fix, a fresh clone of the branch built
with `flutter build web`, with no asset error, and `flutter analyze` was clean.
`flutter test` passed all 706 tests, and `pubspec.lock` was unchanged.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":2015,"specSha256":"9f7099e5759f59a10fbbd533b64c4b90c431011a8ec902fcc92c1dd95d1a1fc5","branch":"refs/heads/fix/empty-assets-declaration","head":"dda3a43e3219905ee80a6bebedfd6489efceeea0","baseRef":"refs/heads/main","baseCommit":"2992642dce6522f1ae3d0711b170fbd798843f60","sourceTree":"6253aba5cca3a5b88625225e75bc7c3af49f41fe","absentOptional":[]} -->
