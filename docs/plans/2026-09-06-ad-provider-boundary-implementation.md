# Ad Provider Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place a game-shaped seam in front of any future ad provider, so adopting or replacing one touches the flavor entry points and one adapter rather than the match screen.

**Architecture:** One interface named for two moments on the game timeline, a `const` no-op implementation that ships today, and the same nullable-parameter threading the rules engine already uses from `App` down to `GamePage`. The game asks; the gateway decides whether anything happens.

**Tech Stack:** Flutter, Dart with `very_good_analysis`, `flutter_test`. No new dependency.

**Spec:** `docs/specs/0012-ad-provider-boundary/spec.md`

## Global Constraints

- No ad SDK, no new package dependency, and no network call anywhere in this plan.
- No ad call during a round, during move resolution, or while the round-complete screen is up.
- The shipped default performs no work and shows nothing.
- Provider selection is a build-time choice in the flavor entry points.
- Player-visible behavior of the current release does not change.
- Unchanged by this plan: `engine/`, `lib/src/rust/`, `pubspec.yaml`, `android/`, `ios/`.
- `flutter analyze` must stay clean under `very_good_analysis`, which forbids a discarded future.
- The Web CI job must stay green, so no `dart:io` import and no conditional import enters `lib/`.

## File Structure

| File                                     | Responsibility                                                                               |
| ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| `lib/game/ads/ad_gateway.dart`           | The whole boundary: the interface and the no-op default. Nothing else imports an ad concept. |
| `lib/game/view/game_page.dart`           | Reports the two moments. Owns no ad policy.                                                  |
| `lib/game/start/start_page.dart`         | Forwards the gateway to `GamePage`, exactly as it forwards the rules engine.                 |
| `lib/app/view/app.dart`                  | Accepts the gateway from the entry point and forwards it to `StartPage`.                     |
| `test/support/recording_ad_gateway.dart` | One shared recording fake, usable from both widget test files.                               |
| `test/game/ads/ad_gateway_test.dart`     | The default completes and does nothing.                                                      |
| `test/game/view/game_page_test.dart`     | The call-ordering assertions that are the point of this work.                                |
| `test/game/start/start_page_test.dart`   | Proves the gateway actually reaches `GamePage` through the widget tree.                      |

---

### Task 1: The gateway interface and its shipped default

**Files:**

- Create: `lib/game/ads/ad_gateway.dart`
- Test: `test/game/ads/ad_gateway_test.dart`

**Interfaces:**

- Consumes: nothing.
- Produces: `abstract interface class AdGateway` with `Future<void> matchDecided()` and `Future<void> beforeNewMatch()`; `final class NoAdGateway implements AdGateway` with a `const` constructor.

- [ ] **Step 1: Write the failing test**

Create `test/game/ads/ad_gateway_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/ads/ad_gateway.dart';

void main() {
  test('the shipped default completes both moments', () async {
    const gateway = NoAdGateway();

    await expectLater(gateway.matchDecided(), completes);
    await expectLater(gateway.beforeNewMatch(), completes);
  });

  test('the shipped default is a compile-time constant', () {
    expect(identical(const NoAdGateway(), const NoAdGateway()), isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/game/ads/ad_gateway_test.dart`

Expected: FAIL, because `package:ttush_push/game/ads/ad_gateway.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/game/ads/ad_gateway.dart`:

```dart
/// A moment the game reached, stated as the event rather than as an ad
/// request.
///
/// The page reports what happened; this layer alone decides whether anything
/// is shown. A frequency policy, a consent step, or a change of provider
/// therefore never reaches game code.
abstract interface class AdGateway {
  /// The match is decided. Prepare whatever the next interruption needs.
  ///
  /// The caller does not wait for this, because nothing may delay the result
  /// the player is reading.
  Future<void> matchDecided();

  /// The player asked for a new match.
  ///
  /// Completes when the interruption, if any, is over. The caller starts the
  /// new match afterwards, so an implementation that shows nothing simply
  /// completes.
  Future<void> beforeNewMatch();
}

/// What ships until a provider is chosen: it performs no work and shows
/// nothing.
final class NoAdGateway implements AdGateway {
  const NoAdGateway();

  @override
  Future<void> matchDecided() async {}

  @override
  Future<void> beforeNewMatch() async {}
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/ads/ad_gateway_test.dart`

Expected: PASS, 2 tests.

- [ ] **Step 5: Check formatting and analysis**

Run: `dart format lib/game/ads/ad_gateway.dart test/game/ads/ad_gateway_test.dart` then `flutter analyze`

