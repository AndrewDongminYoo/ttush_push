# Playtest-Ready Game Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the development-grade round screen into a board a first-time player can read, without adding animation or moving any rule into Flutter.

**Architecture:** `RoundController` is unchanged. `RoundBoard` gains tile shapes, piece identity, and the move-versus-push destination affordances. `GamePage` gains the full-screen layout, the two player panels, and the terminal result overlay.

**Tech Stack:** Flutter Material widgets, `CustomPainter`, Dart widget and unit tests. No new dependency.

**Spec:** `docs/specs/2026-08-22-playtest-ready-game-screen.md`

## Global Constraints

- Rust stays the only rules authority. Legality comes only from `RulesEngine.legalMoves`.
- Reading occupancy from `snapshot.pieces` is presentation. Deciding what a push does is not, and stays in Rust.
- Do not add a dependency, change Rust rules, or touch generated `flutter_rust_bridge` source.
- Introduce no presentation state that outlives a snapshot replacement, and no animation controller.
- `RoundController` keeps its current public surface; this milestone adds no controller method.
- Coverage stays at 100% on `lib`, so every new painter and layout branch needs a test that reaches it.
- Follow the existing test style: assert painter and widget behavior directly rather than introducing golden files, which this repo does not use.

## File Map

| Path                                   | Responsibility                                                                            |
| -------------------------------------- | ----------------------------------------------------------------------------------------- |
| `lib/game/view/round_board.dart`       | Tile shapes, piece identity, selection, and the move-versus-push destination affordances. |
| `lib/game/view/game_page.dart`         | Full-screen layout, player panels, result overlay, and existing error and input wiring.   |
| `test/game/view/round_board_test.dart` | Painter behavior for each tile kind, piece owner, selection, and both destination kinds.  |
| `test/game/view/game_page_test.dart`   | Layout, turn indication, push-destination tap precedence, overlay, and `Play Again`.      |
| `test/app/view/app_test.dart`          | Entry rendering after the `AppBar` is removed.                                            |

### Task 1: Give Tiles a Readable Shape

**Files:**

- Modify: `lib/game/view/round_board.dart`
- Modify: `test/game/view/round_board_test.dart`

- [x] Paint `Normal` as an intact foothold inset from its cell, so the gap between footholds reads as structure rather than as a grid line.
- [x] Paint `Damaged` as the same foothold carrying a visible crack, so its meaning does not depend on hue.
- [x] Paint `Hole` as absent floor: the board background shows through, with no foothold body drawn.
- [x] Assert each kind separately, including that a `Hole` cell draws no foothold body.

### Task 2: Separate Move Destinations From Push Destinations

**Files:**

- Modify: `lib/game/view/round_board.dart`
- Modify: `test/game/view/round_board_test.dart`

- [x] Derive each legal destination for the selected piece exactly as today, from `move.direction` applied to the selected piece's position.
- [x] Classify a destination as a push when any piece in `snapshot.pieces` occupies it, and as a move otherwise.
- [x] Render the two classes distinguishably, keeping the existing rule that destination markers paint after pieces so an occupied destination stays visible.
- [x] Assert that a destination occupied by an opposing piece renders the push affordance while an empty one does not, and that neither is drawn without a selection.

### Task 3: Strengthen Piece Identity and Selection

**Files:**

- Modify: `lib/game/view/round_board.dart`
- Modify: `test/game/view/round_board_test.dart`

- [x] Give each owner a distinct shape treatment in addition to its color, so the two sides are separable without relying on hue.
- [x] Keep the selection marker unmistakable against both owners and against both destination affordances.
- [x] Assert owner distinction and selection marking independently of color equality alone.

### Task 4: Replace the Development Screen With the Full-Screen Layout

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `test/game/view/game_page_test.dart`
- Modify: `test/app/view/app_test.dart`

- [x] Remove the `AppBar` and lay the screen out as a top player panel, the board, and a bottom player panel inside `SafeArea`.
- [x] Give the bottom panel to the first player and the top panel to the second player, so each faces their own panel across a shared device.
- [x] Show in each panel whether the turn is that player's, using more than a text label so the active side is visible at a glance.
- [x] Let the panels take their intrinsic height and the board take the remaining space while staying square, so a short screen shrinks the board instead of clipping it.
- [x] Keep the existing initialization, retry, and action-error presentation reachable.
- [x] Assert the layout at a small and a large surface size, and that the board stays square in both.

### Task 5: Show the Result Over the Final Board

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `test/game/view/game_page_test.dart`

- [x] Draw the terminal result as an overlay above the board rather than replacing it, so the final position stays readable.
- [x] Name the winning player and whether the win was a knockout or an immobilization.
- [x] Offer `Play Again`, wired to the existing `RoundController.restart()`.
- [x] Derive the overlay solely from `snapshot.winner` and `snapshot.winReason`, adding no controller state.
- [x] Assert both win reasons, that the board remains rendered underneath, that input is refused while terminal, and that `Play Again` starts a new round.

### Task 6: Assert the Push Tap Precedence

**Files:**

- Modify: `test/game/view/game_page_test.dart`

- [x] Add a test naming the case where a cell is both an opposing piece and a legal push destination.
- [x] Assert that tapping it applies the push move and never selects the opposing piece.

### Task 7: Verify

- [x] Run `merry run check` and confirm every gate passes, including the 100% coverage gate.
- [x] Confirm no new dependency, no controller method, and no animation controller was introduced.
