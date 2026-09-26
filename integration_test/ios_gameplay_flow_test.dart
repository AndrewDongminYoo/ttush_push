import 'dart:io';

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

const _expectedEngine = FrbRulesEngine();
const _maxMovesPerMatch = 240;
const _maxFramesPerMove = 400;

const _expectedStartingPieces = <rust.GamePiece>[
  rust.GamePiece(id: 0, owner: rust.GamePlayer.first, x: 1, y: 0),
  rust.GamePiece(id: 1, owner: rust.GamePlayer.first, x: 3, y: 0),
  rust.GamePiece(id: 2, owner: rust.GamePlayer.second, x: 1, y: 4),
  rust.GamePiece(id: 3, owner: rust.GamePlayer.second, x: 3, y: 4),
];

const _baselinePlayableCells = <(int, int)>[
  (0, 0),
  (0, 1),
  (0, 2),
  (0, 3),
  (0, 4),
  (1, 0),
  (1, 1),
  (1, 2),
  (1, 3),
  (1, 4),
  (2, 0),
  (2, 1),
  (2, 2),
  (2, 3),
  (2, 4),
  (3, 0),
  (3, 1),
  (3, 2),
  (3, 3),
  (3, 4),
  (4, 0),
  (4, 1),
  (4, 2),
  (4, 3),
  (4, 4),
];

const _clippedCornersPlayableCells = <(int, int)>[
  (0, 1),
  (0, 2),
  (0, 3),
  (1, 0),
  (1, 1),
  (1, 2),
  (1, 3),
  (1, 4),
  (2, 0),
  (2, 1),
  (2, 2),
  (2, 3),
  (2, 4),
  (3, 0),
  (3, 1),
  (3, 2),
  (3, 3),
  (3, 4),
  (4, 1),
  (4, 2),
  (4, 3),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(RustLib.init);
  tearDownAll(RustLib.dispose);
  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
  });

  for (final board in BuiltInBoard.values) {
    testWidgets(
      'English local ${board.id} match uses real board taps through a result',
      (tester) => _runEnglishLocalScenario(tester, binding, board),
      timeout: const Timeout(Duration(minutes: 20)),
    );

    testWidgets(
      'Korean Expert ${board.id} match keeps Flutter text scale usable',
      (tester) => _runKoreanExpertScenario(tester, binding, board),
      timeout: const Timeout(Duration(minutes: 20)),
    );
  }
}

Future<void> _runEnglishLocalScenario(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  BuiltInBoard board,
) async {
  tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

  final prefix = '${board.id}-en-local';
  await tester.pumpWidget(App(key: ValueKey('$prefix-app')));
  await tester.pumpAndSettle();
  await _tapSetupControl(
    tester,
    find.byKey(const Key('start-mode-two-players')),
  );
  await _selectBoard(tester, board);
  await _prepareScreenshotCapture(tester, binding);
  await _capture(tester, binding, '$prefix-setup');
  await _tapSetupControl(tester, find.byKey(const Key('start-match')));
  await _waitForBoard(tester);

  final initial = _expectedEngine.initialMatch(board.definition.rules);
  await _waitForBoardHash(tester, initial.round.snapshotHash);
  _expectOpeningBoard(tester, initial, board);
  await _capture(tester, binding, '$prefix-board');
  await _exerciseCoachAndHelp(tester, binding, prefix: prefix);
  if (board == BuiltInBoard.clippedCorners) {
    await _expectMissingCornerTapIsIgnored(tester);
  }

  await _playMatch(
    tester,
    binding,
    board: board,
    initial: initial,
    prefix: prefix,
    expertOpponent: false,
  );

  final l10n = localizationsOf(tester.element(find.byType(GamePage)));
  await tester.tap(find.text(l10n.newMatch));
  final fresh = _expectedEngine.initialMatch(board.definition.rules);
  await _waitForBoardHash(tester, fresh.round.snapshotHash);
  _expectOpeningBoard(tester, fresh, board);
  await _capture(tester, binding, '$prefix-restart');

  await tester.tap(find.byKey(const Key('leave-match')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('leave-match-dialog')), findsOneWidget);
  await _capture(tester, binding, '$prefix-leave-dialog');
  await tester.tap(find.byKey(const Key('leave-match-cancel')));
  await tester.pumpAndSettle();
  expect(find.byType(GamePage), findsOneWidget);
  await tester.tap(find.byKey(const Key('leave-match')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('leave-match-confirm')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('start-title')), findsOneWidget);
}

Future<void> _runKoreanExpertScenario(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  BuiltInBoard board,
) async {
  tester.binding.platformDispatcher.localesTestValue = const [Locale('ko')];
  tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.binding.platformDispatcher.clearTextScaleFactorTestValue);

  final prefix = '${board.id}-ko-expert-flutter-text-scale-2p0';
  await tester.pumpWidget(App(key: ValueKey('$prefix-app')));
  await tester.pumpAndSettle();
  await _tapSetupControl(tester, find.byKey(const Key('start-mode-versus-ai')));
  await _selectBoard(tester, board);
  await _prepareScreenshotCapture(tester, binding);
  await _capture(tester, binding, '$prefix-board-choice');
  await _tapSetupControl(
    tester,
    find.byKey(const Key('start-difficulty-strategic')),
  );
  await _capture(tester, binding, '$prefix-setup');
  await _tapSetupControl(tester, find.byKey(const Key('start-match')));
  await _waitForBoard(tester);

  final initial = _expectedEngine.initialMatch(board.definition.rules);
  await _waitForBoardHash(tester, initial.round.snapshotHash);
  _expectOpeningBoard(tester, initial, board);
  await _capture(tester, binding, '$prefix-board');
  await _dismissCoachIfVisible(tester);

  await _playMatch(
    tester,
    binding,
    board: board,
    initial: initial,
    prefix: prefix,
    expertOpponent: true,
  );
}

