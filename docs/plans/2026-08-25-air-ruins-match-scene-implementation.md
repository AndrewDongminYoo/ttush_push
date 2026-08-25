# Air-Ruins Match Scene Implementation Plan

> **For agentic workers:** Execute this plan inline, task by task, with one red-green-refactor test cycle for each behaviour.

**Goal:** Turn the playable local match into a readable air-ruins scene while preserving Rust as the source of all game rules and move resolution.

**Architecture:** `GamePage` composes a single checked-in environment image, compact Ember and Azure HUDs, and the existing snapshot-driven board.
`MatchController` owns only the UI policy for when Second's opponent can change, while `RoundBoard` retains snapshot-derived geometry and evolves its painter treatment.

**Tech Stack:** Flutter, Dart, CustomPainter, Flutter localization generation, existing Flutter widget and unit tests.

**Spec:** `docs/specs/2026-08-24-air-ruins-match-scene.md`

## Global Constraints

- Do not change Rust rules, bridge contracts, board configuration, or resolution playback semantics.
- Do not add package dependencies or hand-edit generated Flutter/Rust/localization output.
- Keep the board geometry derived exclusively from snapshot tile coordinates.
- Keep all visible match copy in English ARB resources.
- Generate one local background with no text, logos, characters, or interactive affordances.
- Preserve tap-up move commitment and destination markers above occupied pieces.

---

### Task 1: Lock opponent selection after the first applied move

**Files:**

- Modify: `lib/game/match/match_controller.dart`
- Test: `test/game/match/match_controller_test.dart`

**Interfaces:**

- Produces: `bool MatchController.canChangeOpponent` and `void MatchController.selectOpponent(Opponent opponent)`.
- Consumes: `prepareHumanMove`, `prepareBotMove`, `commitPendingMove`, and `restart`.

- [x] **Step 1: Write the failing controller test for changing the Second seat before a move.**

```dart
controller.selectOpponent(Opponent.greedy);

expect(controller.opponent, Opponent.greedy);
expect(controller.canChangeOpponent, isTrue);
```

- [x] **Step 2: Run the focused test and confirm it fails because the explicit selection API does not exist.**

Run: `flutter test test/game/match/match_controller_test.dart --plain-name 'changes the opponent before the first move'`

- [x] **Step 3: Implement the minimum explicit selection API.**

```dart
bool get canChangeOpponent => !hasPendingMove && !_hasAppliedMove;

void selectOpponent(Opponent opponent) {
  if (!canChangeOpponent) return;
  _opponent = opponent;
  _selectedPieceId = null;
  _error = null;
  _retryAction = null;
}
```

- [x] **Step 4: Run the focused controller test and confirm it passes.**

Run: `flutter test test/game/match/match_controller_test.dart --plain-name 'changes the opponent before the first move'`

- [x] **Step 5: Write the failing controller test for locking after the prepared move is committed and unlocking only after a successful new match.**

```dart
expect(controller.prepareHumanMove(move), isTrue);
expect(controller.canChangeOpponent, isFalse);
controller.commitPendingMove();
controller.restart();
expect(controller.canChangeOpponent, isTrue);
```

- [x] **Step 6: Run the focused test and confirm it fails because the match does not retain the lock state.**

Run: `flutter test test/game/match/match_controller_test.dart --plain-name 'locks opponent selection after the first applied move'`

- [x] **Step 7: Implement the minimum lock state.**

```dart
bool _hasAppliedMove = false;

void commitPendingMove() {
  // Existing atomic snapshot adoption remains unchanged.
  _hasAppliedMove = true;
}

void restart() {
  // Reset _hasAppliedMove only after initialMatch and legalMoves succeed.
}
```

- [x] **Step 8: Run all controller tests and refactor only duplicated reset/error cleanup.**

Run: `flutter test test/game/match/match_controller_test.dart`

