# Match Visual Cohesion Implementation Plan

**Goal:** Make the match scene read as one deliberate air-ruins game surface and make Push read as a collision event.

**Architecture:** Keep `GamePage` as the replay owner and `RoundBoard` as the painter, geometry, semantics, and overlay owner. Use an orthographic top-down active board set while retaining the first generated set outside the runtime loader. Derive the Push marker from the existing Rust-authored `MoveResolution`.

**Tech Stack:** Flutter 3.44, Dart 3.12, Flutter widget tests, Flutter integration tests, and the existing asset bundle loader.

**Spec:** `docs/specs/0003-match-visual-cohesion/spec.md`

## Scope

| Path                                                 | Responsibility                                            |
| ---------------------------------------------------- | --------------------------------------------------------- |
| `assets/images/sprites/*.png`                        | Provide the five active production sprites.               |
| `assets/images/reference/match-visual-cohesion-v1/*` | Preserve the first set for external-content use.          |
| `assets/images/sprites/README.md`                    | Record retained and active generation provenance.         |
| `lib/game/view/game_page.dart`                       | Apply the restrained HUD visual treatment.                |
| `lib/game/view/round_board.dart`                     | Paint the directional Push contact brace.                 |
| `test/game/view/round_board_test.dart`               | Prove the directional contact cue with rendered pixels.   |
| `integration_test/production_sprite_scene_test.dart` | Capture real selection, contact, and settled Push states. |
| `docs/specs/0003-match-visual-cohesion/*`            | Record approved requirements and decision sources.        |

## Task 1: Add the Push contact regression

- [x] Add one focused `RoundBoard` pixel test for a Push contact brace.
- [x] Run the focused test and confirm that it fails because the current impact ring is symmetric.
- [x] Add the smallest painter change that uses mover travel from `MoveResolution`.
- [x] Run the focused test again and confirm that it passes.

The test must assert a rendered behavior that a missing directional brace breaks.
It must not assert private constants or source text.

## Task 2: Apply the restrained HUD treatment

- [x] Keep the top Ember panel, bottom Azure panel, score pips, controls, widget keys, semantics, and active-turn distinction.
- [x] Replace the full saturated active-panel fill with a muted surface, a shared border rule, and a small team accent.
- [x] Run the existing `game_page_test.dart` and accessibility tests.

## Task 3: Replace the five production sprites

- [x] Generate one transparent image for each explorer and foothold with the built-in image-generation tool.
- [x] Select a cohesive matched set and process each file to a transparent 512 by 512 PNG.
- [x] Preserve the original explorer files.
- [x] Add the two top-down explorer paths and replace the three active foothold paths.
- [x] Keep only those five paths active in `ProductionSpriteSet`.
- [x] Update `assets/images/sprites/README.md` with final prompts and processing steps.
- [x] Run `production_sprite_assets_test.dart`.

The initial pass did not add a new image loader, remote asset access, or an image-processing dependency.

## Task 4: Exercise the real Push states

- [x] Extend the integration fixture so it taps a legal Azure-to-Ember Push through `GamePage`.
- [x] Capture the selected board, the Push contact hold, and the settled board with the existing screenshot binding.
- [x] Run the fixture on one iOS Simulator and one Android Emulator.
- [x] Inspect every saved native screenshot before completion.

The fixture must obtain its Push facts from the fake rules engine and the real match interaction path.
It must not directly fabricate a Flutter-only replay state.

## Task 5: Run completion checks

- [x] Run `dart format --output=none --set-exit-if-changed lib test integration_test test_driver`.
- [x] Run focused Flutter view tests.
- [x] Run `npx cspell lint --config cspell.json --gitignore-root . '**/*.md'`.
- [x] Run `flutter pub get`.
- [x] Run `flutter gen-l10n`.
- [x] Run `dart pub get --offline` in `rust_builder/cargokit/build_tool`.
- [x] Run `merry run check`.

`merry run check` proves format, static analysis, Flutter tests, Rust checks, the host bridge, and Trunk checks.
It does not prove the native screenshot appearance.

## Task 6: Align the board camera after native review

- [x] Change the active-path and square-footprint tests first and confirm that the previous assets fail them.
- [x] Preserve hash-matched copies of all five first-pass sprites under `assets/images/reference/match-visual-cohesion-v1/`.
- [x] Generate three orthographic square footholds and two elevated board-specific explorers with the built-in image-generation tool.
- [x] Keep the original explorer files and switch only `ProductionSpriteSet` to the new top-down explorer paths.
- [x] Normalize the active PNG files to 512 by 512 sRGBA and filter unreadable detached alpha debris from the collapsed foothold.
- [x] Update the asset provenance, specification, decision ledger, and this plan.
- [x] Capture and inspect selection, Push contact, and settled output on one iOS Simulator and one Android Emulator.
- [x] Rerun focused Flutter tests, documentation checks, and `merry run check`.

## Constraints

- Keep the original checkout untouched.
- Keep this working tree on `feat/match-visual-cohesion`.
- Do not install, launch, or write to the daily iPhone.
- Do not add a dependency.
- Do not hand-edit generated bridge or localization output.
- Do not commit, push, or create a pull request without separate operator authorization.
