# Foothold State Progression Implementation Plan

## Goal

Replace the damaged foothold artwork with one clearer intermediate state and prove its behavior at native board scale without changing runtime code.

## Scope

- Add the approved Spec and its decision ledger.
- Add one selected damaged sprite and preserve generated alternatives outside the bundled asset path.
- Extend the existing production sprite asset test with one native-scale contrast guard.
- Update the existing sprite provenance.
- Reuse the existing native production sprite scene fixture.

## Tasks

### 1. Establish a failing native-scale asset check

Add one focused test to `test/game/view/production_sprite_assets_test.dart` that reduces the foothold sprites to 64 pixels, compares the intact and damaged dark surface pixels, and distinguishes the solid damaged center from the collapsed hole.
Confirm that the current damaged sprite fails the new threshold before replacing the asset.

### 2. Generate and select the damaged sprite

Edit the current foothold artwork with the intact sprite as the composition anchor and the collapsed sprite as the severity ceiling.
Select the smallest successful change: several bold branching fractures, modest edge chips, connected major slabs, and a solid center.
Preserve at least one unselected candidate under `assets/images/reference/foothold-state-progression-v1/`.

### 3. Normalize and document the assets

Reuse the established alpha crop, square resize, centered canvas, and metadata-stripping process.
Update `assets/images/sprites/README.md` with the prompt, selected source, processing steps, and hashes.

### 4. Verify mechanical constraints

Run `dart format` on the changed Dart test, then run the focused asset test and `flutter analyze`.
Confirm that the intact and collapsed active sprite hashes did not change.

### 5. Verify native appearance

Run the existing production sprite scene on one iOS Simulator and one Android Emulator, one heavy job at a time.
Inspect the selection, push-contact, and settled captures from both renderers and confirm that all three foothold states remain readable.

### 6. Run delivery gates

Run `merry run check`, inspect the complete Git diff, and request one local adversarial code review.
Resolve every supported finding before creating semantic commits and opening the pull request.
