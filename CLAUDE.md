<!-- cspell:ignore clippy hotseat -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Every command string lives in `merry.yaml`. Run `merry ls` for the current list and `merry run <name> <subname>` to execute one, rather than restating a command here.
Note that the CLI separates nested names with a space, while the config file references them as `$rust:test`.

`merry run check` is the full local gate before committing, and it adds `trunk check`, which CI does not run.
It does not stand in for the whole of CI. The `spell-check` job reads every `**/*.md` through `cspell.json`, and no local linter does: `trunk check` looks only at modified files and has no cspell among its enabled linters. Run `npx cspell lint --config cspell.json --gitignore-root . '**/*.md'` after touching any markdown, including from a linked checkout whose parent is ignored. The `semantic-pull-request` job reads the PR title and has no local form at all.

The aggregate gate builds the release Rust host library and runs `tool/rules_engine_host_test.dart` on macOS or Linux. That test calls `RustLib.init` through the generated bridge and reuses the device integration test's snapshot and bot-policy parity fixture, so a codegen/runtime/version mismatch fails before app startup. It does not validate Android or iOS packaging.

The gate's last step, `merry run parity`, is what covers packaging, and it covers it only opportunistically: it runs the integration test on every simulator or emulator that is **already** running and skips when none is, because booting one costs more than a pre-commit gate may. So a green gate says nothing about native packaging on its own. Read the step's own last line, which is either `parity: covered N runtime(s)` or `parity: SKIPPED`, and start a runtime and re-run after any change to mobile runner or build integration.

A skip means nothing was running, never that the step could not tell. A device query that fails — a wedged CoreSimulator, an adb that cannot start its daemon — fails the step instead of skipping it, because a discovery failure cannot distinguish an idle machine from a running one.

Two things the script list does not tell you:

- `merry run format` rewrites Dart sources, while `merry run format check` only fails on drift. The same pair exists under `merry run rust format`.
- `merry run` does not forward extra arguments, so anything that takes a target is invoked directly:

```sh
flutter test test/game/match/match_controller_test.dart
cargo test --manifest-path engine/Cargo.toml counter_push
flutter test integration_test/rules_engine_parity_test.dart -d <device-id> --flavor development
```

The parity integration test is the accepted native evidence: the same Rust-owned snapshot hash must appear on both an Android and an iOS runtime.
`merry run parity` covers that on simulators and emulators without a device id, and refuses a physical device outright, so the direct form above is only for running it against a real phone.
Connect the iOS device over USB before running it that way. `flutter test` does not publish a port, so on a wirelessly tethered device it exits at `IOSDevice.startApp` with "Cannot start app on wirelessly tethered iOS device. Try running again with the --publish-port flag" — and no such flag exists on `flutter run` or `flutter drive` in the pinned Flutter, so the message is a dead end rather than an instruction. Over USB the command above works as written; it still prints a local-network warning, which is the mDNS lookup failing before the run falls back to the cable.

## Architecture

### Rust owns the rules, Flutter owns only presentation

`engine/src/lib.rs` holds the entire rules model: board topology, push resolution, tile damage, counter-push restrictions, and win detection.
`engine/src/api.rs` exposes synchronous bridge functions over that model, and the `RulesEngine` interface in `lib/game/rules/rules_engine.dart` is the Dart-side boundary that wraps them; grep `^pub fn` in `api.rs` for the current set rather than trusting a list here.

- `initial_match` accepts a `GameBoardDefinition`, validates its cells and starting pieces in Rust, and returns the starting `MatchSnapshot`.
- `match_legal_moves` returns every move the current player may make.
- `match_apply_move` returns a `MoveResult` containing the next snapshot and Rust-authored resolution.
- `advance_round` starts the next round of a match.
- `choose_bot_move` returns the move a policy would play, and never applies it.

The bridge passes values, not handles, so no game state lives across the boundary between calls.
`lib/game/board/board_definition.dart` owns the one built-in board definition and its background asset path.
It sends only `GameBoardDefinition` to Rust.
Rust validates the cells and starting pieces before it creates a match.
Every round and match snapshot carries a `snapshotHash`: `state_from_snapshot` validates the round value fields, while `match_state_from_snapshot` validates the match fields and its inner round.
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

- `roundWinner == null` if and only if `roundWinReason == null`, and the match phase decides whether the round result and `matchWinner` must be present. These are bridge schema checks rather than game logic, so an inconsistent snapshot is treated as a bridge failure.
- `applyMove` is atomic from the presentation's point of view: the new snapshot is assigned only after `legalMoves` for it also succeeds, so a mid-sequence bridge failure leaves a mutually consistent snapshot and legal-move list.
- Irreversible moves fire on tap-up, never on tap-down, so a canceled gesture cannot change the round.
- Legal destination markers paint after pieces, so a legal push destination stays visible even when it is currently occupied.

## Generated code

Never hand-edit `lib/src/rust/**`, `engine/src/frb_generated.rs`, `lib/gen/`, or `lib/l10n/gen/`.
After changing `engine/src/api.rs`, regenerate with `merry run generate`; the script pins `flutter_rust_bridge_codegen` to 2.13.0 and refuses to run when the vendored Cargokit Gradle plugin's blob SHA has drifted from the pinned commit.
That version is pinned in five places at once, and they move together or the bridge refuses itself: `pubspec.yaml` (an exact pin, deliberately not a caret range), `pubspec.lock`, the `"="` requirement in `engine/Cargo.toml`, the version the generate script checks, and the `@generated by` header the glue carries on both sides.
Rewriting that header is not regeneration, and it is the only visible difference, so a search-and-replace leaves a file asserting a version it was not built from.

Keep CSpell additions scoped to `.cspell/custom-dictionary.txt`, and keep repository documentation under `docs/specs/`, `docs/plans/`, or `docs/notes/`.

## Scope boundaries

The MVP is a local best-of-three match on Android and iOS, hot-seat or with a policy holding the second seat.
Flutter Web builds, but it is not a shipping target: `flutter_rust_bridge.yaml` sets `web: true`, `lib/src/rust/frb_generated.web.dart` is tracked, and the `web` CI job runs `tool/build_web.sh` against the nightly Rust `wasm32-unknown-unknown` toolchain and `wasm-pack` 0.15.0.
That gate exists so a regenerated bridge cannot silently break the Web glue, not to license Web-specific UI work, and the MVP still ships Android and iOS only.
`merry run build web` runs that same script locally; it is deliberately not one of `merry run check`'s steps, because the Web toolchain it installs is not what a commit should have to pay for.
Flame, Bloc, online PvP, matchmaking, accounts, rankings, and complex animations beyond the existing Rust-authored move replay were removed or deferred on purpose, so do not reintroduce them without an explicit request.
The current haptic and synthesized sound feedback is intentional; do not expand it into a broader audio or animation system without an explicit request.

Treat board topology and starting layouts as balance configuration rather than invariant game rules, and keep `engine/` free of dependencies beyond `flutter_rust_bridge` unless a change explicitly requires otherwise.
