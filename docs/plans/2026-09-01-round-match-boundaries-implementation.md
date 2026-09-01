# Round and Match Boundaries Implementation Plan

## Goal

Make an internal round result and the overall match result immediately distinguishable without adding a new lifecycle or transition surface.

## Scope

- Add the approved Spec and Interview Ledger.
- Add localized completion-scope copy and explicit start-action labels.
- Strengthen the existing result overlay hierarchy with one small badge.
- Extend the existing round and match result widget regressions.
- Keep rules, controller state, board rendering, replay, and callbacks unchanged.

## Tasks

### 1. Establish the failing result contract

Extend the current round-result test to require `ROUND COMPLETE`, a neutral badge, and `Start Next Round`.
Extend the current match-result test to require `MATCH COMPLETE`, a winner-colored badge, and `Start New Match`.
Run only those two tests and confirm that the current overlay fails for the missing scope badge or action copy.

### 2. Add the smallest presentation distinction

Add the two completion-scope messages and update the two continuation messages in the English ARB file.
Render one keyed scope badge before the existing winner row.
Use the existing neutral panel color for round completion and the winner color for match completion.

### 3. Preserve lifecycle and accessibility behavior

Keep the existing outcome sentence, reason, score, final board, live announcement, button callback, and full touch target.
Do not modify `MatchController`, Rust, bridge output, replay, facing reset, or timing state.
Run the complete `GamePage` widget suite so compact layout, 200-percent text, announcements, and continuation behavior remain covered.

### 4. Run delivery gates

Run `dart format`, `flutter analyze`, `merry run check`, and `git diff --check`.
Inspect the complete diff and request one local adversarial review.
Resolve every supported finding before the semantic commit and pull request.
