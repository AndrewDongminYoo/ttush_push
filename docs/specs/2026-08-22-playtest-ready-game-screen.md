# Playtest-Ready Game Screen Specification

## Goal

Make the board legible to someone opening the app for the first time.
Without being told the rules, they should immediately see whose turn it is, which piece is selected, where it can go, which footholds are dangerous, and who won and why.

This milestone exists to make a playtest possible, not to settle the art direction.
A deliberate prototype visual, one step above grey boxes and circles, is the target.

## Scope

The game screen becomes a full-screen layout rather than an `AppBar`-centered development screen.
A player panel sits above and below the board, one per player, each showing that player's identity and whether the turn is theirs.
The board is the dominant visual element and keeps a stable square layout on both small and large screens.

Tiles are distinguished by shape as well as color.
A `Normal` tile reads as an intact foothold.
A `Damaged` tile carries a visible crack, so that "one more departure removes this" is readable without a legend.
A `Hole` reads as absent floor rather than as a differently colored tile.

The two players' pieces carry distinct visual identities beyond hue alone.
The selected piece is unmistakably marked.
Legal destinations for the selected piece are marked, and a destination that would push an opposing piece is marked differently from an ordinary move, so the two cannot be confused.

When the snapshot is terminal, a result overlay above the board names the winning player and whether the win was a knockout or an immobilization, and offers `Play Again` for an immediate restart.

## Non-Goals

This milestone adds no animation, no transition model, and no presentation state that outlives a snapshot replacement.
It adds no Flame, final character art, sound, best-of-three progression, online play, accounts, rankings, bot UI, settings screen, or main menu.
It does not change the Rust rules, the value-based bridge API, or generated `flutter_rust_bridge` code.
It does not add a package dependency.

Animation is deliberately deferred to the next milestone.
Interpreting what happened between snapshot A and snapshot B would require a Flutter layer that re-derives rule meaning from a diff, which is exactly the boundary this project protects.
State transitions in this milestone are immediate, and whether that is too abrupt is a question for the playtest to answer.

## Architecture

Rust remains the sole rules authority through the existing value-based interface.
`RoundController` keeps its current responsibilities unchanged: it is plain Dart, owns the snapshot, selection, legal moves, and recoverable error state, and calculates no rule.

All new work is presentation.
`RoundBoard` gains the tile shapes, piece identities, and destination affordances; `GamePage` gains the full-screen layout, player panels, and result overlay.

### The push affordance boundary

Distinguishing a push destination from an ordinary move destination is a read of snapshot state, not a rule computation.

- A legal destination that is occupied by any piece in the current snapshot renders with the push affordance.
- A legal destination that is empty renders with the move affordance.

Occupancy comes from `snapshot.pieces`, and legality comes only from `RulesEngine.legalMoves`.
Flutter must not compute what the push does: not where the pushed piece lands, not how far a push chain travels, not whether the pushed piece falls, and not whether the push is blocked.
If a destination is unreachable for any reason, including the immediate counter-push restriction, it is simply absent from `legalMoves` and therefore unmarked.

The functions listed in `CLAUDE.md` remain forbidden in Dart.
Reading "is this cell occupied right now" is permitted; deciding "may this piece push" is not.

### Layout contract

The screen is a vertical stack of a top player panel, the board, and a bottom player panel.
The board keeps its existing `LayoutBuilder` behavior of centering a square derived from the smaller constraint axis, and renders nothing when that constraint is not finite or positive.
A short screen therefore shrinks the board rather than clipping or scrolling it.

The board takes most of the vertical space and the panels share what is left.
On a tall screen the board is bounded by the screen width, so the surplus height goes to the panels rather than to empty background, which makes the active player's color readable from further away.
Text inside a panel and inside the result overlay must flex rather than size itself first, because at 320pt neither fits its row otherwise.

The top panel represents the first player and the bottom panel the second, following the engine's starting layout, which places the first player's pieces on row 0 and the second player's on row 4.
Each player therefore sits behind their own pieces rather than opposite them.

### Result overlay

The overlay is drawn above the board rather than replacing it, so the final position stays visible while the result is read.
It contains the winning player, the win reason, and the `Play Again` control, which calls the existing `RoundController.restart()`.
No new controller state is introduced for it: the overlay is a function of `snapshot.winner` and `snapshot.winReason`.

## Interaction Contract

The existing interaction contract from the playable-round slice continues to hold unchanged.

One case becomes load-bearing that previously was not.
A cell can now be simultaneously occupied by an opposing piece and marked as a legal push destination, and the screen actively advertises that.
Tapping such a cell applies the push move; it never attempts to select the opposing piece.
Destination resolution therefore precedes piece selection in tap handling, and that precedence is asserted by a test that names the push case.

After a terminal snapshot, the board accepts no move input, and the only available action is `Play Again`.

## Acceptance Criteria

- A person who has never seen the rules can identify the current player, the selected piece, its destinations, and the damaged tiles from the screen alone.
- A legal destination occupied by an opposing piece is visually distinct from an empty legal destination, and tapping it applies the push move.
- `Normal`, `Damaged`, and `Hole` tiles are distinguishable without relying on color alone.
- A terminal snapshot shows the winner and the win reason over the final board, and `Play Again` starts a new round.
- The 5-by-5 board stays square and fully visible on both a small and a large screen.
- No presentation state survives a snapshot replacement, and no animation controller is introduced.
- Every new painter and layout branch is covered, and `merry run check` passes.
