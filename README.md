# Ttush Push

Ttush Push is a Flutter game project with a dependency-free Rust rules engine for deterministic gameplay experiments.

## Prerequisites

- Flutter 3.44 or later
- Dart 3.12 or later
- Rust toolchain
- iOS 15.0 or later for iOS builds

## Run the Flutter App

```sh
flutter pub get
flutter run --flavor development --target lib/main_development.dart
```

Use the matching `staging` or `production` flavor and entrypoint when required.

## Verify Flutter Changes

```sh
dart format --set-exit-if-changed lib/app lib/bootstrap.dart lib/game test integration_test
flutter analyze
flutter test
trunk check --no-progress
```

## Run the Rules Engine

```sh
cargo test --manifest-path engine/Cargo.toml
TMPDIR="$PWD/engine/target/test-tmp" cargo run --release --manifest-path engine/Cargo.toml -- --games 100000 --seed 42
```

The Rust engine is intentionally independent from Flutter.

## Documentation

- [Rules-engine checkpoint](docs/specs/2026-08-21-rust-engine-checkpoint.md)
- [Implementation plan](docs/plans/2026-08-21-rust-engine-checkpoint.md)
- [Playable round specification](docs/specs/2026-08-22-playable-round-vertical-slice.md)
- [Playable round plan](docs/plans/2026-08-22-playable-round-vertical-slice.md)
