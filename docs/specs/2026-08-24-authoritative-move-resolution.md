# Authoritative Move Resolution and Snapshot-Driven Board Geometry

## Goal

Make every normal move, Push, fall, and foothold change visible in a replay without allowing Flutter to infer game rules from two snapshots.
Remove the Flutter-only fixed board-length assumption so the renderer derives its geometry from Rust-owned snapshot coordinates.

## Context

The current value bridge returns only the next `MatchSnapshot` after a move.
`MatchController` adopts that snapshot immediately, so a Push and a resulting fall are difficult to perceive.
`RoundBoard` also hard-codes a five-by-five board even though Rust already models a board as a set of playable positions.

Rust remains the sole authority for move legality, Push resolution, falls, foothold damage, round results, and match results.
Flutter may render a Rust-provided move result but must not reconstruct its meaning by comparing an old snapshot with a new one.

## Scope

- Extend the Rust bridge so applying a move returns a `MoveResult` containing the next `MatchSnapshot` and an authoritative `MoveResolution`.
- Change the Dart `RulesEngine` boundary and fake implementations to use `MoveResult`.
- Let `MatchController` prepare and validate a next state without publishing it until the page commits it after playback.
- Add a page-owned resolution playback state that locks interaction while it replays Rust-provided effects.
- Make `RoundBoard` use one snapshot-derived `BoardGeometry` for painting, overlay placement, and hit testing.
- Support the system reduced-motion setting by skipping travel paths while still showing a brief collision and the next state.
- Verify the bridge and resolution result on real Android and iOS runtimes after generation.

## Non-Goals

- Do not add the air-ruins background, new HUD, faction copy, ARB migration, opponent bottom sheet, generated image asset, or explorer sprites.
- Do not add the persisted coach or the complete VoiceOver/TalkBack board interaction surface.
- Do not introduce a `BoardDefinition` loader or change a board's size, topology, or starting layout.
- Do not move board configuration, legal-move derivation, Push rules, fall rules, or outcome calculation into Flutter.
- Do not add a package dependency in this milestone.

## Product Contract

### Authoritative move result

The bridge exposes a synchronous `applyMove` operation that returns a `MoveResult`.
`MoveResult` contains the fully validated next `MatchSnapshot` and one `MoveResolution` describing only the move just applied.

`MoveResolution` contains ordered, Rust-authored effects.

- The moving explorer's piece ID, origin, and destination.
- Every displaced explorer's piece ID, origin, and destination, or an explicit fall.
- The Rust-provided `exitDirection` for each fallen explorer.
- Each changed foothold's coordinate and exact state transition, including `normal → damaged` and `damaged → hole`.
- Whether the action is a normal move or a Push.

The next snapshot remains the sole authority for round and match outcomes.
Flutter does not derive a fall direction, a displaced piece, a foothold transition, or action kind from coordinate or snapshot differences.

### Deferred state adoption

`MatchController` validates the next snapshot and reads its legal moves before any visual playback begins.
It stores the validated next state as pending while continuing to expose the current snapshot and legal moves.

The page owns playback and commits the pending state only after every move effect has finished.
If preparation fails, the controller keeps the current visible state, records the recoverable error, and preserves the existing Retry behavior.
If the page is disposed or the pending result becomes stale, it must not commit that result.

The same prepare, replay, and commit path applies to a human move and to a bot move.
During playback, board taps, opponent changes, advancing the round, and starting a new match are unavailable.

### Board geometry

`BoardGeometry` derives the smallest inclusive coordinate bounds from every tile in the current snapshot, including Hole tiles.
It owns the column count, row count, square cell size, centered board origin, cell rectangle lookup, and point-to-cell mapping.

No Flutter rendering or hit-testing path may retain a fixed board-length constant or assume an origin of `(0, 0)`.
An irregular future board remains a rectangle of addressable cells inside these bounds, with absent terrain and Hole tiles rendered as void.
The future `BoardDefinition` data owner is explicitly out of scope for this milestone.

### Playback behavior

In the normal motion mode, playback completes within 0.6 seconds.
The moving explorer travels first, a Push shows an impact before displaced explorers travel or fall in Rust-provided order, and foothold damage plays at the transition coordinate.
Only then does the page commit the next snapshot and reveal any result state it contains.

