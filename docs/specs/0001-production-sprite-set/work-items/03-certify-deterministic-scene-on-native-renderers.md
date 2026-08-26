---
type: Work Item
title: Certify the deterministic scene on both native renderers
parent: ../spec.md
---

## What to build

Add a deterministic production-sprite integration scene and screenshot-aware driver, then exercise the real Flutter renderer sequentially on one compact iOS Simulator and one tall Android Emulator.
Save and inspect one platform-specific PNG from each renderer and finish with the repository-wide gates that cover the implemented milestone.

## Required context

- `../spec.md` defines the exact fixture state, screenshot output path, inspection criteria, verification commands, and physical-device exclusion.
- `lib/game/view/game_page.dart` accepts a `RulesEngine` and exposes the real selection path through board taps.
- `test/support/match_fixtures.dart` demonstrates deterministic fake-engine and snapshot construction patterns, but selection and legal destinations remain Flutter-owned state rather than `GameSnapshot` fields.
- `integration_test/rules_engine_parity_test.dart` demonstrates the existing native integration-test shape but does not certify sprite rendering.
- `test_driver/integration_test.dart` uses the basic driver; the production-sprite scene needs a dedicated screenshot-aware driver without changing Rust parity scope.
- `merry.yaml` defines the repository gate, and `CLAUDE.md` explains that the gate does not replace native-renderer or full Markdown-spelling evidence.

## Acceptance criteria

- [x] `integration_test/production_sprite_scene_test.dart` mounts the real match surface with the production asset loader and a deterministic fake rules engine.
- [x] The fake engine returns a snapshot containing both explorer factions and all three foothold states plus legal moves from one Azure explorer to one empty normal destination and one Ember-occupied Push destination.
- [x] The integration test taps the Azure explorer through the real match interaction path and visibly produces selection, normal-move, and occupied-Push overlays without fabricating those states in `GameSnapshot`.
- [x] The test uses `IntegrationTestWidgetsFlutterBinding.takeScreenshot` and calls `convertFlutterSurfaceToImage` before capture on Android.
- [x] `test_driver/production_sprite_scene_driver.dart` writes screenshot bytes under `build/screenshots/production-sprite-set/` using platform-specific filenames.
- [x] The fixture completes on one compact iOS Simulator and leaves an iOS PNG available for inspection at the required output path.
- [x] The fixture completes on one tall Android Emulator and leaves an Android PNG available for inspection at the required output path.
- [x] The two native jobs run sequentially after checking machine load, and neither job installs or launches on Andrew's daily iPhone.
- [x] Both PNGs visibly confirm faction distinction, terrain progression, central void, broken fragments, board gutters, overlay ordering, background cohesion, and absence of cell-scale clipping.
- [x] `flutter pub get`, focused Flutter view tests, CSpell for the Spec folder and sprite README, `merry run check`, and both Spec-defined `flutter drive` commands pass.
- [x] The final repository status contains only intended milestone files plus any preserved author-unknown changes that were present before implementation.

## Covers

- User Stories: 5
- Requirements: 6-8, 12-18, 20-21
- Testing Strategy: 7-10
- Interview Ledger: L5

## Blocked by

- `02-render-atomic-sprite-set-with-lifecycle-safe-fallback.md`
