---
type: Spec
title: Opponent Sheet Contrast
---

## Problem

The opponent-selection bottom sheet uses the dark `_panelColor` background.
Its heading and option labels inherit colors from the app's light `ColorScheme`.
The resulting text colors have insufficient contrast against the sheet background. [L1] [L2]

## Proposed Outcome

Render the opponent-sheet heading and every option label with a local high-contrast foreground color.
Keep the existing sheet background, controls, and selection behavior unchanged. [L2] [L3]

## User Stories

1. As a player, I can read the opponent-sheet heading and every opponent option before I select one.
2. As a player, I can read the selected and unselected opponent labels with equal clarity.
3. As a developer, I can detect a contrast regression from the resolved widget colors.

## Requirements

1. Keep `_panelColor` as the modal bottom-sheet background. [L2] [L3]
2. Give the `Opponent` heading a foreground color with at least a 4.5-to-1 contrast ratio against the rendered sheet background. [L1] [L4]
3. Give the Human, Random, Greedy, and Minimax labels a foreground color with at least a 4.5-to-1 contrast ratio against the rendered sheet background. [L1] [L4]
4. Meet the same contrast requirement when an option is selected or unselected. [L1] [L4]
5. Preserve the existing `RadioGroup`, `RadioListTile`, selected semantics, dismissal behavior, opponent changes, lock behavior, and stable widget keys. [L3]
6. Keep the change local to `_OpponentSelectionSheet` and its widget regression. [L3] [L5]
7. Do not change the app-wide theme, HUD colors, localization, navigation, controller state, game rules, bridge code, or dependencies. [L3]

## Technical Decisions

Use an explicit white foreground for the heading and each option label.
Do not add a sheet theme or a new widget abstraction for one local use.

The regression reads the resolved `RenderParagraph` color instead of checking only the `Text.style` input.
It reads the rendered `BottomSheet.backgroundColor` and calculates the contrast ratio from both luminance values. [L4]

## Testing Strategy

1. Extend the existing opponent-sheet widget test with one contrast regression. [L4]
2. Open the real `_OpponentSelectionSheet` through `GamePage`.
3. Read the actual sheet background and the resolved heading and option-label colors.
4. Confirm that the test fails against the current inherited colors before implementation.
5. Require a contrast ratio of at least 4.5 to 1 for the heading and all four option labels.
6. Run the focused opponent-sheet tests, `flutter analyze`, and `merry run check`.
   The widget regression verifies resolved Flutter colors.
   It does not replace visual inspection on a native renderer.

## Acceptance Criteria

1. The focused contrast regression fails on the current implementation because at least one resolved label color is too close to `_panelColor`.
2. The heading and all four option labels meet the 4.5-to-1 contrast threshold after the fix.
3. Existing open, select, dismiss, lock, semantics, and text-scale tests remain green.
4. `flutter analyze` and `merry run check` complete without a product failure.
5. One local adversarial review reports no unresolved findings.

## Out of Scope

- A global dark theme or a new bottom-sheet theme.
- Changes to radio indicator colors, panel layout, copy, options, or interaction timing.
- Changes to game state, Rust rules, generated bridge code, assets, or platform configuration.

## Verification

```shell
flutter test test/game/view/game_page_test.dart --plain-name 'keeps opponent sheet labels legible against its dark background'
flutter test test/game/view/game_page_test.dart test/game/view/game_page_accessibility_test.dart
flutter analyze
merry run check
```
