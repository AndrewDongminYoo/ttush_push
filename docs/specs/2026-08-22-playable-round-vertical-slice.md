# Playable Round Vertical Slice Specification

## Goal

Deliver one locally playable 5-by-5 round in Flutter.
Two people sharing a device can select their pieces, take legal turns, see the board change, reach a Rust-determined winner, and restart a fresh round.

## Scope

The app opens directly to the playable round board after Rust bridge initialization.
The board renders the complete `GameSnapshot` returned by `RulesEngine.initialState()`.
The active player can select one of their pieces and see destinations derived from `RulesEngine.legalMoves(snapshot)`.
Tapping a highlighted destination applies its corresponding `GameMove` through `RulesEngine.applyMove(snapshot, move)`.
The returned snapshot replaces the displayed state atomically.
The board visibly distinguishes `Normal`, `Damaged`, and `Hole` tiles.
The board visibly distinguishes the two players' pieces.
The UI reflects a push solely from the returned piece positions and tile states.
The UI must not calculate push destinations, tile damage, counter-push legality, knockout, or immobilization itself.
The UI shows the active player while a round is ongoing.
When the snapshot contains both `winner` and `winReason`, the UI shows the winning player and reason and offers a restart control.
Restart creates a new round by calling `RulesEngine.initialState()`.

## Non-Goals

This slice is one round only.
It does not expose the engine's `MatchState`, match scoring, or best-of-three progression.
It does not add Flame, online play, matchmaking, accounts, rankings, sound polish, complex animation, or a Web target.
It does not change the Rust rules, the value-based bridge API, or generated flutter_rust_bridge code.
It does not add a package dependency.

## Architecture

Rust remains the sole rules authority through this existing value-based interface.

```dart
abstract interface class RulesEngine {
  GameSnapshot initialState();
  List<GameMove> legalMoves(GameSnapshot state);
  GameSnapshot applyMove(GameSnapshot state, GameMove move);
}
```

Flutter owns presentation, local input state, and error display only.
A plain Dart `RoundController` owns the current snapshot, the currently selected piece identifier, the legal moves for that snapshot, and any recoverable bridge error.
It receives a `RulesEngine` instance so widget and controller tests can supply a deterministic fake without a native library.
It clears the selection after each accepted move and refreshes legal moves from the snapshot returned by Rust.
It does not duplicate any game rule or mutate snapshot value objects.
An unexpected bridge error leaves the last valid snapshot visible and presents a recoverable error message.

`GamePage` is a Flutter `StatefulWidget` that observes the controller and is responsible for layout and interaction wiring.
A `CustomPainter` is sufficient for the 5-by-5 board because it needs only tile, piece, selection, and legal-destination rendering.
No Flame game loop, component tree, asset preload, or audio state is retained.

## Interaction Contract

Tapping a piece owned by the current player selects it when it has at least one legal move.
Selecting a piece highlights the adjacent destination of each legal move for that piece.
Tapping a highlighted destination applies exactly the matching legal move.
Tapping another selectable current-player piece changes the selection.
Tapping elsewhere clears the selection and does not call the engine.
Opponent pieces are never selectable during the other player's turn.
The immediate counter-push restriction is represented by the absence of that move from `legalMoves`, so its destination is not highlighted and cannot be applied.
After a terminal snapshot, the board accepts no move input until restart.

## Template Removal

The Flame template implementation, its preload screen, audio cubit, audio assets, image assets, and their tests are removed when they are no longer referenced.
The Bloc template implementation and its tests are removed with those screens because this slice uses the plain Dart controller described above.
Unused Flame, audio, Bloc, and test-only packages are removed from `pubspec.yaml`, and `pubspec.lock` is regenerated with `flutter pub get` in the same change.
The FlutterGen asset output is regenerated from the edited asset declarations rather than edited directly.
The app continues to initialize `RustLib` before rendering the round board.
The workflow's Bloc lint invocation is removed or disabled only after no Bloc source, tests, or tooling remain.

## Native Runtime Parity Smoke Test

The integration test uses this fixed value-only sequence.

```plaintext
initialState()
applyMove(piece 0, Down)
applyMove(piece 2, Up)
applyMove(piece 0, Down)
applyMove(piece 2, Up)
```

The last move pushes piece 0 and creates the immediate counter-push restriction from piece 2 to piece 0.
The final snapshot hash is `7044880ea390e9a8`.
The test also verifies that piece 0 cannot immediately move `Down` to counter-push piece 2.
The same test must pass against the fixed expected hash on iOS and an Android Emulator, proving that the native process on each platform executes the same Rust value API.
This is a bridge smoke test, not a UI automation test.
Android Emulator verification is required for this milestone.
A physical Android-device run is deferred until hardware is available.
Web remains out of the MVP until a later, separately scoped bridge validation.

## Acceptance Criteria

- A person can complete a local round from the initial board to a knockout or immobilization result and start another round.
- Every board state after an accepted action is a `GameSnapshot` returned by Rust.
- Current-player selection, legal destinations, push outcomes, tile degradation, counter-push prevention, terminal state, and restart are covered by controller or widget tests.
- The native parity integration test passes on iOS and an Android Emulator with final hash `7044880ea390e9a8`.
- No active app source depends on Flame, Flame Audio, audioplayers, Bloc, flutter_bloc, or their template-specific test tooling.
- The CI configuration no longer invokes Bloc lint after its tooling is removed.
- `dart format --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, `cargo test -p engine`, and the project quality gate pass.
