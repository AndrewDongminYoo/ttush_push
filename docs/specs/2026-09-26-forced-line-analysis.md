# Bounded alternative-reply analysis

## Approved question

Continue [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) after the [four-board comparison](../notes/2026-09-26-board-comparison-control.md).
For selected reachable positions, can one player force a round win against every reply within a declared bound?
Keep the rules, app, bridge, board defaults, bot policies, dependencies, and public engine API unchanged.

## Offline contract

Add an `analyze` Rust binary that reuses the simulator board-file reader.
Require `--board-file`, `--moves-file`, `--depth`, and `--nodes` exactly once.
The move file starts with `ttush-moves-v1`, followed by `move <first|second> <piece-id> <up|down|left|right>` rows.
An empty path represents the initial First-to-move state.
Replay every row through the real engine, checking the recorded actor and rejecting illegal or post-terminal moves before printing any report.
Limits are depth 1 through 32 and 1 through 1,000,000 visited states per root alternative.
Each alternative gets its own equal node budget; the declared depth includes that root move.
Print the board identity and initial configuration, path length, current actor, bounds, every legal root alternative and its result, consumed nodes and cutoffs, and the resulting position classification.
Terminal input positions report their actual winner and no alternatives.

Search uses terminal outcomes only, without heuristic scores, randomness, cache, or the Strategic policy.
A position is a proven win for its mover if at least one child is proved for that mover.
It is a proven loss only if every legal child is proved for the opponent.
Otherwise it is unknown.
Terminal inspection consumes a node and precedes the depth cutoff; an exhausted node budget yields unknown even for a terminal that has not been inspected.
Early stopping after a winning child is logically sufficient, but all root alternatives must still receive a report.
A depth or node cutoff never implies a draw or loss.
A proven result certifies a winning strategy within the examined tree under the current rules, not an optimal distance or an exhaustive initial-position solution.
Report rows are summaries, not portable proof certificates.

## Acceptance

1. Observe failing behavior before implementation for reachable forced wins, forced losses, depth/node cutoffs, and malformed input.
2. Compare a small solved fixture with the independent exhaustive test solver and validate each root alternative.
3. A mutation that ignores an unknown opponent reply must fail a regression.
4. Preserve the default simulator output; all existing tests and `CARGO_BUILD_JOBS=2 merry run check` must pass.
5. Record source, binary and input hashes, declared selection, exact commands, complete output repeats, and explicit unresolved positions.

## Frozen selection and bounds

Use the four committed seed-42 default canonical traces from the prior comparison and their exact `.board` inputs.
For each board, analyze prefixes at 0 moves, 8 moves before the recorded terminal, and 4 moves before it: twelve positions selected before running the new solver.
Use depth 8 and 100,000 nodes per root alternative, with a process timeout of 120 seconds.
Repeat every command once and require byte-identical output.
If any command exceeds the timeout, stop that collection and report the constraint without changing its declared bounds.
Do not rerun Strategic self-play or count these selected suffixes as new independent games.
Validate each complete source trace against the engine and its recorded terminal before extracting the prefixes.
This is an endgame and unresolved-opening investigation, not a frequency estimate or evidence of human enjoyment.
Keep #67 open for unresolved initial positions and synthesis with #42.

## Precedent

Personal Oracle queries `forced line` and `simulation` returned `[no precedent found]` at provider revision `c1681868ac634e4b2414874716bb75a7864113c4`.
The current project memory's simulation-policy-observability guidance distinguishes real behavioral readers, repeatability, and sampled traces from proofs.
