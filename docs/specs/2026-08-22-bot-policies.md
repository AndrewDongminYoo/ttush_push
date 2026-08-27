# Bot Policies Specification

## Goal

Give the engine a way to choose a move, so a person can play against the machine and so balance experiments can pit one way of playing against another.

## Scope

Three policies, each understandable on its own, in increasing order of strength.

- **Random** picks uniformly among the legal moves.
- **Greedy** takes a move that wins the round outright; failing that, it avoids moves that let the opponent win on their reply; failing that, it picks among what is left.
- **Minimax** searches to a fixed depth and scores the leaves.

The simulator gains a policy per side, so a run can measure one policy against another rather than only random against random.

Every policy is deterministic given its seed. A bot that cannot be replayed cannot have its mistakes reported.

## Non-Goals

A policy chooses within a round. It sees `GameState`, never `MatchState`, and knows nothing of the score: a match is a sequence of rounds, and making a bot play differently when behind is a personality, not a strategy, and is not wanted here.

No opening book, no learned weights, no time-based search budget, and no policy that reads or writes anything outside the state it is given.

Alpha-beta pruning and a transposition table are deferred until a depth is wanted that plain search cannot reach in time. The measurement that would justify them is stated below rather than assumed.

## Why the search terminates

A move damages the tile it leaves, and a damaged tile becomes a hole; tiles never heal. The board therefore degrades monotonically, and a round cannot continue indefinitely.

Measured over 100,000 random games at seed 42: `repetitions=0`, `turn_limits=0`, `max_observed_turns=47`, `mean_turns=29.655`. No game repeated a position or reached the 10,000-turn limit.

A depth-limited search therefore needs no repetition detection, and 47 is the observed ceiling a full search would have to reach.

## Architecture

The policies live in the engine, beside the rules they consult, for two reasons. A search evaluates thousands of positions per move, which no value bridge should carry. And the simulator is already the place balance is measured, so a policy it can select is worth more than one only the app can reach.

```rust
pub trait Policy {
    fn choose(&mut self, state: &GameState) -> Option<Move>;
}
```

`choose` returns `None` exactly when there is no legal move, which is the engine's own signal that the round is over. A policy never inspects `outcome` to decide whether to play.

The xorshift generator currently private to `simulate.rs` moves into the library, so the simulator and the policies share one definition rather than growing a second.

### What Greedy does, stated exactly

For each legal move, apply it and read the result:

1. If the round is won by the player to move, take that move.
2. Otherwise, apply each of the opponent's replies; if any wins for them, the move is losing.
3. Choose among the non-losing moves, or among all of them when every move loses.

This is one ply of lookahead, entirely within the engine. It is deliberately not written as a special case of the search: the point of Greedy is that its reasoning can be read off in three lines.

### What Minimax scores

Terminal positions score as a win or a loss, adjusted by depth so a faster win outranks a slower one and a delayed loss outranks an immediate one.
The depth term is the search budget still unspent, so a round that ended sooner carries a larger one and the adjustment is added rather than subtracted.
That ordering is asserted on its own rather than through play, because neither channel that found the first polarity bug can see this one: the knockout fixture offers a single winning line, so no two wins at different depths ever compete, and at the depth the app actually runs every mover-win sits at the same depth as every other.
It was shipped inverted and caught in review.

Non-terminal leaves score on mobility alone. Material is deliberately absent: a knockout ends the round outright, so in any position still being played both sides hold every piece they started with and a material term could only ever be zero. Mobility is what varies, and running the opponent out of moves is the other way a round is won.

## Acceptance Criteria

- Each policy returns only legal moves, and `None` only when none exist.
- The same seed and the same position produce the same move, for every policy.
- Greedy takes a winning move when one exists, and declines a move that hands the opponent a win when an alternative exists.
- Minimax at depth 2 or more never plays a move that loses immediately when an alternative exists.
- The simulator accepts a policy per side and reports the result, so the policies can be ranked against each other by measurement rather than by assertion.
- Each policy beats the one below it from both seats, asserted by playing rounds rather than by inspecting code.
- `merry run check` passes.

## Measured

Recorded pairings at seed 42 use 2,000 games for the first three rows and 500 games for the minimax rows:

| First     | Second    | Games | First wins | Second wins | Mean turns |
| --------- | --------- | ----- | ---------- | ----------- | ---------- |
| random    | random    | 2,000 | 980        | 1,020       | 29.9       |
| greedy    | random    | 2,000 | 1,750      | 250         | 26.7       |
| random    | greedy    | 2,000 | 222        | 1,778       | 26.4       |
| minimax:2 | random    | 500   | 488        | 12          | 20.6       |
| minimax:2 | greedy    | 500   | 365        | 135         | 34.4       |
| greedy    | minimax:2 | 500   | 107        | 393         | 33.4       |

The ordering holds from either seat, so it reflects the policies rather than a first-move advantage — random against random is 49% / 51%, which is the baseline that makes the rest readable.

This measurement is what found the search bug the unit tests could not: a minimax that minimized where it should maximize still took a winning move and still avoided an immediate loss, because both are decided by terminal scores, and it showed up only as losing to greedy 37% / 41%. The ranking is asserted in the tests for that reason.

Alpha-beta and a transposition table are still deferred. Depth 2 already beats greedy from both seats, and nothing yet asks for a depth that plain search cannot reach.