Future<void> _playMatch(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required BuiltInBoard board,
  required rust.MatchSnapshot initial,
  required String prefix,
  required bool expertOpponent,
}) async {
  var expected = initial;
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
      expected = _expectedEngine.advanceRound(expected);
      await _waitForBoardHash(tester, expected.round.snapshotHash);
      _expectOpeningBoard(tester, expected, board);
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
      final expertMove = await _expectedEngine.chooseBotMove(
        expected,
        rust.BotPolicy.strategic,
      );
      expect(expertMove, isNotNull);
      expected = _expectedEngine.applyMove(expected, expertMove!).snapshot;
      _expectVisibleSnapshot(tester, expected);
      moves++;
      debugPrint(
        'Expert response for ${board.id} observed after '
        '${stopwatch.elapsedMilliseconds} ms wall-clock wait across '
        '$responseFrames test pumps; this is UI response timing, not a CPU '
        'benchmark. Move $moves, phase ${expected.phase.name}.',
      );
      if (!capturedGameplay && expected.phase == rust.GameMatchPhase.playing) {
        await _capture(tester, binding, '$prefix-gameplay');
        capturedGameplay = true;
      }
      continue;
    }

    final legalMoves = _expectedEngine.legalMoves(expected);
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
    expected = _expectedEngine.applyMove(expected, move).snapshot;
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
  expect(capturedGameplay, isTrue);
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
  IntegrationTestWidgetsFlutterBinding binding, {
  required String prefix,
}) async {
  await tester.tap(find.byKey(const Key('coach-help')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('first-play-coach')), findsOneWidget);
  final firstMessage = tester
      .widget<Semantics>(find.byKey(const Key('coach-message')))
      .properties
      .label;
  await _capture(tester, binding, '$prefix-coach-step-1');
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
  await _capture(tester, binding, '$prefix-help-reopened');
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

Future<void> _tapSetupControl(WidgetTester tester, Finder control) async {
  expect(control, findsOneWidget);
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _selectBoard(WidgetTester tester, BuiltInBoard board) {
  return _tapSetupControl(tester, find.byKey(Key('start-board-${board.id}')));
}

Future<void> _prepareScreenshotCapture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  if (!Platform.isAndroid) {
    return;
  }
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
}

List<(int, int)> _expectedPlayableCells(BuiltInBoard board) => switch (board) {
  BuiltInBoard.baseline => _baselinePlayableCells,
  BuiltInBoard.clippedCorners => _clippedCornersPlayableCells,
};

void _expectOpeningBoard(
  WidgetTester tester,
  rust.MatchSnapshot expected,
  BuiltInBoard board,
) {
  _expectVisibleSnapshot(tester, expected);
  final visible = tester.widget<RoundBoard>(find.byType(RoundBoard));
  expect(
    visible.snapshot.tiles.map((tile) => (tile.x, tile.y)),
    unorderedEquals(_expectedPlayableCells(board)),
    reason: '${board.id} must keep its complete topology',
  );
  expect(
    visible.snapshot.tiles.map((tile) => tile.kind),
    everyElement(rust.GameTileKind.normal),
    reason: '${board.id} must reset every tile for a new round',
  );
  expect(
    visible.snapshot.pieces,
    unorderedEquals(_expectedStartingPieces),
    reason: '${board.id} must reset its starting pieces',
  );
  expect(
    expected.startingPieces,
    unorderedEquals(_expectedStartingPieces),
    reason: 'the independent engine must retain ${board.id} starting pieces',
  );
}

Future<void> _expectMissingCornerTapIsIgnored(WidgetTester tester) async {
  final before = tester.widget<RoundBoard>(find.byType(RoundBoard));
  expect(
    before.snapshot.tiles.any((tile) => tile.x == 0 && tile.y == 0),
    isFalse,
    reason: 'the clipped-corners board must not render its top-left corner',
  );
  final selectedPiece = before.snapshot.pieces.singleWhere(
    (piece) => piece.id == 0,
  );
  final initialHash = before.snapshot.snapshotHash;

  await _tapCell(tester, before.snapshot, selectedPiece.x, selectedPiece.y);
  expect(
    tester.widget<RoundBoard>(find.byType(RoundBoard)).selectedPieceId,
    selectedPiece.id,
    reason: 'the real starting piece must be selected before the corner tap',
  );

  await _tapCell(tester, before.snapshot, 0, 0);
  await tester.pumpAndSettle();
  final after = tester.widget<RoundBoard>(find.byType(RoundBoard));
  expect(
    after.snapshot.snapshotHash,
    initialHash,
    reason: 'tapping a missing corner must not commit a move',
  );
  expect(
    after.selectedPieceId,
    selectedPiece.id,
    reason: 'a missing corner must not clear the selected real piece',
  );
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
