# Spec: Centered Fall Playback

## Status

Approved for implementation by the repository issue and the operator's active issue-processing mandate.

## Problem

When a Push displaces an explorer into an adjacent hole, Flutter moves the visible piece 1.3 cell widths and keeps painting it after the displacement phase.
The explorer therefore appears to pass the opening before the final Rust snapshot removes it.

## Goal

End fall playback at the adjacent hole's visual center and remove the falling explorer from later playback frames without changing authoritative game state.

## Requirements

1. Change only Flutter playback path, visibility, tests, and the native visual fixture.
2. Preserve the Rust-authored move resolution, final snapshot, event order, board geometry, hit regions, and semantics.
3. Move a falling explorer exactly one cell from its source in the Rust-authored exit direction.
4. Keep the explorer visible at the displacement endpoint and hide it after that boundary.
5. Use the same endpoint and visibility boundary when reduced motion is enabled.
6. Cover one horizontal and one vertical fall direction with regression checks for standard and reduced-motion playback.
7. Exercise a real fall in the existing production sprite scene and capture Push-contact and settled scenes on an iOS Simulator and an Android Emulator.

## Acceptance Criteria

1. The last endpoint frame centers the displaced explorer over the adjacent hole instead of beyond it.
2. A later playback frame contains no pixels from the displaced explorer.
3. Horizontal and vertical checks pass with reduced motion enabled and disabled.
4. The production scene's settled Rust snapshot omits the fallen explorer.
5. iOS and Android Push-contact and settled captures show the same fall outcome.
6. The full repository gate and a local adversarial review report no unresolved findings.

## Non-goals

- Changes to Rust rules, bridge types, move timing, board geometry, hit regions, or semantics.
- New animation controllers, opacity effects, sprite variants, or runtime dependencies.
- A redesign of other move or Push playback.

## Verification

```shell
flutter test test/game/view/round_board_test.dart
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <ios-simulator-id> --flavor development
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <android-emulator-id> --flavor development
merry run check
```
