# Spec: Directional Explorer Sprites

## Status

Approved for implementation by GitHub Issue #27 and the operator's active issue-processing mandate.

## Problem

Each team currently uses one neutral explorer image in every board state.
The starting formation therefore does not visibly face the opposing team, and movement does not leave a directional pose.

## Goal

Render Azure and Ember with consistent static up, down, left, and right sprites while keeping facing entirely within Flutter presentation state.

## Requirements

1. Preserve the approved Azure turnaround as an unbundled reference asset before production implementation begins.
2. Provide four transparent 512-by-512 production sprites for Azure and four for Ember.
3. Keep each team's silhouette, palette, scale, high-angle camera, canvas, and foot anchor consistent across all four directions.
4. Default Azure to visual up and Ember to visual down so the initial formation faces inward.
5. Update the moving explorer's facing when playback begins by reading Rust-authored travel coordinates.
6. Update a displaced explorer's facing from its Rust-authored displacement or exit direction during Push playback.
7. Preserve the last facing for surviving explorers after playback commits.
8. Reset facing overrides after a successful round advance, restart, or runtime board replacement.
9. Keep facing out of Rust rules, bridge types, legal moves, snapshots, board geometry, hit regions, and accessibility semantics.
10. Extend the sprite loader and asset contract tests for all eight explorer exports.
11. Capture idle, Push-contact, and settled scenes on one iOS Simulator and one Android Emulator.

## Acceptance Criteria

1. The preserved reference PNG has SHA-256 `5101ee7a93afc4596cc41dcb2359c3803960fb5e4e598ebaf08bc2b6f05f4c65` and is absent from the Flutter asset manifest.
2. All eight explorer PNGs are 512 by 512, contain real transparent pixels, and meet one shared footprint and foot-anchor tolerance.
3. Azure and Ember use opposing initial sprites on an idle board.
4. A normal move changes the mover to the visual direction of travel before playback and keeps that direction after commit.
5. A Push changes both visible explorers to the Rust-authored travel direction before contact and keeps surviving directions after commit.
6. Round advance, restart, and runtime board replacement return all explorers to team defaults only when the authoritative snapshot changes.
7. Existing board geometry, hit regions, semantics, reduced motion, and feedback behavior remain unchanged.
8. Native idle, Push-contact, and settled captures show readable, anchored poses on both supported platforms.
9. The full repository gate and one local adversarial review report no unresolved findings.

## Non-goals

- Foot movement, idle animation, frame interpolation, or a new animation dependency.
- Diagonal sprites or use of the 3-by-3 reference as a runtime sheet.
- Changes to Rust, generated bridge code, snapshots, rules, legal moves, geometry, hit regions, or semantics.
- A redesign of playback timing, board art, team panels, or accessibility copy.

## Verification

```shell
flutter test test/game/view/production_sprite_set_test.dart test/game/view/production_sprite_assets_test.dart test/game/view/round_board_test.dart test/game/view/game_page_test.dart
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <ios-simulator-id> --flavor development
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <android-emulator-id> --flavor development
merry run check
```
