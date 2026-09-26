# Built-in board selection implementation

## Approved direction

The operator requested #67 controls followed by #72 implementation.
Complete and validate the controlled reports before changing app source.
Keep the baseline and add clipped corners as an optional playtest configuration.

## Steps and ownership

1. Root records #67 source, fixed inputs, complete reports, repeat hashes, trace replay, and interpretation before implementation.
2. App worker owns `lib/game/board/board_definition.dart`, `lib/game/start/start_page.dart`, both source ARB files, and setup/catalog tests.
   Observe a meaningful failing setup regression before adding the picker.
   Verify catalog identity, forwarding, session retention, fresh defaults, localization, and scrolling.
3. Native test worker owns `integration_test/ios_gameplay_flow_test.dart` and `tool/rules_engine_host_test.dart`.
   Reuse the native real-engine gameplay harness for each catalog board.
   Verify initial topology, full match and next round, restart, missing corner taps, Expert responses, and large text.
4. Root runs existing irregular geometry and stale-result regressions plus the complete local gate.
   Run heavy native jobs sequentially and inspect the actual screenshots.
5. Independent reviewers inspect implementation and acceptance evidence.
   Root repairs verified findings, makes scoped commits, opens the PR, and waits for current-head hosted review and CI.
   Human visual approval and merge remain required.

## Verification

- Setup and board tests: `flutter test test/game/start/start_page_test.dart test/game/board/board_definition_test.dart`.
- Shared presentation lifecycle: `flutter test test/game/view/round_board_test.dart test/game/view/game_page_test.dart test/game/match/match_controller_test.dart`.
- Host configuration and bridge: `merry run bridge host`.
- Full repository gate: `merry run check`.
- Markdown vocabulary: `npx cspell lint --config cspell.json --gitignore-root . '**/*.md'`.
- Native gameplay: existing Flutter integration driver with each selected Android/iOS simulator runtime, one at a time.
- Human review: captured setup choices and actual selected-board screens.

## Limits

A host bridge pass does not prove native packaging.
A native snapshot hash proves the engine state seen by the UI, not visual readability.
Screenshots are inspected separately.
The new board is not claimed balanced by the baseline simulation results.
