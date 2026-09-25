import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/app/view/app.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;
import 'package:ttush_push/src/rust/frb_generated.dart';

const _engine = FrbRulesEngine();
const _maxMovesPerMatch = 240;
const _maxFramesPerMove = 400;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(RustLib.init);
  tearDownAll(RustLib.dispose);
  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
  });

  testWidgets('English local match uses real board taps through a result', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const App(key: ValueKey('en-local-app')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-mode-two-players')), findsOneWidget);
    await _capture(tester, binding, '01-en-local-setup');
    await tester.tap(find.byKey(const Key('start-match')));
    await _waitForBoard(tester);

    await _exerciseCoachAndHelp(tester, binding);
    await _playMatch(
      tester,
      binding,
      prefix: 'en-local',
      expertOpponent: false,
    );

    final l10n = localizationsOf(tester.element(find.byType(GamePage)));
    await tester.tap(find.text(l10n.newMatch));
    final fresh = _engine.initialMatch(baselineBoardDefinition.rules);
    await _waitForBoardHash(tester, fresh.round.snapshotHash);
    _expectVisibleSnapshot(tester, fresh);
    await _capture(tester, binding, '08-en-local-restart');

    await tester.tap(find.byKey(const Key('leave-match')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leave-match-dialog')), findsOneWidget);
    await _capture(tester, binding, '09-en-local-leave-dialog');
    await tester.tap(find.byKey(const Key('leave-match-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(GamePage), findsOneWidget);
    await tester.tap(find.byKey(const Key('leave-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-match-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-title')), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('Korean Expert match and Flutter text scale override', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ko')];
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(const App(key: ValueKey('ko-expert-app')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-difficulty-strategic')),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('start-difficulty-strategic')));
    await tester.pumpAndSettle();
    await _capture(
      tester,
      binding,
      '10-ko-expert-flutter-text-scale-2p0-setup',
    );
    await tester.ensureVisible(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-match')));
    await _waitForBoard(tester);
    await _capture(
      tester,
      binding,
      '11-ko-expert-flutter-text-scale-2p0-board',
    );
    await _dismissCoachIfVisible(tester);

    await _playMatch(
      tester,
      binding,
      prefix: 'ko-expert-flutter-text-scale-2p0',
      expertOpponent: true,
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> _playMatch(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String prefix,
  required bool expertOpponent,
}) async {
  var expected = _engine.initialMatch(baselineBoardDefinition.rules);
  _expectVisibleSnapshot(tester, expected);
  var moves = 0;
  var capturedGameplay = false;
  var capturedRound = false;

  while (expected.phase != rust.GameMatchPhase.matchOver) {
    expect(moves, lessThan(_maxMovesPerMatch), reason: '$prefix move limit');
    if (expected.phase == rust.GameMatchPhase.roundOver) {
      expect(find.byKey(const Key('result-scope-round')), findsOneWidget);
      if (!capturedRound) {
        await _capture(tester, binding, '$prefix-round-result');
        capturedRound = true;
      }
      final beforeWins = (expected.firstPlayerWins, expected.secondPlayerWins);
      final l10n = localizationsOf(tester.element(find.byType(GamePage)));
      await tester.tap(find.text(l10n.nextRound));
      expected = _engine.advanceRound(expected);
      await _waitForBoardHash(tester, expected.round.snapshotHash);
      _expectVisibleSnapshot(tester, expected);
      expect(
        (expected.firstPlayerWins, expected.secondPlayerWins),
        beforeWins,
        reason: 'round transition must keep the earned score',
      );
      continue;
    }

    if (expertOpponent &&
        expected.round.currentPlayer == rust.GamePlayer.second) {
      final previousHash = expected.round.snapshotHash;
      final stopwatch = Stopwatch()..start();
      final responseFrames = await _waitForBoardChange(tester, previousHash);
      stopwatch.stop();
      final expertMove = await _engine.chooseBotMove(
        expected,
        rust.BotPolicy.strategic,
      );
      expect(expertMove, isNotNull);
      expected = _engine.applyMove(expected, expertMove!).snapshot;
      _expectVisibleSnapshot(tester, expected);
      moves++;
      debugPrint(
        'Expert response observed after $responseFrames pump frames '
        '(${responseFrames * 100} ms test-clock, '
        '${stopwatch.elapsedMilliseconds} ms wall-clock wait) '
        'on simulator, move $moves, phase ${expected.phase.name}',
      );
      if (!capturedGameplay && expected.phase == rust.GameMatchPhase.playing) {
        await _capture(tester, binding, '$prefix-gameplay');
        capturedGameplay = true;
      }
      continue;
    }

    final legalMoves = _engine.legalMoves(expected);
    expect(legalMoves, isNotEmpty, reason: 'a playing turn needs a legal move');
    final move = legalMoves.first;
    final piece = expected.round.pieces.singleWhere(
      (candidate) => candidate.id == move.pieceId,
    );
    await _tapCell(tester, expected.round, piece.x, piece.y);
    final selected = tester.widget<RoundBoard>(find.byType(RoundBoard));
    expect(selected.selectedPieceId, move.pieceId);
    expect(selected.legalMoves, contains(move));
    if (moves == 0) {
      await _capture(tester, binding, '$prefix-selection');
    }

    final destination = switch (move.direction) {
      rust.GameDirection.up => (piece.x, piece.y - 1),
      rust.GameDirection.down => (piece.x, piece.y + 1),
      rust.GameDirection.left => (piece.x - 1, piece.y),
      rust.GameDirection.right => (piece.x + 1, piece.y),
    };
    final previousHash = expected.round.snapshotHash;
    expected = _engine.applyMove(expected, move).snapshot;
    await _tapCell(tester, selected.snapshot, destination.$1, destination.$2);
    await _waitForBoardChange(tester, previousHash);
    _expectVisibleSnapshot(tester, expected);
    moves++;
    if (!expertOpponent &&
        !capturedGameplay &&
        expected.phase == rust.GameMatchPhase.playing) {
      await _capture(tester, binding, '$prefix-gameplay');
      capturedGameplay = true;
    }
  }

  expect(moves, greaterThan(0));
  expect(capturedRound, isTrue);
  expect(find.byKey(const Key('result-scope-match')), findsOneWidget);
  expect(expected.matchWinner, isNotNull);
  final winnerWins = expected.matchWinner == rust.GamePlayer.first
      ? expected.firstPlayerWins
      : expected.secondPlayerWins;
  expect(winnerWins, 2);
  await _capture(tester, binding, '$prefix-match-result');
}

Future<void> _exerciseCoachAndHelp(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  await tester.tap(find.byKey(const Key('coach-help')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('first-play-coach')), findsOneWidget);
  final firstMessage = tester
      .widget<Semantics>(find.byKey(const Key('coach-message')))
      .properties
      .label;
  await _capture(tester, binding, '02-en-local-coach-step-1');
  await tester.tap(find.byKey(const Key('coach-next')));
  await tester.pumpAndSettle();
  final secondMessage = tester
      .widget<Semantics>(find.byKey(const Key('coach-message')))
      .properties
      .label;
  expect(secondMessage, isNot(firstMessage));
  await tester.tap(find.byKey(const Key('coach-next')));
  await tester.pumpAndSettle();
  final thirdMessage = tester
      .widget<Semantics>(find.byKey(const Key('coach-message')))
      .properties
      .label;
  expect(thirdMessage, isNot(secondMessage));
  await tester.tap(find.byKey(const Key('coach-next')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('first-play-coach')), findsNothing);

  await tester.tap(find.byKey(const Key('coach-help')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('first-play-coach')), findsOneWidget);
  await _capture(tester, binding, '03-en-local-help-reopened');
  await tester.tap(find.byKey(const Key('coach-dismiss')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('first-play-coach')), findsNothing);
}

Future<void> _dismissCoachIfVisible(WidgetTester tester) async {
  await tester.pump();
  final dismiss = find.byKey(const Key('coach-dismiss'));
  if (dismiss.evaluate().isNotEmpty) {
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapCell(
  WidgetTester tester,
  rust.GameSnapshot snapshot,
  int x,
  int y,
) async {
  final canvas = find.byKey(const Key('round-board-canvas'));
  final boardRect = tester.getRect(canvas);
  final geometry = BoardGeometry.fromSnapshot(snapshot, boardRect.size);
  final center = geometry.cellCenter(x, y);
  expect(geometry.cellAt(center), (x, y));
  await tester.tapAt(boardRect.topLeft + center);
  await tester.pump();
}

void _expectVisibleSnapshot(WidgetTester tester, rust.MatchSnapshot expected) {
  final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
  expect(board.snapshot.snapshotHash, expected.round.snapshotHash);
  expect(
    find.byKey(Key('round-wins-first-${expected.firstPlayerWins}')),
    findsOneWidget,
  );
  expect(
    find.byKey(Key('round-wins-second-${expected.secondPlayerWins}')),
    findsOneWidget,
  );
  switch (expected.phase) {
    case rust.GameMatchPhase.playing:
      expect(find.byKey(const Key('result-overlay')), findsNothing);
    case rust.GameMatchPhase.roundOver:
      expect(find.byKey(const Key('result-scope-round')), findsOneWidget);
    case rust.GameMatchPhase.matchOver:
      expect(find.byKey(const Key('result-scope-match')), findsOneWidget);
  }
}

Future<void> _waitForBoard(WidgetTester tester) async {
  final board = find.byType(RoundBoard);
  for (var frame = 0; frame < 100 && board.evaluate().isEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(board, findsOneWidget);
  final sprites = find.byKey(const Key('round-board-production-sprites'));
  for (var frame = 0; frame < 100 && sprites.evaluate().isEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(sprites, findsOneWidget);
  // Cached sprites can appear before the route's entry transition finishes.
  await tester.pumpAndSettle();
}

Future<void> _waitForBoardHash(WidgetTester tester, String hash) async {
  for (var frame = 0; frame < _maxFramesPerMove; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester
            .widget<RoundBoard>(find.byType(RoundBoard))
            .snapshot
            .snapshotHash ==
        hash) {
      return;
    }
  }
  expect(
    tester.widget<RoundBoard>(find.byType(RoundBoard)).snapshot.snapshotHash,
    hash,
    reason: 'UI did not publish the expected Rust snapshot',
  );
}

Future<int> _waitForBoardChange(
  WidgetTester tester,
  String previousHash,
) async {
  for (var frame = 0; frame < _maxFramesPerMove; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester
            .widget<RoundBoard>(find.byType(RoundBoard))
            .snapshot
            .snapshotHash !=
        previousHash) {
      return frame + 1;
    }
  }
  expect(
    tester.widget<RoundBoard>(find.byType(RoundBoard)).snapshot.snapshotHash,
    isNot(previousHash),
    reason: 'UI tap or Expert response did not commit a move',
  );
  return _maxFramesPerMove;
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await tester.pumpAndSettle();
  final bytes = await binding.takeScreenshot(name);
  expect(bytes, isNotEmpty);
}
