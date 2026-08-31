---
type: Spec
title: Runtime Board Replacement
---

## Problem

`GamePage` creates its `MatchController` only in `initState`.
When a retained `GamePage` receives a different `BoardDefinition`, Flutter renders the new background path while the controller continues to use the old rules and match snapshot.
This mismatch can also leave an old bot timer or replay callback active after the visible board changes. [L1]

## Proposed Outcome

Treat a new `BoardDefinition` instance as a request to start a fresh match on the retained `GamePage` State.
Cancel page-owned work from the previous match before a fresh `MatchController` initializes from the new rules.
Render the background and match snapshot from the same definition after the transition. [L1] [L3]

## User Stories

1. As a player, I see a fresh match that belongs to the newly selected board instead of a background and rules mismatch.
2. As a player, I never see a bot move or replay from the previous board complete after board replacement.
3. As a developer, I can replace A with B on the same `GamePage` State and verify the complete lifecycle transition in a widget test.

## Requirements

1. Detect a replacement when the `BoardDefinition` instance changes on a retained `GamePage` State. [L1] [L5]
2. Keep the current match when the parent rebuilds with the identical `BoardDefinition` instance. [L3]
3. Create and initialize a fresh `MatchController` with the current `RulesEngine` and the new `BoardDefinition.rules`. [L3] [L4]
4. Render `BoardDefinition.backgroundAssetPath` from the same new definition that initialized the fresh controller. [L1]
5. Discard the previous active match, score, selected piece, opponent selection, error, retry action, pending move, and match announcement. The fresh controller starts with its existing defaults. Ignore a pending opponent-sheet result that was opened for the previous controller. [L3]
6. Cancel the previous bot timer and clear its page-owned reference before the new match can schedule bot work. The canceled callback must not call the engine. [L3] [L4]
7. Stop the previous replay, invalidate its completion callback, and clear its visible resolution. A prepared result from the previous match must never commit after replacement. [L3] [L4]
8. Preserve the coach state, coach store, and feedback resource because they belong to the retained page rather than one match. [L3]
9. If initialization from the new definition fails, show the existing initialization error UI over the new background. Retry must use the new definition. [L4]
10. Keep Rust validation, bridge APIs, `BoardDefinition`, `RulesEngine`, `MatchController`, `RoundBoard`, board geometry, hit regions, semantics, and feedback behavior unchanged. [L4]
11. Do not add a board selector, persistence, navigation, dependency, asynchronous initialization path, or new user-facing copy. [L2] [L4]

## Technical Decisions

`GamePage.didUpdateWidget` compares the old and new `BoardDefinition` instances with `identical`.
A new instance is an explicit replacement request, even if its fields contain equivalent values.
This rule avoids a partial value comparison across generated list-backed bridge types.

`GamePage` changes `_controller` from a `late final` field to a replaceable `late` field.
One private helper constructs and initializes the controller for both `initState` and board replacement.
`didUpdateWidget` cancels the bot timer, invalidates replay completion, stops replay playback, clears the visible replay resolution and match announcement, and installs the fresh controller.

The replacement is synchronous because `RulesEngine.initialMatch` is synchronous and `MatchController.initialize` already converts failures into `MatchStatus.initializationError`.

## Testing Strategy

1. Add a widget regression that rebuilds a keyed `GamePage` from definition A to definition B. Assert that the State object is identical, the engine receives A then B, the visible snapshot and background belong to B, the opponent returns to Human, the A announcement is gone, and a pending A bot timer never calls the engine. [L1] [L3] [L5]
2. Rebuild once with the identical A instance before the A-to-B transition. Assert that the engine initializes only once for that no-op rebuild. [L3]
3. Add a widget regression that starts an A replay, replaces A with B before completion, and advances beyond the replay duration. Assert that playback clears immediately and the B snapshot remains visible. [L3] [L4]
4. Add a widget regression that opens the opponent sheet on A, replaces A with B, and returns a choice from the old sheet. Assert that B keeps its default Human opponent. [L3] [L4]
5. Run the focused `game_page_test.dart`, Flutter analysis, and `merry run check`.
   The aggregate gate checks source formatting, analysis, Flutter tests, Rust checks, the host bridge, and Trunk.
   It does not prove native packaging, but this lifecycle change has no platform-specific implementation path.

## Out of Scope

- A user-facing board selector or a second production board.
- Match, score, opponent, selection, error, pending move, timer, or replay persistence across replacement.
- Rust, bridge, rule, snapshot, board geometry, hit-region, semantics, localization, sound, haptic, asset, or navigation changes.
- Runtime configuration loading, serialization, caching, or a new state-management abstraction.