Expected: no changes reported by a second `dart format --output=none --set-exit-if-changed` run, and no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/game/ads/ad_gateway.dart test/game/ads/ad_gateway_test.dart
git commit -m "feat(ads): add the ad gateway boundary and its no-op default"
```

---

### Task 2: GamePage reports the two moments

**Files:**

- Create: `test/support/recording_ad_gateway.dart`
- Modify: `lib/game/view/game_page.dart`
- Test: `test/game/view/game_page_test.dart`

**Interfaces:**

- Consumes: `AdGateway`, `NoAdGateway` from Task 1.
- Produces: `GamePage({AdGateway? adGateway})`, forwarded by Task 3; `RecordingAdGateway` in `test/support/recording_ad_gateway.dart` with `List<String> events` and an optional `Completer<void> hold`.

- [ ] **Step 1: Write the shared recording fake**

Create `test/support/recording_ad_gateway.dart`:

```dart
import 'dart:async';

import 'package:ttush_push/game/ads/ad_gateway.dart';

/// Records the moments the game reported, and can hold the new match open.
///
/// `hold` exists so a test can assert the ordering an ad imposes: while the
/// future is incomplete the interruption is still on screen, and the board
/// must not have restarted.
final class RecordingAdGateway implements AdGateway {
  RecordingAdGateway({this.hold});

  final Completer<void>? hold;
  final List<String> events = [];

  @override
  Future<void> matchDecided() async {
    events.add('match-decided');
  }

