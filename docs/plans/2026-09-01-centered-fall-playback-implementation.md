# Centered Fall Playback Implementation Plan

## Goal

Center a displaced explorer over its adjacent hole for the final visible fall frame, then stop painting it without changing authoritative game state or board interaction geometry.

## Scope

- Add the approved Spec and decision ledger.
- Extend the existing `RoundBoard` paint regression with endpoint and visibility checks.
- Change the fall distance and post-end visibility in the existing playback painter.
- Reuse the existing production sprite scene with a fall resolution and final snapshot.

## Tasks

### 1. Establish a failing playback regression

Measure the fallback explorer's painted color bounds at the start and endpoint of a fall.
Check one horizontal and one vertical direction with reduced motion enabled and disabled, then confirm that the explorer is absent after the displacement boundary.
Run the focused board test against the current 1.3-cell path and retain its expected failure.

### 2. Center and hide the falling explorer

Change the fall distance to one cell in `_fallCenter`.
Skip painting a displaced explorer with an exit direction after the existing Push displacement endpoint.
Do not alter timing constants, resolution data, snapshots, geometry, hit regions, or semantics.

### 3. Exercise the fall in the native fixture

Make the existing production sprite scene displace its second explorer into an adjacent hole.
Keep the fixture's current selection, Push-contact, and settled capture flow.

### 4. Verify focused behavior

Run `dart format` on the changed Dart files, the focused board test, the production scene widget test where supported, and `flutter analyze`.
Inspect the diff to confirm that Rust and bridge code are unchanged.

### 5. Verify native rendering

Run the production sprite scene on one iOS Simulator and one Android Emulator, one heavy job at a time.
Inspect the Push-contact and settled captures and confirm that the fallen explorer is absent from the settled board.

### 6. Run delivery gates

Run `merry run check`, inspect the complete Git diff, and request one local adversarial code review.
Resolve every supported finding before creating semantic commits and opening the pull request.
