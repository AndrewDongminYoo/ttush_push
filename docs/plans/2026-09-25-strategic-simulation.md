# Strategic simulation implementation

## Scope and ownership

The implementation worker owns `engine/src/bin/simulate.rs`, `engine/tests/simulation.rs`, and read-only accessors in the `Move` implementation in `engine/src/lib.rs` only.
The root owns this plan, the matching specification, the experiment note, Git operations, and final verification.
All work uses the current workspace and the `codex/strategic-simulation` branch.

## Steps

1. Add integration tests for Strategic in either seat and self-play, deterministic opening reports, and accounting across completed and capped rounds.
   Verify: run `cargo test --manifest-path engine/Cargo.toml --test simulation` and record failures caused by the missing behavior before implementation.
2. Add the existing policy to the CLI and accumulate sorted first-move statistics without modifying engine rules or search.
   Verify: the targeted suite and `cargo test --manifest-path engine/Cargo.toml` pass; inspect policy dispatch and preserve existing aggregate behavior.
3. Document a bounded, reproducible experiment and its interpretation limits.
   Verify: run a small CLI sample in both seat orders and self-play; compare repeated output and record the observed result without claiming balance proof.
4. Run the complete local gate and Markdown spelling check, then independently review the candidate.
   Verify: record `merry run check`, `npx cspell lint --config cspell.json --gitignore-root . '**/*.md'`, and dispositions for blocking findings; repair only scoped defects.
5. Commit, push, open a PR referencing #67, and complete current-head hosted review and CI.
   Verify: exact head, passing applicable checks, required reviewer signals, and no unresolved review threads before requesting operator merge.

## Constraints

Do not close #67; its broader analysis and human-playtest dependency remain open.
Use no new dependency, generated-code edit, mobile runtime write, or board data copy.
Keep search experiments small; the existing 100,000-round random baseline is historical evidence, not a requirement to run 100,000 Expert games.
