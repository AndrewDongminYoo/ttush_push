# Single Player Specification

## Goal

Let one person play against the engine, choosing how strong an opponent they want, without leaving the board.

## Scope

The second player can be a person or one of the three policies. Tapping the second player's panel cycles through the choices, and the panel says which one is playing.

When the opponent is a policy and it is their turn, the engine chooses and the move is applied. A short pause precedes it so the board does not change while the person is still reading it.

The choice persists across rounds and matches within a session, and can be changed at any point; a policy carries nothing between moves, so switching mid-round is harmless.

## Non-Goals

No menu, no settings screen, and no difficulty stored between launches.

No search-depth control: the three policies are the three strengths, and exposing a depth would be a second axis for a knob nobody has asked for.

No change to the rules, the match contract, or the round screen's existing behaviour. The first player is always the person.

## Architecture

The policies stay in the engine, and the bridge exposes one function over them.

```rust
fn choose_bot_move(snapshot: MatchSnapshot, policy: BotPolicy) -> Result<Option<GameMove>, String>
```

It returns `None` exactly when the round offers no move, which is the same signal `Policy::choose` gives.

**The seed comes from the snapshot, not from Dart.** Passing a fresh seed on each call would make the bot unreproducible, and holding a counter in Dart would put game-relevant state in the presentation layer. The round's own hash is derived by Rust from the position, so the same position always produces the same move, and a bot's mistake can be reported by naming the position it happened in.

The same position recurring within a round would therefore repeat the choice. Measured over 100,000 random games: `repetitions=0`, so this does not arise.

`MatchController` gains the opponent selection and asks the engine for a move when it is the policy's turn. It still holds no rule: which move to play is the engine's answer, and whether a move may be played at all remains the phase's.

The pause before a bot move is pacing, not animation. It delays applying a move the engine has already chosen; it does not interpolate between two states, and nothing about it survives the snapshot replacement.

## Acceptance Criteria

- A person can play a full match against each of the three policies and see which one they chose.
- The opponent selection is visible on the board without opening anything.
- A bot move is applied only on the bot's turn, and only while the phase accepts moves.
- The same position and policy produce the same move.
- Switching the opponent mid-round neither breaks the round nor loses the score.
- A bridge failure during a bot move leaves the board as it was, with a retry, exactly as a human move does.
- Every branch is covered, and `merry run check` passes.
