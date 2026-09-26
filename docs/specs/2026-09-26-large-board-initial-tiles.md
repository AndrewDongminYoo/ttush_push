# Large boards and initial tile states

## Contract

Add two optional seven-by-seven presets with six pieces.
First owns IDs 0, 1, and 2 at (1, 1), (3, 1), and (5, 1).
Second owns IDs 3, 4, and 5 at (1, 5), (3, 5), and (5, 5).
The `large` preset starts all 49 cells normal.
The `large-holes` preset starts holes at (1, 3), (3, 3), and (5, 3), with all other cells normal.
Holes remain part of the board and use the existing destroyed-tile rendering and rules.

The existing baseline remains the default, and selection remains local to the mounted setup page.
The first knockout still wins a round, and the existing best-of-three match rules remain unchanged.
The larger layout is a playable option, not a claim of improved balance.

## Initial states

Dart supplies an optional list of initial tile overrides through `GameBoardDefinition`.
Omitted cells are normal, and an omitted list preserves existing callers.
Reuse the normal, damaged, and hole enum values.
Reject duplicate overrides, coordinates outside the board, and a starting piece on a hole.
A piece may start on a damaged tile, which becomes a hole when that piece leaves.

Rust validates and retains the canonical initial tile map with the starting pieces.
The match value must carry and hash that map, because current round damage cannot identify the reset state.
Every bridge round trip and next-round reset must preserve it.
New matches restore the same definition.
Keep round hash and baseline policy behavior unchanged.

Do not add a board editor, persistence, dependencies, an elimination victory mode, a separate damaged preset, or balance-policy changes.
Generate bridge code from the Rust API rather than editing generated files.

## Acceptance

- Verify exact cells, IDs, owners, coordinates, and initial states for both new presets.
- Observe a failing selection or state behavior before implementing it.
- Reject invalid initial-state input and altered reset metadata at the bridge.
- Exercise damaged departure, illegal entry into a hole, knockout into an initial hole, and next-round restoration.
- Test localized setup reachability with large text, real-engine start and restart, and six-piece gameplay.
- Run actual Android and iOS gameplay with screenshots, including Expert responses.
- Run the complete local gate and current-head CI and hosted review.
- Request operator approval of the rendered presets before merge.

## Precedent

The scoped personal Oracle queries for `BoardConfig` and `initial tiles` returned `[no precedent found]` at source revision `c1681868ac634e4b2414874716bb75a7864113c4`.
Current `CLAUDE.md` remains the architectural source: Dart owns configuration, and Rust owns validation, rules, and resets.