  @override
  Future<void> beforeNewMatch() {
    events.add('before-new-match');
    return hold?.future ?? Future<void>.value();
  }
}
```

- [ ] **Step 2: Write the three failing tests**

Add to `test/game/view/game_page_test.dart`. The imports at the top of that file gain exactly one line:

```dart
import '../../support/recording_ad_gateway.dart';
```

Do not import `ad_gateway.dart` here: the three tests below name only `RecordingAdGateway`, and an unused import fails `flutter analyze` under `very_good_analysis`.
`dart:async`, which the third test needs for `Completer`, is already imported at the top of the file.
Add these three tests inside the existing top-level `main()` group, next to the restart test that already builds a decided match:

```dart
  testWidgets('reports no ad moment while a round is being played', (
    tester,
  ) async {
    const startSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'ads-playing-start',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.damaged),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      snapshotHash: 'ads-playing-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final ads = RecordingAdGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          adGateway: ads,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(startSnapshot, hash: 'ads-playing-start'),
            next: matchOf(nextSnapshot, hash: 'ads-playing-next'),
            legalMoves: const [move],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(ads.events, isEmpty);
  });

  testWidgets('reports the decided match exactly once', (tester) async {
    const startSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.normal),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'ads-decided-start',
    );
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.damaged),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'ads-decided-terminal',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final ads = RecordingAdGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          adGateway: ads,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(startSnapshot, hash: 'ads-decided-start'),
            next: matchOverMatch(
              terminalSnapshot,
              winner: GamePlayer.first,
              hash: 'ads-decided-over',
            ),
            legalMoves: const [move],
            resolution: _fallPushResolution,
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(find.text('MATCH COMPLETE'), findsOneWidget);
    expect(ads.events, ['match-decided']);
  });

  testWidgets('holds the new match until the interruption is over', (
    tester,
  ) async {
    const startSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.normal),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'ads-hold-start',
    );
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.damaged),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'ads-hold-terminal',
    );
    final restartedSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: startSnapshot.tiles,
      pieces: startSnapshot.pieces,
      snapshotHash: 'ads-hold-restarted',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final hold = Completer<void>();
    final ads = RecordingAdGateway(hold: hold);
    final engine = FakeRulesEngine(
      initial: [
        matchOf(startSnapshot, hash: 'ads-hold-start'),
        matchOf(restartedSnapshot, hash: 'ads-hold-restarted'),
      ],
      moveResults: [
        moveResultOf(
          next: matchOverMatch(
            terminalSnapshot,
            winner: GamePlayer.first,
            hash: 'ads-hold-over',
          ),
          resolution: _fallPushResolution,
        ),
      ],
      legalMovesFor: (snapshot) =>
          snapshot.snapshotHash == 'ads-hold-start' ? const [move] : const [],
    );

    await tester.pumpWidget(
      MaterialApp(home: GamePage(adGateway: ads, rulesEngine: engine)),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(find.text('MATCH COMPLETE'), findsOneWidget);

    await tester.tap(find.text('Start New Match'));
    await tester.pump();

    expect(ads.events, ['match-decided', 'before-new-match']);
    expect(
      find.text('MATCH COMPLETE'),
      findsOneWidget,
      reason: 'the board must not restart while the interruption is up',
    );

    hold.complete();
    await tester.pump();

    expect(find.text('MATCH COMPLETE'), findsNothing);
    _expectActiveTurn(tester, GamePlayer.first);
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/game/view/game_page_test.dart --plain-name "ad"`

Expected: FAIL, because `GamePage` has no `adGateway` parameter.

- [ ] **Step 4: Add the parameter and the resolved default**

In `lib/game/view/game_page.dart`, add the import next to the other game imports:

```dart
import 'package:ttush_push/game/ads/ad_gateway.dart';
```

Add the parameter after `this._feedback,` in the constructor, and the field after `final RoundFeedback? _feedback;`:

```dart
    this._adGateway,
```

```dart
  final AdGateway? _adGateway;
```

In `_GamePageState`, add the resolved getter next to the other state members. It mirrors how the coach store resolves its default:

```dart
  AdGateway get _adGateway => widget._adGateway ?? const NoAdGateway();
```

- [ ] **Step 5: Report the decided match**

In the replay-completion listener, inside the existing `if (_controller.isMatchOver) {` branch, add the call as the first statement of the branch, before the announcement:

```dart
        if (_controller.isMatchOver) {
          unawaited(_adGateway.matchDecided());
          final snapshot = _controller.snapshot!;
```

The call is deliberately not awaited: nothing may delay the result the player is reading.

- [ ] **Step 6: Hold the new match until the gateway completes**

Replace `_restart` with an asynchronous version, and add the guard field next to the other state members:

```dart
  bool _restartPending = false;
```

```dart
  Future<void> _restart() async {
    if (_restartPending) {
      return;
    }
    _restartPending = true;
    _cancelBotWork();
    try {
      await _adGateway.beforeNewMatch();
    } finally {
      _restartPending = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _mutateAndResetFacing(_controller.restart));
  }
```

The `_restartPending` guard is what stops a second tap during an interruption from queueing a second restart, and the `mounted` check is what stops a page disposed during one from restarting a dead state.

Update the button so the analyzer does not see a discarded future. Find the callback that currently reads `: _controller.isMatchOver ? _restart : _advanceRound` and change the match-over branch:

```dart
                                : _controller.isMatchOver
                                ? () => unawaited(_restart())
                                : _advanceRound,
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/game/view/game_page_test.dart`

Expected: PASS for the whole file, including every pre-existing test. The pre-existing restart test passes unchanged because the default gateway completes immediately, which is the assertion that the shipped behavior did not move.

- [ ] **Step 8: Check formatting and analysis**

Run: `dart format lib/game/view/game_page.dart test/game/view/game_page_test.dart test/support/recording_ad_gateway.dart` then `flutter analyze`

Expected: no analyzer issues. If `discarded_futures` fires anywhere, the call site is missing its `unawaited`.

- [ ] **Step 9: Commit**

```bash
git add lib/game/view/game_page.dart test/game/view/game_page_test.dart test/support/recording_ad_gateway.dart
git commit -m "feat(ads): report the decided match and hold the new match"
```

---

### Task 3: Thread the gateway from the composition root

**Files:**

- Modify: `lib/app/view/app.dart`
- Modify: `lib/game/start/start_page.dart`
- Test: `test/game/start/start_page_test.dart`

**Interfaces:**

- Consumes: `AdGateway` from Task 1, `GamePage({AdGateway? adGateway})` from Task 2, `RecordingAdGateway` from Task 2.
- Produces: `App({AdGateway? adGateway})`, which the flavor entry points use as the build-time swap point.

- [ ] **Step 1: Write the failing test**

Add to `test/game/start/start_page_test.dart`. Its imports gain:

```dart
import 'package:ttush_push/game/view/round_board.dart';

import '../../support/recording_ad_gateway.dart';
```

Add the test, plus the two local helpers it needs. They mirror the private helpers in `game_page_test.dart`; this file cannot see those, and the duplication is two short functions:

```dart
  testWidgets('carries the ad gateway from the app down to the match', (
    tester,
  ) async {
    const startSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.normal),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'threading-start',
    );
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.damaged),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'threading-terminal',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    const resolution = MoveResolution(
      actionKind: MoveActionKind.push,
      mover: PieceTravel(pieceId: 0, fromX: 2, fromY: 2, toX: 2, toY: 1),
      displaced: PieceDisplacement(
        pieceId: 1,
        fromX: 2,
        fromY: 1,
        exitDirection: GameDirection.up,
      ),
      tileTransition: TileTransition(
        x: 2,
        y: 2,
        from: GameTileKind.normal,
        to: GameTileKind.damaged,
      ),
    );
    final ads = RecordingAdGateway();

    await tester.pumpWidget(
      App(
        adGateway: ads,
        rulesEngine: FakeRulesEngine.playing(
          initial: matchOf(startSnapshot, hash: 'threading-start'),
          next: matchOverMatch(
            terminalSnapshot,
            winner: GamePlayer.first,
            hash: 'threading-over',
          ),
          legalMoves: const [move],
          resolution: resolution,
        ),
      ),
    );

The resolution has to be spelled out here because the equivalent constant in `game_page_test.dart` is private to that file, and the default fixture resolution describes a different move than the one this test taps.

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(ads.events, ['match-decided']);
  });