When the operating system requests reduced motion, Flutter does not animate travel paths.
It shows a short collision or transition indication, commits the same Rust-provided next state, and preserves the interaction lock until that indication completes.

## Architecture

| Component                              | Responsibility                                                                                 |
| -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `engine/src/lib.rs`                    | Produces ordered move effects from the rule-authoritative move application.                    |
| `engine/src/api.rs`                    | Exposes generated bridge types and returns `MoveResult` without changing snapshot ownership.   |
| `lib/game/rules/rules_engine.dart`     | Mirrors the bridge contract for production and fake engines.                                   |
| `lib/game/match/match_controller.dart` | Atomically prepares and commits validated match states without rendering or animating.         |
| `lib/game/view/round_board.dart`       | Derives and applies `BoardGeometry` for rendering and hit testing.                             |
| `lib/game/view/game_page.dart`         | Owns the short-lived playback state, input lock, reduced-motion branch, and disposal behavior. |

## Error Handling

- An engine or bridge failure while preparing a result leaves the old board, selection, and legal moves visible.
- A failure while reading next legal moves is treated the same way as a failed move and exposes Retry for the original action.
- A result cannot begin playback until the next snapshot and next legal moves have both passed the existing contract validation.
- A stale timer, animation callback, or bot callback cannot commit a result after the page is disposed or after its pending result was invalidated.

## Testing Strategy

| Layer                    | Evidence                                                                                                                                       |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Rust rules tests         | Directly assert `MoveResolution` for a normal move, Push, chained displacement, fall, and both foothold transitions.                           |
| Rust bridge tests        | Assert `MoveResult` preserves the expected next snapshot and rejects edited values through the existing snapshot-hash boundary.                |
| Dart controller tests    | Assert prepare does not publish early, commit publishes the validated result, and failure preserves a consistent current state with Retry.     |
| Flutter widget tests     | Assert dynamic rectangular and irregular geometry, point-to-cell mapping, input locking, stale playback disposal, and reduced-motion behavior. |
| Native integration tests | On Android and iOS, initialize the real bridge and assert the same fixed fixture produces the same snapshot hash and resolution effects.       |

Each focused regression must fail when its corresponding effect is removed or incorrectly ordered before its passing result is accepted.
`merry run check` remains aggregate source-quality evidence only and does not prove the Rust bridge can initialize.

## Acceptance Criteria

- [ ] A legal human or bot move produces one Rust-authored `MoveResult` that includes the next snapshot and every visible move effect.
- [ ] Flutter does not infer displacement, falls, tile changes, action kind, or fall direction from snapshots or board coordinates.
- [ ] The old snapshot stays visible while a result is playing, and the next snapshot appears only after playback completes.
- [ ] Failed preparation leaves a coherent old screen and provides Retry for the failed action.
- [ ] All interactive match controls are unavailable while playback is active.
- [ ] A reduced-motion preference omits travel but retains a brief transition and commits the identical next snapshot.
- [ ] Painting and hit testing derive all board bounds from the current snapshot without a fixed board length.
- [ ] Focused Rust, Dart, and widget tests pass, and each directly reads its claimed behavior.
- [ ] Generated bridge code is refreshed through the repository generator after API changes.
- [ ] `merry run check` passes, and the updated native integration fixture passes on one Android runtime and one USB-connected iOS runtime.

## Verification Commands

```sh
merry run check
flutter test integration_test/rules_engine_parity_test.dart -d <android-device-id> --flavor development
flutter test integration_test/rules_engine_parity_test.dart -d <ios-device-id> --flavor development
```

The device commands are required bridge evidence after the API change.
Before writing to Andrew's daily iPhone, announce the exact install or launch action and obtain the separate required approval.

## Follow-Up Milestones

- Milestone 2 owns the generated air-ruins background, post-storm twilight scene, Azure and Ember HUD, ARB copy, and explicit opponent selection.
- Milestone 3 owns persisted first-play coaching and full VoiceOver/TalkBack board interaction.
- A later configuration milestone owns the one-time `BoardDefinition` integration so subsequent board size, playable-cell layout, starting pieces, and background metadata are data-only changes without Rust source edits.
