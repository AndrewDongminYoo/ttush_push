# Strategic simulation reporting

## Problem

[Issue #67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) requires opening-bias analysis, but the simulation CLI cannot select the Strategic policy used by the app's Expert opponent.
Its aggregate results also hide which first moves produced those outcomes.

## Contract

- Accept `strategic` in both `--first` and `--second`, using the existing `StrategicBot` and its deterministic search budget without changing the policy.
- Preserve existing policy names, defaults, seed derivation, and aggregate statistic keys.
- Report the existing Rust baseline board as `board=baseline`; do not copy its cells or pieces into the CLI.
- Append deterministic opening rows grouped by the first move's piece ID and direction.
  Each row records games, first- and second-seat wins, termination causes, total turns, and maximum turns.
  Sum each additive opening field to the corresponding aggregate field.
- Repeated invocations of the same binary and arguments produce byte-identical output.
- Document commands that capture source revision, working-tree changes, policies, seed, and turn cap, including both seat orders and self-play.

## Boundaries

This is the first implementation slice of #67, not completion of the analysis issue.
It does not change rules, AI strength, bridge APIs, app UI, or dependencies.
Read-only `Move` accessors expose its existing piece ID and direction for reporting; existing constructors and behavior remain unchanged.
Board variants, multi-move opening trees, representative forced-line analysis, exhaustive initial-position proof, and synthesis with the human playtest remain follow-up work.
A turn cap is a censored simulation result, not proof of a draw.
Opening frequencies describe the selected policies and seeds, not optimal-play probabilities.
No operator visual approval is needed for this CLI and documentation change.

## Acceptance

CLI integration tests must reject the old implementation and verify actual Strategic selection, repeatability, opening grouping, and outcome/turn accounting.
Run the engine suite and the repository's declared local gate before publication.
Review the diff for accidental public API or rule changes and keep #67 open in the PR description.
