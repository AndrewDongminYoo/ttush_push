# flutter_rust_bridge v2 Platform Spike

<!-- cspell:words Cargokit -->

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

`tool/generate_rust_bridge.sh` requires `flutter_rust_bridge_codegen 2.13.0` before generating glue.

The Dart and Rust dependencies are pinned to 2.13.0 in their manifests.

`web: false` records the MVP scope in `flutter_rust_bridge.yaml`.

Version 2.12.0 still emits conditional Web glue even with that setting, so the generated file is retained unmodified and Web builds remain unsupported for this MVP.

## Native Verification Boundary

`cargo test --manifest-path engine/Cargo.toml --test bridge_api` is the reproducible value API parity fixture.

The iOS parity integration test passed on an iPhone 17 Pro Max simulator with `flutter test integration_test/rules_engine_parity_test.dart -d <simulator-id> --flavor development`.

It initialized the generated iOS Rust library and verified the initial snapshot hash and the hash after applying the same move as the Rust fixture.

Flutter created temporary Xcode, CocoaPods, and Swift Package Manager migrations during that run.
Those generated migrations were reverted after the test, so the tracked iOS project remains unchanged.

The Android debug APK now builds with `flutter build apk --debug --flavor development --target lib/main_development.dart`.

Android parity remains unverified because no Android device is currently connected for the integration test.

The Kotlin Gradle plugin was raised from 2.2.10 to 2.2.20, the minimum accepted by the local Flutter SDK.

The vendored Cargokit Gradle plugin is synchronized to `fzyzcjy/cargokit` commit `8e2cfa1710503b596f1ca552ecb98ad43d71ebef`, which injects `ExecOperations` into `CargoKitBuildTask` instead of calling the removed Gradle 9 `Project.exec()` API.

`tool/verify_cargokit_gradle_plugin.sh` pins that exact upstream plugin blob, and `tool/generate_rust_bridge.sh` runs it after FRB code generation so an incompatible Cargokit regeneration fails loudly.

The local Flutter tool selects Java 25 from Android Studio even when `JAVA_HOME` points to the installed Java 17, and the APK build succeeds without a Java toolchain change.

No emulator cleanup or Java toolchain change is included in this spike.

## Re-entry Criteria

Revisit Web only in an explicitly approved dependency update that uses a stable FRB release with compatible generated Web glue.

Rerun the Chrome parity integration test before adding Web back to the MVP target list.

Connect an Android device, then run the Android parity integration test before treating Android as verified.
