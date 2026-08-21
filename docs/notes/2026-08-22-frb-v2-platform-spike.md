# flutter_rust_bridge v2 Platform Spike

## Decision

The first MVP targets Android and iOS only.

Web is deferred to a later milestone.

Do not upgrade `flutter_rust_bridge` to a prerelease or patch generated glue as part of this MVP.

The spike remains time-boxed to five hours.

## Value API

The Rust bridge exposes only value DTOs and synchronous state transitions.

```rust
initial_state() -> GameSnapshot
legal_moves(GameSnapshot) -> Vec<GameMove>
apply_move(GameSnapshot, GameMove) -> GameSnapshot
```

The Flutter `RulesEngine` mirrors those operations without exposing a Rust pointer or opaque handle.

`GameSnapshot` includes the board, pieces, turn, counter-push restriction, outcome, and a deterministic snapshot hash.

The initial snapshot hash is `008d1d43a9eefe72`.

Applying piece `0` down produces `540736b5048c5f9f`.

## Web Result

The local Web build attempt used `flutter_rust_bridge_codegen build-web --rust-root engine`.

Its Wasm output and command log are ignored build products, so the build result is [UNVERIFIED] exact-head review evidence.

The local Chrome integration attempt failed during compilation before the parity test ran.

The tracked generated source contains the same constructor mismatch, but the local command output is not committed as an artifact.

```plaintext
Error: A value of type 'RustLibWire Function()' can't be returned from a function with return type 'RustLibWire Function(ExternalLibrary)'.
```

The failing generated `frb_generated.web.dart` constructor takes no `ExternalLibrary` argument while the 2.12.0 Dart runtime expects one.

`tool/generate_rust_bridge.sh` requires `flutter_rust_bridge_codegen 2.12.0` before generating glue.

The Dart and Rust dependencies are pinned to 2.12.0 in their manifests.

`web: false` records the MVP scope in `flutter_rust_bridge.yaml`.

Version 2.12.0 still emits conditional Web glue even with that setting, so the generated file is retained unmodified and Web builds remain unsupported for this MVP.

## Native Verification Boundary

`cargo test --manifest-path engine/Cargo.toml --test bridge_api` is the reproducible value API parity fixture.

The local iOS attempt reached `simctl install` after Xcode built an untracked `Runner.app` containing `Frameworks/engine.framework/engine`.

That untracked output is link evidence only and is not native parity success.

The iOS runtime parity test is unverified because the local CoreSimulator service stopped responding to `simctl install`.

The Android runtime parity test is unverified because the emulator had 406 MiB free on `/data` and package management could not free the requested space.

An Android package rebuild is also unverified because the current Flutter SDK requires Kotlin 2.2.20 while the project pins 2.2.10, and its Java 25 runtime is incompatible with Gradle 9.0.0.

No simulator reset, emulator cleanup, Kotlin update, Gradle update, or Java toolchain change is included in this spike.

## Re-entry Criteria

Revisit Web only in an explicitly approved dependency update that uses a stable FRB release with compatible generated Web glue.

Rerun the Chrome parity integration test before adding Web back to the MVP target list.
