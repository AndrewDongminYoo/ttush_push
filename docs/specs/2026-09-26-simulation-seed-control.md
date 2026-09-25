# Simulation seat seed control

## Problem and scope

The [baseline opening analysis](../notes/2026-09-26-baseline-opening-analysis.md) found a second-seat Expert self-play signal under one seed schedule.
That sample does not separate seat effects from policy randomness.
Continue [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) with a bounded simulator control, keeping board rules, policies, search budgets, and app behavior unchanged.

## CLI contract

Add the optional presence flag `--swap-seeds`.
It accepts no value and works before, between, or after existing option pairs.
Repeated occurrences enable the same mode; they do not toggle it off.

For round index `i`, first compute `a = seed.wrapping_add(i)` and `b = a.wrapping_mul(0x9e3779b9)`.
Without the flag, initialize First with `a` and Second with `b`, preserving the complete existing output byte for byte.
With the flag, initialize First with `b` and Second with `a`.
Do not recompute the multiplier after swapping, exchange policy names, or change who moves first.
The selected trace must record the actual seeds passed to each policy constructor.

Only swapped runs emit the additional configuration row `seed_assignment=swapped`, immediately after `board=baseline` and before opening rows.
This makes a retained report interpretable even when no trace was requested.
All existing aggregate, opening, and trace fields retain their meaning.

## Acceptance and limits

Use integration tests to replay actual Random policy choices independently for both seats at a nonzero round index, including addition and multiplication wrapping.
At least one fixed fixture must distinguish default and swapped move sequences.
Printed seed checks alone are insufficient: a mutation that preserves correct trace metadata but initializes a policy with the wrong seed must fail the behavioral check.
Verify flag positions, repeatability, explicit swapped-report labeling, unchanged trace-free statistics, and exact parent-output compatibility when the flag is absent.

Run the simulation tests, Rust checks, full repository gate, Markdown spelling, and current-head hosted review and CI.
No visual approval is required for this CLI-only change.
Swapping streams is one sensitivity control, not a symmetric board transformation, identical move sequence, independent extra sample, or causal proof of a rule advantage.
New balance experiments and product board choices remain separate work.