```

Add these two helpers at the bottom of the same file, outside `main()`:

```dart
Offset Function(int x, int y) _cellCenterOf(WidgetTester tester) {
  final boardRect = tester.getRect(
    find.byKey(const Key('round-board-canvas')),
  );
  final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
  final geometry = BoardGeometry.fromSnapshot(board.snapshot, boardRect.size);
  return (x, y) => boardRect.topLeft + geometry.cellCenter(x, y);
}

Future<void> _finishReplay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}
```

`BoardGeometry` lives in `lib/game/view/round_board.dart`, which the import above already brings in, so no second import is needed.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/game/start/start_page_test.dart --plain-name "carries the ad gateway"`

Expected: FAIL, because `App` has no `adGateway` parameter.

- [ ] **Step 3: Forward the gateway through App**

In `lib/app/view/app.dart`, add the import, the parameter, and the field to both `App` and `AppView`, following how `_rulesEngine` is already carried:

```dart
import 'package:ttush_push/game/ads/ad_gateway.dart';
```

```dart
class App extends StatelessWidget {
  const App({super.key, this._rulesEngine, this._adGateway});

  final RulesEngine? _rulesEngine;
  final AdGateway? _adGateway;

  @override
  Widget build(BuildContext context) {
    return AppView(rulesEngine: _rulesEngine, adGateway: _adGateway);
  }
}
```

`AppView` takes the same pair and passes both on:

```dart
      home: StartPage(rulesEngine: _rulesEngine, adGateway: _adGateway),
```

- [ ] **Step 4: Forward the gateway through StartPage**

In `lib/game/start/start_page.dart`, add the import, add `this.adGateway` to the constructor beside `this.rulesEngine`, declare `final AdGateway? adGateway;`, and pass it where the page pushes the match:

```dart
            GamePage(
              rulesEngine: widget.rulesEngine,
              adGateway: widget.adGateway,
              opponent: _opponent,
            ),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/game/start/start_page_test.dart`

Expected: PASS for the whole file. A reviewer can confirm the test is not vacuous by deleting `adGateway: widget.adGateway` from `StartPage` and seeing this test fail.

- [ ] **Step 6: Prove the test fails without the wiring**

Temporarily delete `adGateway: widget.adGateway` from `StartPage`, run the same command, and confirm the new test fails. Restore the line and confirm it passes again.

This step is the point of the task: a threading test that cannot fail proves nothing.

- [ ] **Step 7: Run the whole suite, formatting, and analysis**

Run: `dart format lib/app/view/app.dart lib/game/start/start_page.dart test/game/start/start_page_test.dart`, then `flutter analyze`, then `flutter test`

Expected: no analyzer issues, and the whole suite green.

- [ ] **Step 8: Commit**

```bash
git add lib/app/view/app.dart lib/game/start/start_page.dart test/game/start/start_page_test.dart
git commit -m "feat(ads): thread the ad gateway from the composition root"
```

**The flavor entry points are deliberately not edited.** `lib/main_development.dart`, `lib/main_staging.dart`, and `lib/main_production.dart` construct `App()` with no arguments, which resolves to `NoAdGateway` and is the shipped behavior this plan promises. They are the swap point named in the Spec: adopting a provider changes one line in whichever of them should carry it, and that change belongs to the adapter's own work, not here.

---

## Final Verification

Run the aggregate gate before opening the pull request:

```shell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
merry run check
```

`merry run check` is the local gate that CI does not fully reproduce, and its `parity` step reports either `parity: covered N runtime(s)` or `parity: SKIPPED`. A skip is acceptable here because this plan changes no mobile runner or build integration.

## What This Plan Does Not Do

Every item below belongs to the first real adapter, and the Spec's `Constraints on the First Real Adapter` section states the rules each one inherits.

- No SDK, no dependency, no network call, no `INTERNET` permission.
- No consent collection, no tracking prompt, no privacy policy, no store declarations.
- No change to the store descriptions, which currently promise the player that the game has no ads.
- No banner, no rewarded placement, no frequency policy, and no runtime provider switching.
