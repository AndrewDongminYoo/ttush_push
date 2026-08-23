<!-- cspell:ignore clippy hotseat -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Every command string lives in `merry.yaml`. Run `merry ls` for the current list and `merry run <name> <subname>` to execute one, rather than restating a command here.
Note that the CLI separates nested names with a space, while the config file references them as `$rust:test`.

`merry run check` is the full local gate before committing, and it adds `trunk check`, which CI does not run.
It does not stand in for the whole of CI. The `spell-check` job reads every `**/*.md` through `cspell.json`, and no local linter does: `trunk check` looks only at modified files and has no cspell among its enabled linters. Run `npx cspell --config cspell.json '**/*.md'` after touching any markdown. The `semantic-pull-request` job reads the PR title and has no local form at all.

Two things the script list does not tell you:

- `merry run format` rewrites Dart sources, while `merry run format check` only fails on drift. The same pair exists under `merry run rust format`.
- `merry run` does not forward extra arguments, so anything that takes a target is invoked directly:

```sh
flutter test test/game/match/match_controller_test.dart
cargo test --manifest-path engine/Cargo.toml counter_push
flutter test integration_test/rules_engine_parity_test.dart -d <device-id> --flavor development
```

The parity integration test is the accepted native evidence: the same Rust-owned snapshot hash must appear on both an Android and an iOS runtime.

## Architecture

### Rust owns the rules, Flutter owns only presentation

`engine/src/lib.rs` holds the entire rules model: board topology, push resolution, tile damage, counter-push restrictions, and win detection.
`engine/src/api.rs` exposes synchronous bridge functions over that model, and the `RulesEngine` interface in `lib/game/rules/rules_engine.dart` is the Dart-side boundary that wraps them; grep `^pub fn` in `api.rs` for the current set rather than trusting a list here.

- `initial_match` returns the starting `MatchSnapshot`.
- `match_legal_moves` returns every move the current player may make.
- `match_apply_move` returns the resulting snapshot.
- `advance_round` starts the next round of a match.
- `choose_bot_move` returns the move a policy would play, and never applies it.

The bridge passes values, not handles, so no game state lives across the boundary between calls.
Every snapshot carries a `snapshotHash`, and `state_from_snapshot` in `engine/src/api.rs` rejects any snapshot whose hash disagrees with its value fields.
That check is what makes it impossible for Dart to fabricate or edit a position, and it is invisible from the Dart side, so a Dart-side "fix" that rebuilds a snapshot by hand fails at the bridge rather than in Flutter.

Stop and reconsider the design if a function like any of these starts appearing in Dart, because each one re-implements a rule that belongs to Rust.

```dart
bool canPush(...)
bool isHoleDestination(...)
TileState damageTile(...)
bool isCounterPush(...)
Player? calculateWinner(...)
void awardRound(...)
bool isMatchDecided(...)
Player nextStartingPlayer(...)
```

The match is a rule too, so counting round wins, deciding a match is over,
and choosing who starts the next round belong to Rust for the same reason
push resolution does.

### Flutter layering

`lib/game/match/match_controller.dart` is a plain Dart state holder with no Flutter or state-management imports.
`lib/game/view/game_page.dart` owns the controller and calls `setState` after each mutation, and `lib/game/view/round_board.dart` is a `CustomPainter` board.

The controller enforces invariants that are easy to break during edits.

- `winner == null` if and only if `winReason == null`. This is a bridge schema check rather than game logic, so a snapshot with only one field set is treated as a bridge failure.
- `applyMove` is atomic from the presentation's point of view: the new snapshot is assigned only after `legalMoves` for it also succeeds, so a mid-sequence bridge failure leaves a mutually consistent snapshot and legal-move list.
- Irreversible moves fire on tap-up, never on tap-down, so a canceled gesture cannot change the round.
- Legal destination markers paint after pieces, so a legal push destination stays visible even when it is currently occupied.

## Generated code

Never hand-edit `lib/src/rust/**`, `engine/src/frb_generated.rs`, `lib/gen/`, or `lib/l10n/gen/`.
After changing `engine/src/api.rs`, regenerate with `merry run generate`; the script pins `flutter_rust_bridge_codegen` to 2.12.0 and refuses to run when the vendored Cargokit Gradle plugin's blob SHA has drifted from the pinned commit.

Keep CSpell additions scoped to `.cspell/custom-dictionary.txt`, and keep repository documentation under `docs/specs/`, `docs/plans/`, or `docs/notes/`.

## Scope boundaries

The MVP is a local best-of-three match on Android and iOS, hot-seat or with a policy holding the second seat.
Flutter Web is deliberately excluded because the stable `flutter_rust_bridge` Web toolchain boundary was never validated: `flutter_rust_bridge.yaml` sets `web: false`, and adopting a prerelease or patching generated glue to include Web is not an acceptable workaround.
Flame, Bloc, online PvP, matchmaking, accounts, rankings, sound polish, and complex animations were all removed or deferred on purpose, so do not reintroduce them without an explicit request.

Treat board topology and starting layouts as balance configuration rather than invariant game rules, and keep `engine/` free of dependencies beyond `flutter_rust_bridge` unless a change explicitly requires otherwise.
