# Bounded opening analysis protocol

## Question and scope

Can the existing simulator replay Expert in either seat and expose which first moves occur and what follows them?
This protocol validates that measurement path before drawing balance conclusions under [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67).
The human evidence and product decision remain in [#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42).

Use `strategic` for the app's Expert policy and `minimax:2` for Hard.
Both policies are the existing engine implementations; this change introduces no alternative AI.
Each CLI game is one round, not a best-of-three match.
The first seat always moves first.
The initial board comes from `GameState::baseline()` and is reported as `board=baseline`.

## Reproduce a bounded run

Run from the repository root on a clean checkout of the revision under analysis.
Save the revision, any diff, toolchain, command, and complete standard output together.
A source revision alone does not describe a dirty working tree.
Stop if the status contains any changes, including untracked files; commit the intended experiment inputs before collecting evidence with this protocol.
The diff command is diagnostic and does not preserve untracked file contents.

```sh
git rev-parse HEAD
git status --short
git diff HEAD
if [ -n "$(git status --porcelain)" ]; then
  printf '%s\n' 'Stop: a clean checkout is required for recorded experiments.' >&2
  exit 1
fi
rustc --version
cargo build --release --locked --manifest-path engine/Cargo.toml --bin simulate
engine/target/release/simulate --games 4 --seed 42 --max-turns 100 --first strategic --second minimax:2
engine/target/release/simulate --games 4 --seed 42 --max-turns 100 --first minimax:2 --second strategic
engine/target/release/simulate --games 4 --seed 42 --max-turns 100 --first strategic --second strategic
```

Repeat each command and compare its entire output byte for byte.
Four rounds per configuration are a measurement smoke test, not a balance sample.
The two seat orders use the existing simulator's seed schedule: First receives `seed + game_index`; Second receives `(seed + game_index) * 0x9e3779b9`, with wrapping unsigned arithmetic.
Seat reversal therefore is not an identical random-stream pairing.

Strategic uses its existing deterministic node budget: a base of 18,000 nodes scaled by the current number of tiles and pieces, with one more than the legal root-move count as a lower bound.
The budget is derived from board state and capped at the base before applying that lower bound; it is not a wall-clock timeout or a fixed search depth.
The exact implementation is in `engine/src/bot/strategic.rs`; record the source revision with the results instead of assuming this description applies to future revisions.
The CLI's `--max-turns` caps round length and does not change that per-move budget.

## Interpret the report

The original aggregate keys remain available.
Opening rows group rounds by the first move's piece ID and direction, preserving orientation rather than merging symmetric moves.
Each group reports its frequency, seat wins, termination causes, total turns, and maximum observed turns.
Rows use `opening.<piece_id>.<direction>.<statistic>=<integer>`, ordered by numeric piece ID and then the lowercase direction label.
For example, `opening.0.down.games=3` means three sampled rounds started by moving piece 0 down.
The example illustrates the format and is not an experiment result.
For every additive statistic, summing the opening rows must equal the aggregate value.
For maximum turns, take the maximum across groups instead of their sum.

`turn_limits` records rounds censored by the configured cap.
`repetitions` records a repeated complete engine state detected by the harness.
Neither counter proves a game-theoretic draw.
Win rates and opening frequencies are conditional on these policies, budgets, board, and seeds.
A frequent opening or a short winning continuation is not proof of a forced line.

## Inspect one sampled continuation

Use the same clean-checkout and source-provenance checks above before recording a trace.
Add `--trace-game` to select one zero-based round index within the requested batch.
For example, this traces the second round and retains statistics for all three rounds:

```sh
engine/target/release/simulate --games 3 --seed 18 --max-turns 100 --first random --second strategic --trace-game 1
```

Repeat the command to check the complete output byte for byte.
The trace is appended after the existing report; omitting `--trace-game` preserves the old output.
`trace.game_index` identifies the round, and `trace.first_seed` and `trace.second_seed` record the actual policy seeds after unsigned wrapping.
Moves appear as contiguous one-based `trace.move.<n>.player`, `.piece`, and `.direction` entries.
They are the moves the simulation applied, not a second policy search performed for reporting.
Replay them from `GameState::baseline()` through `apply_move`, checking the acting player before each move and `outcome` at the end.
The CLI integration tests exercise that engine replay contract.

`trace.turns` counts applied moves.
`trace.termination` distinguishes `knockout`, `immobilization`, `turn_limit`, `repetition`, and the unexpected `policy_none` exit.
`trace.winner` is `first` or `second` only for an observed win and is `none` otherwise.
A win on the last allowed move remains a win; a shorter cap may censor the same continuation.
The parent report's policies, board, and cap and the source revision above remain part of the trace's interpretation.

This is one sampled continuation, not a search tree or a certificate that every reply loses.
Use it to identify positions for separate analysis; do not label a short trace a forced win or an unfinished trace a draw.
No trace is emitted for other rounds, and only the selected round's move history is retained.

## Remaining analysis

The [2026-09-26 baseline opening analysis](2026-09-26-baseline-opening-analysis.md) records a bounded Expert/Hard seat reversal and Expert self-play experiment, including reproducible outputs and its limitations.

The historical 100,000-round random-policy baseline in `docs/specs/2026-08-22-bot-policies.md` remains historical evidence for that engine revision.
Do not relabel it as Expert data or compare revisions without noting rule and policy differences.
Before increasing the workload, choose a specific hypothesis and a sampling budget.
Board variants without duplicated production configuration, representative forced lines, and exhaustive initial-position analysis remain open in #67.
Keep rule or board changes dependent on that evidence and the human playtest; this reporting change makes no balance recommendation.
