# Spec: Foothold State Progression

## Status

Approved for implementation by the repository issue and the operator's active issue-processing mandate.

## Problem

The damaged foothold currently retains one dominant fracture at native board scale.
It reads as a lightly cracked version of the intact foothold instead of a distinct intermediate state near collapse.

## Goal

Make intact, damaged, and collapsed footholds read as a clear three-step progression while preserving the established board composition and gameplay contract.

## Requirements

1. Replace only `assets/images/sprites/foothold_damaged.png` among the active foothold sprites.
2. Preserve the current 512-by-512 transparent sRGB image contract and the matched orthographic square footprint.
3. Show several bold branching fractures and modest edge chips that remain legible when the sprite is reduced to native board scale.
4. Keep the damaged foothold usable as a landing surface: its center remains solid, its major slabs remain connected, and it has no transparent central hole.
5. Keep the intact and collapsed active sprites byte-for-byte unchanged.
6. Keep the existing one-sprite-per-state runtime model.
7. Preserve at least one unselected generated candidate under `assets/images/reference/foothold-state-progression-v1/`, which remains outside the bundled asset path.
8. Record the selected source, prompt, processing steps, and hashes in the sprite provenance.
9. Do not change tile types, board geometry, hit regions, semantics, Rust rules, or bridge behavior.

## Acceptance Criteria

1. At native board scale, the intact foothold has an orderly surface, the damaged foothold has multiple readable fracture branches without becoming a hole, and the collapsed foothold has a transparent center with a connected rim.
2. The damaged sprite passes the existing dimension, transparency, footprint, and alpha-bound checks.
3. A targeted asset check confirms that the damaged surface retains stronger dark fracture contrast than the intact surface after reduction to 64 pixels.
4. The existing production sprite scene shows all three states correctly on an iOS Simulator and an Android Emulator.
5. The full repository gate and a local adversarial review report no unresolved findings.

## Non-goals

- Runtime sprite variants or random selection.
- Changes to the intact or collapsed active artwork.
- Animation, new gameplay states, or rules changes.
- A new image-processing dependency or runtime asset abstraction.

## Verification

```shell
flutter test test/game/view/production_sprite_assets_test.dart
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <ios-simulator-id> --flavor development
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <android-emulator-id> --flavor development
merry run check
```
