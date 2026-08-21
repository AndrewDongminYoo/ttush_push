# Ttush Push

Ttush Push is a Flutter and Flame game project with a dependency-free Rust rules engine for deterministic gameplay experiments.

## Prerequisites

- Flutter 3.44 or later
- Dart 3.12 or later
- Rust toolchain

## Run the Flutter App

```sh
flutter pub get
flutter run --flavor development --target lib/main_development.dart
```

Use the matching `staging` or `production` flavor and entrypoint when required.

## Verify Flutter Changes

```sh
dart format --set-exit-if-changed lib test
flutter analyze
bloc lint .
TMPDIR="$PWD/.tmp/flutter-test" flutter test
TMPDIR="$PWD/.tmp/flutter-test" very_good test --min-coverage 100 --report-on lib
```

The temporary directory keeps local Flutter test artifacts off the low-space system volume.

## Run the Rules Engine

```sh
rustfmt --check --edition 2024 engine/src/lib.rs engine/src/bin/simulate.rs engine/tests/rules.rs engine/tests/simulation.rs
TMPDIR="$PWD/engine/target/test-tmp" cargo test --manifest-path engine/Cargo.toml
TMPDIR="$PWD/engine/target/test-tmp" cargo run --release --manifest-path engine/Cargo.toml -- --games 100000 --seed 42
```

The Rust engine is intentionally independent from Flutter and Flame.

## Documentation

- [Rules-engine checkpoint](docs/specs/2026-08-21-rust-engine-checkpoint.md)
- [Implementation plan](docs/plans/2026-08-21-rust-engine-checkpoint.md)
