---
type: Spec
title: Round and Match Boundaries
---

## Problem

The result overlay uses nearly the same hierarchy for an internal round and the overall best-of-three match. [L1]
The current copy changes from `takes the round` to `wins the match` and from `Next Round` to `New Match`, but neither outcome names its completion scope before the winner or describes the continuation as a start action. [L1]

## Proposed Outcome

Make the completed scope immediately visible as either `ROUND COMPLETE` or `MATCH COMPLETE`, and make the next action explicit as starting the next round or a new match. [L1]
Keep the final board, winner, reason, score, rules state, and transition behavior unchanged. [L2] [L3]

## User Stories

1. As a player, I can tell whether I completed one round or won the overall match before choosing the next action.
2. As a player, I can tell whether the continuation starts another round inside the match or resets the complete match.
3. As a screen-reader or large-text user, I retain the existing result announcement and primary action without clipped content.

## Requirements

1. Show a localized `ROUND COMPLETE` badge whenever the snapshot has a round winner but no match winner. [L1] [L3]
2. Show a localized `MATCH COMPLETE` badge whenever the snapshot has a match winner. [L1] [L3]
3. Render the round badge on the existing neutral panel color and the match badge on the winning expedition color so the scopes differ by text and surface treatment.
4. Change the round continuation label to `Start Next Round` and the match continuation label to `Start New Match`.
5. Preserve the winner label, round outcome sentence, win reason, score, final board, full-size primary action, and distinct live announcements. [L2] [L4]
6. Keep `MatchController`, Rust rules, bridge types, `advanceRound`, `restart`, replay, facing reset, feedback, and opponent timing unchanged. [L3]
7. Add no route, timer, animation, package, generated runtime code, or new application state. [L2]
8. Keep the result usable without overflow at the existing supported compact and large-text fixtures. [L4]

## Technical Decisions

Keep the change inside `_ResultOverlay` and the English ARB contract.
Select the badge copy and surface from the existing `matchWinner` branch that already selects the outcome sentence and continuation callback.
Reuse `_panelColor` for a completed round and `_playerColor(winner)` for a completed match.
Place the badge inside the existing `FittedBox` content so it scales with result copy while the action remains outside and keeps its full touch target.

Do not calculate a round number from score pips in Dart.
Do not create a transient start banner because that would add local timing state without improving the existing explicit continuation boundary.

## Testing Strategy

1. Extend the current round-result widget test to require the round scope, neutral badge surface, and `Start Next Round` action.
2. Extend the current match-result widget test to require the match scope, winner-colored badge surface, and `Start New Match` action.
3. Confirm both tests fail against the current overlay because the scope badges and start labels do not exist.
4. Implement the minimal ARB and `_ResultOverlay` changes, then rerun both focused tests.
5. Run the existing compact-screen, 200-percent text, semantics, and result-announcement tests through the complete widget suite.
6. Run `dart format`, `flutter analyze`, and `merry run check`.

## Acceptance Criteria

1. A round result visibly says `ROUND COMPLETE`, keeps the round outcome details, and offers `Start Next Round`.
2. A match result visibly says `MATCH COMPLETE`, keeps the deciding-round details, and offers `Start New Match`.
3. The two scope badges use distinct surfaces without relying on that color difference as their only cue.
4. Advancing a round and restarting a match still use the existing callbacks and reset presentation facing.
5. Existing result announcements, final-board visibility, input blocking, feedback, and large-text behavior remain green.
6. The focused regressions fail before implementation and pass after it.
7. `flutter analyze` and `merry run check` complete without a product failure.
8. One local adversarial review reports no unresolved findings.

## Out of Scope

- Round numbering, configurable match length, match history, statistics, or tournament presentation.
- A separate result route, start screen, modal, countdown, confetti, or transition animation.
- Changes to Rust rules, bridge code, controller state, board rendering, haptics, sound, or opponent policy.
- New localization beyond the existing English ARB contract.

## Verification

```shell
flutter test test/game/view/game_page_test.dart --plain-name "shows a finished round and advances past it"
flutter test test/game/view/game_page_test.dart --plain-name "blocks terminal board input and restarts the round"
flutter test test/game/view/game_page_test.dart
flutter analyze
merry run check
```
