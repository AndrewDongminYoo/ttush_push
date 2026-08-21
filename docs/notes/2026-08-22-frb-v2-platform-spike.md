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

`flutter_rust_bridge_codegen build-web --rust-root engine` completed and produced the Wasm package.

Chrome integration compilation then failed before the parity test ran.

```plaintext
Error: A value of type 'RustLibWire Function()' can't be returned from a function with return type 'RustLibWire Function(ExternalLibrary)'.
```

The failing generated `frb_generated.web.dart` constructor takes no `ExternalLibrary` argument while the 2.12.0 Dart runtime expects one.

Both the code generator and Dart dependency were pinned to 2.12.0.

`web: false` records the MVP scope in `flutter_rust_bridge.yaml`.

Version 2.12.0 still emits conditional Web glue even with that setting, so the generated file is retained unmodified and Web builds remain unsupported for this MVP.

## Native Verification Boundary

`cargo test --manifest-path engine/Cargo.toml --test bridge_api` passed the value API parity fixture.

The iOS development build produced `Runner.app` containing `Frameworks/engine.framework/engine`.

The iOS runtime test could not install because the local CoreSimulator service stopped responding to `simctl install`.

The Android runtime test could not install because the emulator had 406 MiB free on `/data` and package management could not free the requested space.

An Android package rebuild was also blocked before FRB compilation because the current Flutter SDK requires Kotlin 2.2.20 while the project pins 2.2.10, and its Java 25 runtime is incompatible with Gradle 9.0.0.

No simulator reset, emulator cleanup, Kotlin update, Gradle update, or Java toolchain change is included in this spike.

## Re-entry Criteria

Revisit Web only in an explicitly approved dependency update that uses a stable FRB release with compatible generated Web glue.

Rerun the Chrome parity integration test before adding Web back to the MVP target list.
