<!-- cspell:ignore clippy -->

# Ttush Push Development Guide

## Project Boundaries

- Keep Flutter and Flame gameplay presentation separate from the Rust rules engine in `engine/`.
- Keep `engine/` dependency-free unless a change explicitly requires otherwise.
- Treat board topology and starting layouts as balance configuration rather than invariant game rules.

## Flutter Workflow

Run these checks before delivering Flutter or Dart changes.

```sh
dart format --set-exit-if-changed lib test
flutter analyze
bloc lint .
TMPDIR="$PWD/.tmp/flutter-test" flutter test
TMPDIR="$PWD/.tmp/flutter-test" very_good test --min-coverage 100 --report-on lib
```

Cubit runtime resources belong in state when they must be consumed outside the Cubit.

Do not import Flutter widgets or material libraries from Cubit implementation files.

## Rust Engine Workflow

Run these checks before delivering engine changes.

```sh
rustfmt --check --edition 2024 engine/src/lib.rs engine/src/bin/simulate.rs engine/tests/rules.rs engine/tests/simulation.rs
TMPDIR="$PWD/engine/target/test-tmp" cargo clippy --manifest-path engine/Cargo.toml --all-targets -- -D warnings
TMPDIR="$PWD/engine/target/test-tmp" cargo test --manifest-path engine/Cargo.toml
```

For balance experiments, run the simulator with a fixed seed and compare the complete output across repeated runs.

## Generated and Configuration Files

- Do not hand-edit generated files under `lib/gen/` or `lib/l10n/gen/`.
- Keep CSpell additions scoped to `.cspell/custom-dictionary.txt`.
- Keep repository documentation under `docs/specs/`, `docs/plans/`, or `docs/notes/`.