### Task 2: Localize and compose the full air-ruins match surface

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/game/view/game_page.dart`
- Modify: `pubspec.yaml`
- Create: `assets/images/air_ruins_twilight.png`
- Test: `test/game/view/game_page_test.dart`

**Interfaces:**

- Consumes: `MatchController.canChangeOpponent`, `MatchController.selectOpponent`, `AppLocalizations`, and `assets/images/air_ruins_twilight.png`.
- Produces: a full-safe-area scene with Ember in the top HUD, Azure in the bottom HUD, and an explicit `Opponent` bottom-sheet control.

- [x] **Step 1: Write the failing widget test for the stable expedition labels and HUD orientation.**

```dart
expect(find.text('Ember Expedition'), findsOneWidget);
expect(find.text('Azure Expedition'), findsOneWidget);
expect(
  tester.getTopLeft(find.text('Ember Expedition')).dy,
  lessThan(tester.getTopLeft(find.text('Azure Expedition')).dy),
);
```

- [x] **Step 2: Run the focused test and confirm it fails with the prototype player labels.**

Run: `flutter test test/game/view/game_page_test.dart --plain-name 'places Ember above Azure'`

- [x] **Step 3: Add English ARB keys and build compact top and bottom HUDs.**

```dart
final l10n = AppLocalizations.of(context);
final name = switch (player) {
  rust.GamePlayer.first => l10n.azureExpedition,
  rust.GamePlayer.second => l10n.emberExpedition,
};
```

- [x] **Step 4: Run the focused widget test and localization generation, then confirm it passes.**

Run: `flutter gen-l10n && flutter test test/game/view/game_page_test.dart --plain-name 'places Ember above Azure'`

- [x] **Step 5: Write the failing widget test for the pre-move opponent bottom sheet.**

```dart
await tester.tap(find.byKey(const Key('opponent-control')));
await tester.pumpAndSettle();
expect(find.text('Opponent'), findsWidgets);
expect(find.text('Minimax'), findsOneWidget);
```

- [x] **Step 6: Run the focused test and confirm it fails because the HUD still cycles the opponent.**

Run: `flutter test test/game/view/game_page_test.dart --plain-name 'opens opponent choices before the first move'`

- [x] **Step 7: Implement the explicit control and selected-value bottom sheet.**

```dart
OutlinedButton.icon(
  key: const Key('opponent-control'),
  onPressed: controller.canChangeOpponent ? () => _showOpponentSheet(context) : null,
  icon: const Icon(Icons.groups_outlined),
  label: Text(l10n.opponentWithValue(localizedOpponent)),
)
```

- [x] **Step 8: Write and run one widget test that applies a legal move, confirms the disabled control, advances a round, and confirms it remains disabled.**

Run: `flutter test test/game/view/game_page_test.dart --plain-name 'locks opponent choices after the first move'`

- [x] **Step 9: Generate and inspect one original background candidate before adding it to the declared asset path.**

```text
Use case: stylized-concept
Asset type: Flutter match-screen background
Primary request: a fragmented floating air-ruin island after a storm at twilight
Constraints: no text, no logo, no watermark, no characters, no game-board cells, readable negative space at the centre
```

- [x] **Step 10: Add the approved image asset, declare it in `pubspec.yaml`, and layer it behind the board with a non-interactive dark scrim.**

Run: `flutter pub get && flutter test test/game/view/game_page_test.dart`

### Task 3: Paint stone slabs and distinct explorer silhouettes without changing geometry or playback

**Files:**

- Modify: `lib/game/view/round_board.dart`
- Test: `test/game/view/round_board_test.dart`

**Interfaces:**

- Consumes: `BoardGeometry.fromSnapshot`, `BoardPlayback`, Rust `GameTile`, and Rust `GamePiece`.
- Produces: intact and cracked air-ruin slabs plus Azure and Ember painter silhouettes that remain distinguishable without hue.

- [x] **Step 1: Write the failing painter test that samples comparable non-color shape output for Azure and Ember.**

```dart
expect(azurePixels, isNot(equals(emberPixels)));
```

- [x] **Step 2: Run the focused painter test and confirm it fails while pieces use disc and rounded-square tokens.**

Run: `flutter test test/game/view/round_board_test.dart --plain-name 'uses explorer bodies instead of prototype piece tokens'`

- [x] **Step 3: Replace only the piece paths with two stable explorer silhouettes.**

```dart
Path _explorerPath(GamePlayer owner, Offset center) => switch (owner) {
  GamePlayer.first => _azureExplorerPath(center),
  GamePlayer.second => _emberExplorerPath(center),
};
```

- [x] **Step 4: Run the focused painter test and existing move/push/playback tests.**

Run: `flutter test test/game/view/round_board_test.dart`

- [x] **Step 5: Write the failing painter test that identifies an intact slab edge, a damaged crack, and an unpainted hole.**

```dart
expect(intactTilePixels, contains(_slabEdgeColor));
expect(damagedTilePixels, contains(_crackColor));
expect(holePixels, isNot(contains(_slabFillColor)));
```

- [x] **Step 6: Run the focused test and confirm it fails against the prototype foothold treatment.**

Run: `flutter test test/game/view/round_board_test.dart --plain-name 'gives intact footholds a lower stone facet'`

- [x] **Step 7: Implement the minimum slab treatment without changing `BoardGeometry`, destinations, or playback order.**

```dart
// Preserve tile coordinates and paint only the snapshot's non-hole tiles.
final slab = geometry.cellRect(tile.x, tile.y).deflate(geometry.cellSize * 0.08);
```

- [x] **Step 8: Run all board tests, then verify geometry remains tile-derived.**

Run: `flutter test test/game/view/round_board_test.dart && rg -n '_boardLength|/ 5|\b5\b' lib/game/view/round_board.dart`

### Task 4: Validate the production slice and capture visual evidence

**Files:**

- Modify: generated `lib/l10n/gen/` output only through `flutter gen-l10n`
- Verify: `test/game/match/match_controller_test.dart`
- Verify: `test/game/view/game_page_test.dart`
- Verify: `test/game/view/round_board_test.dart`

**Interfaces:**

- Consumes: all previous production paths and existing fake rules-engine fixtures.
- Produces: source and rendered evidence that the M2 acceptance criteria are satisfied.

- [x] **Step 1: Format exactly the changed Dart paths and run focused tests.**

Run: `dart format lib/game/match/match_controller.dart lib/game/view/game_page.dart lib/game/view/round_board.dart test/game/match/match_controller_test.dart test/game/view/game_page_test.dart test/game/view/round_board_test.dart && flutter test test/game/match/match_controller_test.dart test/game/view/game_page_test.dart test/game/view/round_board_test.dart`

- [x] **Step 2: Regenerate localization output and run the full project gate.**

Run: `flutter gen-l10n && merry run check`

- [x] **Step 3: Verify only generator-owned localization files changed, then run Markdown spelling for the new plan.**

Run: `git diff --name-only -- lib/l10n/gen && npx cspell check --config cspell.json 'docs/plans/2026-08-25-air-ruins-match-scene-implementation.md'`

- [x] **Step 4: After separate simulator write approval, capture and inspect compact and tall running-app screenshots with an exercised board state.**

Run: `flutter run --flavor development -d <approved-simulator-id>`

## Coverage Review

- One environment asset, air-ruin hierarchy, and foreground-only board treatment are implemented in Task 2.
- Azure/Ember orientation, explicit opponent control, state lock, ARB ownership, result, and Retry surfaces are implemented in Tasks 1 and 2.
- Explorer silhouettes, slab states, holes, destinations, and resolution playback preservation are covered in Task 3.
- Formatting, analysis, project gate, and deferred rendered simulator evidence are consolidated in Task 4.

## Placeholder and Consistency Review

- No unimplemented behavior is left as a placeholder.
- `canChangeOpponent`, `selectOpponent`, and `BoardGeometry` are used consistently across all tasks.
- The plan uses no new runtime dependency or Rust API.
