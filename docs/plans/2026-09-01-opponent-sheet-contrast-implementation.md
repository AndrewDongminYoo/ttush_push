# Opponent Sheet Contrast Implementation Plan

## Goal

Make every opponent-sheet label readable against the existing dark background with one local style change and one rendered-color regression.

## Scope

- Add the approved Spec and Interview Ledger.
- Extend the existing `GamePage` widget-test seam.
- Set explicit high-contrast text colors in `_OpponentSelectionSheet`.
- Preserve the sheet background, radio controls, selection flow, and app-wide theme.

## Tasks

### 1. Establish the failing contrast regression

Open the opponent sheet through the existing `GamePage` test fixture.
Read the actual `BottomSheet` background and each label's resolved `RenderParagraph` color.
Require at least a 4.5-to-1 contrast ratio for the heading and all four option labels.
Run only this test and confirm that the inherited colors fail the threshold.

### 2. Apply the minimum local foreground fix

Set the heading and option-label text to white inside `_OpponentSelectionSheet`.
Do not change the global theme or introduce a sheet-theme abstraction.

### 3. Verify the focused behavior

Run `dart format` on the changed Dart files.
Run the contrast regression and all `GamePage` and accessibility widget tests.
Run `flutter analyze`.

### 4. Run delivery gates

Run `merry run check` and inspect the complete diff.
Request one local adversarial review against `origin/main`.
Resolve every supported finding before the semantic commit and pull request.
