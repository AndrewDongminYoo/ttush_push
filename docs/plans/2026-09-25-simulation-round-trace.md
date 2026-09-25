# Simulation round trace implementation

## Contract and ownership

Follow [the trace specification](../specs/2026-09-25-simulation-round-trace.md), a bounded continuation of [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67).
Base revision: `4efdb2a897f15b74afae3546ab3ac80e3b5161a3`.
Use the current workspace.
The implementation worker owns only `engine/src/bin/simulate.rs` and `engine/tests/simulation.rs`.
The root owns the specification, this plan, `docs/notes/2026-09-25-strategic-simulation-protocol.md`, verification, staging, commits, and hosted review.
Read-only contract review confirmed that existing Move accessors and engine replay are sufficient.
Oracle found no relevant indexed precedent for simulation or forced lines; that result does not substitute for source verification.

## Steps and verification

1. Capture existing full output for representative default, Strategic, and wrapping-seed runs before implementation.
   Verify: retain arguments, parent SHA, and stdout in Git-local task evidence for exact comparison.
2. Add focused integration tests first.
   Verify: a valid trace request fails on the old CLI with an unknown-argument diagnostic; failed compilation does not count as the intended red result.
3. Implement optional selected-round capture and printing without changing policy dispatch or the untraced report.
   Verify: integration tests replay a full terminal path, distinguish cap outcomes, select a nonzero index with wrapping seeds, and reject malformed options.
4. Extend the existing protocol with trace reproduction and interpretation.
   Verify: a bounded release-binary trace repeats byte for byte, recorded moves replay to the reported result, and untraced outputs match the saved parent outputs.
5. Run local gates and one independent adversarial review.
   Verify: Rust formatting, all-target Clippy, Rust tests, and the declared local gate pass; Markdown spelling passes; review checks compatibility and evidence limits.
   Run mobile work sequentially after checking machine load.
6. Create one coherent feature commit and PR, then complete current-head CI and hosted review.
   Verify: no unresolved findings before requesting operator merge; keep #67 open because the analysis and external-play criteria remain incomplete.

## Constraints

No board product choice, solver, generated code, dependency, UI, or persistence change belongs to this slice.
Do not describe sampled traces as forced wins or capped rounds as draws.
Historical sample counts and prior test runs retain their source revisions.
