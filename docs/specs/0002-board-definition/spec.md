---
type: Spec
title: Board Definition Configuration
---

## Problem

Rust can validate arbitrary playable-cell layouts and starting pieces, but the public start API always creates the fixed baseline board.
Flutter also hardcodes the air-ruins background path.
Future board topology, starting layouts, and background metadata therefore require edits across rule and presentation code.

## Proposed Outcome

Add one built-in typed `BoardDefinition` that preserves the current five-by-five baseline board.
The Dart definition owns presentation metadata and sends only rule inputs to a generated Rust bridge type.
Rust validates those inputs before it creates the match.

## User Stories

1. As a balance author, I can change the built-in board cells and starting pieces without editing Rust rule logic. [L1] [L2]
2. As a player, I see the same baseline match and air-ruins background after the migration. [L2]
3. As a developer, I receive a recoverable initialization error when a BoardDefinition is invalid after the Rust library starts. [L4]
4. As a developer, I can prove that an irregular BoardDefinition reaches Rust and Flutter through the generated bridge. [L5]

## Requirements

1. Create a Dart `BoardDefinition` with a `backgroundAssetPath` and a generated Rust `GameBoardDefinition` value. [L2] [L3]
2. Create the baseline BoardDefinition with the existing 25 playable cells, four starting pieces, and `assets/images/air_ruins_twilight.png`. [L2]
3. Create generated Rust bridge input types for playable-cell coordinates and starting pieces. The input types must not contain background presentation metadata. [L3]
4. Change `initial_match` and `RulesEngine.initialMatch` to accept `GameBoardDefinition`. The call remains synchronous after `RustLib.init()` completes. [L3] [L4]
5. Convert the input cells and pieces to `BoardConfig::new` in Rust. Reject an empty board, duplicate cells, overlapping pieces, duplicate piece IDs, and pieces outside playable cells with a bridge error. [L4]
6. Keep `MatchSnapshot`, snapshot hashing, move legality, move resolution, round reset behavior, and Flutter geometry ownership unchanged. [L2] [L3]
7. Pass the same BoardDefinition through GamePage, MatchController, RulesEngine, production bridge code, and fake RulesEngine test seams. [L2] [L5]
8. Read the background image path from the Dart BoardDefinition. Do not send it through flutter_rust_bridge. [L3]
9. Preserve the current baseline initial snapshot hash and current user-visible baseline board behavior. [L2] [L5]
10. Test an irregular definition that has a non-zero coordinate origin and absent cells. Assert the returned snapshot contains exactly that topology and its stated starting pieces. [L5]
11. Run the existing Android and iOS parity integration test with a BoardDefinition argument when those runtimes are available. Do not install, launch, or otherwise write to the operator's daily iPhone. [L5]

## Technical Decisions

| Field                 | Owner                | Boundary                                |
| --------------------- | -------------------- | --------------------------------------- |
| Playable cells        | Rust validation      | `GameBoardDefinition` input             |
| Starting pieces       | Rust validation      | `GameBoardDefinition` input             |
| Background asset path | Flutter presentation | Dart `BoardDefinition` only             |
| Current match state   | Rust                 | Existing `MatchSnapshot` value boundary |

The app's built-in Dart definition is the only source of its initial layout data in this milestone.
It is not a runtime configuration loader.
Flutter does not validate game invariants or calculate legal moves.

The existing `MatchController.initializationError` state receives an invalid initial-match result after `RustLib.init()` succeeds.
This scope does not add UI recovery for `RustLib.init()` failure because bootstrap initializes the native library before it creates the app widget tree. [L4]

Generated bridge output remains generator-owned.
Run `merry run generate` after the Rust API change.

## Testing Strategy

| Layer                       | Evidence                                                                                                                  |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Rust rules and bridge tests | Directly reject each invalid input shape and assert that the baseline hash remains unchanged.                             |
| Dart controller tests       | Assert that the configured definition reaches the RulesEngine and that an initial-match failure remains retryable.        |
| Flutter widget tests        | Assert that GamePage uses the BoardDefinition background path and retains snapshot-derived irregular geometry.            |
| Host bridge test            | Load the generated native library and assert that an irregular definition returns its exact topology and starting pieces. |
| Native integration tests    | Run the baseline parity fixture and irregular-definition bridge assertion on Android and iOS runtimes.                    |

Each new regression must fail before its production change is written.
Use the existing `RulesEngine` injection and `FakeRulesEngine` instead of network or native test doubles for widget tests.

## Out of Scope

- JSON, YAML, remote, or downloaded board configuration.
- A board picker, persisted board selection, multiple built-in boards, or navigation changes.
- New backgrounds, sprites, animation systems, audio changes, game-rule changes, or new package dependencies.
- Flutter Web support.
- A retry surface for `RustLib.init()` failure.
- Manual TalkBack certification.

## Follow-Ups

- Record separate TalkBack evidence after a fixture and test device are available.
- Consider an asset-loaded board format only when more than one configuration needs runtime selection or independent release cadence.
