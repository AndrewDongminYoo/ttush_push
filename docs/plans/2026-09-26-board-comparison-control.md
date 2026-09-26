# Board comparison execution plan

## Approved direction

Implement the [contract](../specs/2026-09-26-board-comparison-control.md) in the existing workspace on `codex/board-comparison-control`.
Root owns integration, commits, experiment collection, and PR readiness.
No separate checkout is required.

## Sequence and ownership

1. Reconcile verified post-merge drift in the current status note and GitHub #67, #74, and #81.
   Preserve historical evidence and incomplete acceptance criteria.
   Verify scoped Markdown, links, and issue read-back; keep one semantic documentation commit.
2. Add failing Rust CLI tests, then implement a strict offline board-file reader and `--board-file` dispatch.
   Worker ownership: `engine/src/bin/simulate.rs`, `engine/src/bin/simulate/board.rs`, and `engine/tests/simulation.rs` only.
3. Add the Dart catalog exporter and its tests; extend host acceptance to compare parsed initial states and replay traces through the app bridge.
   Root ownership: `tool/export_simulation_boards.dart`, `test/tool/export_simulation_boards_test.dart`, `tool/rules_engine_host_test.dart`, `merry.yaml`, `.github/workflows/main.yaml`, and task documentation.
4. Run focused regressions, `flutter analyze`, scoped `dart format`, Rust checks, the full local gate, and independent read-only reviews of CLI behavior and cross-runtime/experiment evidence.
5. Commit the implementation and frozen experiment declaration before collecting data.
   Verify clean tracked/untracked source, build the release simulator, export fresh inputs, run the declared pilot and conditions sequentially, and verify full repeats and report accounting.
6. Record results under `docs/notes/2026-09-26-board-comparison-control.md` with a provenance directory, clarify remaining #67 work, validate documentation, and commit the evidence.
7. Push the scoped branch, open a PR, complete current-head CI and hosted review, then ask the operator to merge.

## Verification limits

Host bridge/CLI tests verify configuration transport and trace agreement, not native packaging or human enjoyment.
No mobile runner, app presentation, or bridge schema changes are planned.
Document native parity skips accurately.
The experiment is small, dependent, and policy-specific; a winning trace does not prove all alternative replies lose.
