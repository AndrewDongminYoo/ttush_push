# Runtime Board Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reset the complete match lifecycle when a retained `GamePage` receives a different `BoardDefinition` instance.

**Architecture:** Keep replacement ownership in `GamePage`, which already owns the `MatchController`, bot timer, replay controller, background, coach state, and feedback resource.
Replace only the match-scoped controller and presentation state.
Keep Rust, the bridge, and child board rendering unchanged.

**Tech Stack:** Flutter 3.44, Dart 3.12, Flutter widget tests, and the existing `FakeRulesEngine` Test Seam.

**Spec:** `docs/specs/0004-runtime-board-replacement/spec.md`

## Global Constraints

- Compare `BoardDefinition` instances by identity.
- Preserve the current match when the identical instance is rebuilt.
- Reset match state, opponent selection, bot work, and replay work when the instance changes.
- Preserve the retained page State, coach state, coach store, and feedback resource.
- Do not change Rust, generated bridge files, `BoardDefinition`, `RulesEngine`, `MatchController`, `RoundBoard`, dependencies, assets, or localization.
- Do not commit until the exact branch diff passes the local adversarial review.

---

## File Structure

| Path                                                                | Responsibility                                                         |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `lib/game/view/game_page.dart`                                      | Own the BoardDefinition replacement lifecycle.                         |
| `test/game/view/game_page_test.dart`                                | Prove same-State replacement, timer cancellation, and replay abortion. |
| `docs/specs/0004-runtime-board-replacement/interview-ledger.md`     | Record the replacement policy and its sources.                         |
| `docs/specs/0004-runtime-board-replacement/spec.md`                 | Define the requirements and scope boundary.                            |
| `docs/plans/2026-09-01-runtime-board-replacement-implementation.md` | Define the TDD and verification sequence.                              |

## Task 1: Replace the match lifecycle on a BoardDefinition change

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `test/game/view/game_page_test.dart`

**Interfaces:**

- Consumes: `GamePage._boardDefinition`, `GamePage._rulesEngine`, `MatchController`, `_botTimer`, `_replayController`, and `_replayGeneration`.
- Produces: `GamePage.didUpdateWidget` and `_createMatchController()`.

- [x] **Step 1: Add the same-State A-to-B failing regression.**

Rebuild one keyed `GamePage` through repeated `pumpWidget` calls.
Use one `FakeRulesEngine` with ordered A and B initial snapshots.
Rebuild once with the identical A instance, then select a bot and replace A with B before the 450 millisecond pause ends.

Assert all of these results:

```dart
expect(tester.state(find.byType(GamePage)), same(stateBefore));
expect(engine.initialDefinitions, [definitionA.rules, definitionB.rules]);
expect(engine.botRequests, isEmpty);
expect(tester.widget<RoundBoard>(find.byType(RoundBoard)).snapshot, snapshotB);
expect((background.image as AssetImage).assetName, definitionB.backgroundAssetPath);
expect(_inPanel('second', 'Opponent: Human'), findsOneWidget);
```

- [x] **Step 2: Run the focused regression and confirm the current mismatch.**

Run:

```bash
flutter test test/game/view/game_page_test.dart --plain-name 'restarts the retained page when its BoardDefinition changes'
```

Expected: FAIL because the current State keeps the A controller and only renders the B background.

- [x] **Step 3: Add the replay-abortion failing regression.**

Start a legal A move through the real board tap path.
Replace A with B before the 540 millisecond replay completes.
Advance time beyond the old replay duration.

Assert these results before and after the time advance:

```dart
expect(tester.widget<RoundBoard>(find.byType(RoundBoard)).playback, isNull);
expect(tester.widget<RoundBoard>(find.byType(RoundBoard)).snapshot, snapshotB);
```

- [x] **Step 4: Implement the minimum lifecycle transition.**

Use one constructor helper from `initState` and `didUpdateWidget`:

```dart
MatchController _createMatchController() =>
    MatchController(
      widget._rulesEngine,
      boardDefinition: widget._boardDefinition.rules,
    )..initialize();
```

Add the identity guard and reset only match-scoped state:

```dart
@override
void didUpdateWidget(covariant GamePage oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (identical(oldWidget._boardDefinition, widget._boardDefinition)) {
    return;
  }
  _botTimer?.cancel();
  _botTimer = null;
  _replayGeneration++;
  _replayController.stop();
  _replayResolution = null;
  _controller = _createMatchController();
}
```

Change `_controller` from `late final` to `late`.
Do not recreate the coach store, replay controller, or feedback resource.

- [x] **Step 5: Run the focused tests and prove both regressions are live.**

Run:

```bash
flutter test test/game/view/game_page_test.dart --plain-name 'BoardDefinition'
flutter test test/game/view/game_page_test.dart
```

Before trusting the final pass, temporarily remove `_replayController.stop()` and confirm that the replay regression needs six settle pumps and fails.
Restore the replay stop and rerun the focused tests.

- [x] **Step 6: Run scoped formatting and the complete local gate.**

Run:

```bash
dart format lib/game/view/game_page.dart test/game/view/game_page_test.dart
flutter analyze
merry run check
```

Expected: PASS.
The final `merry run check` reads formatting, analysis, Flutter tests, Rust checks, the host bridge, and Trunk.
Native packaging remains a separate property and is not required for this platform-neutral lifecycle change.

## Plan Self-Review

- Spec coverage: Task 1 covers every requirement in `docs/specs/0004-runtime-board-replacement/spec.md`.
- Placeholder scan: The plan contains no deferred implementation step.
- Type consistency: Both initialization paths create `MatchController` from the current widget's `RulesEngine` and `BoardDefinition.rules`.
