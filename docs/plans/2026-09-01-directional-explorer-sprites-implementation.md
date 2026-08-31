# Directional Explorer Sprites Implementation Plan

## Goal

Ship a matched four-direction static sprite set for both teams and a minimal Flutter-owned facing lifecycle.

## Scope

- Preserve the approved Azure turnaround outside the Flutter bundle.
- Generate and normalize eight production explorer PNGs.
- Extend the existing sprite loader and board painter selection.
- Store facing overrides in `GamePage` and reset them only at named lifecycle boundaries.
- Extend focused asset, painter, page, and native scene checks.

## Tasks

### 1. Preserve and verify the approved source

Copy the exact operator-supplied PNG into `assets/images/reference/directional-explorer-sprites-v1`.
Record its SHA-256 and confirm that `pubspec.yaml` does not bundle the reference directory.

### 2. Establish failing contracts

Extend the loader test to require four directions for each team.
Extend the asset test to require eight transparent 512-by-512 explorer exports with matched alpha bounds and foot anchors.
Add page checks for initial defaults, movement and Push updates, persistence, and reset boundaries.

### 3. Produce the directional assets

Use the approved Azure turnaround and the active team sprites as visual references.
Generate one consistent four-direction set per team.
Normalize each output to a transparent 512-by-512 canvas with a shared bottom-center foot anchor.
Record the selected prompts, source hashes, normalization command, and output hashes in the sprite README.

### 4. Implement the minimal presentation state

Add `ExplorerFacing` and directional image selection to `ProductionSpriteSet`.
Pass a piece-id-to-facing map from `GamePage` into `RoundBoard`.
Derive visual facing from Rust-authored movement and displacement facts before playback starts.
Keep overrides after commit and prune missing pieces.
Clear overrides after successful round advance, restart, or runtime board replacement.

### 5. Verify focused behavior

Run `dart format` on changed Dart files, focused sprite and page tests, and `flutter analyze`.
Inspect the diff to confirm that Rust, bridge, geometry, hit regions, and semantics are unchanged.

### 6. Verify native rendering

Run the production sprite scene on one iOS Simulator and one Android Emulator, one heavy job at a time.
Inspect idle, Push-contact, and settled captures for direction, scale, and foot-anchor consistency.

### 7. Run delivery gates

Run `merry run check`, inspect the complete Git diff, and request one local adversarial review.
Resolve every supported finding before creating semantic commits and opening the pull request.
