import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

void main() {
  testWidgets('renders the current player and board from RulesEngine', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'initial',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    _expectActiveTurn(GamePlayer.first);
    expect(find.byType(RoundBoard), findsOneWidget);
    // The engine starts the first player on row 0, so their panel has to be
    // the top one for each player to sit behind their own pieces.
    expect(
      tester.getRect(find.byKey(const Key('player-panel-first'))).top,
      lessThan(
        tester.getRect(find.byKey(const Key('player-panel-second'))).top,
      ),
    );
  });

  testWidgets('retries an initial bridge failure', (tester) async {
    const readySnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'ready',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine(
            initial: [StateError('bridge unavailable'), matchOf(readySnapshot)],
          ),
        ),
      ),
    );

    expect(find.text('Unable to start round'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    _expectActiveTurn(GamePlayer.first);
  });

  testWidgets('blocks terminal board input and restarts the round', (
    tester,
  ) async {
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'terminal',
    );
    const restartedSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'restarted',
    );
    final engine = FakeRulesEngine(
      initial: [
        matchOverMatch(terminalSnapshot, winner: GamePlayer.first),
        matchOf(restartedSnapshot),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    expect(_inOverlay('Player 1'), findsOneWidget);
    expect(find.text('wins the match'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    await tester.tapAt(boardRect.center);

    expect(engine.appliedMoves, isEmpty);

    await tester.tap(find.text('New Match'));
    await tester.pump();

    _expectActiveTurn(GamePlayer.first);
  });

  testWidgets('applies only the selected legal destination', (tester) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'next'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    Offset cellCenter(int x, int y) {
      return Offset(
        boardRect.left + boardRect.width * (x + 0.5) / 5,
        boardRect.top + boardRect.height * (y + 0.5) / 5,
      );
    }

    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    _expectActiveTurn(GamePlayer.second);
  });

  testWidgets(
    'clears selection after a tap outside the current player pieces',
    (
      tester,
    ) async {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
        snapshotHash: 'clear-selection',
      );
      const nextSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
        snapshotHash: 'should-not-apply',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine.playing(
        initial: matchOf(initialSnapshot),
        next: matchOf(nextSnapshot, hash: 'next'),
        legalMoves: const [move],
      );

      await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

      final boardRect = tester.getRect(
        find.byKey(const Key('round-board-canvas')),
      );
      Offset cellCenter(int x, int y) {
        return Offset(
          boardRect.left + boardRect.width * (x + 0.5) / 5,
          boardRect.top + boardRect.height * (y + 0.5) / 5,
        );
      }

      await tester.tapAt(cellCenter(0, 0));
      await tester.tapAt(cellCenter(1, 0));
      await tester.tapAt(cellCenter(0, 1));
      await tester.pump();

      expect(engine.appliedMoves, isEmpty);
      _expectActiveTurn(GamePlayer.first);
    },
  );

  testWidgets('pushes an opposing piece standing on a legal destination', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'push-precedence',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'pushed',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'next'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    Offset cellCenter(int x, int y) {
      return Offset(
        boardRect.left + boardRect.width * (x + 0.5) / 5,
        boardRect.top + boardRect.height * (y + 0.5) / 5,
      );
    }

    await tester.tapAt(cellCenter(2, 2));
    // The destination is occupied by the opponent, so this tap must push
    // rather than fall through to selecting their piece.
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    _expectActiveTurn(GamePlayer.second);
  });

  testWidgets('shows an immobilization result over the final board', (
    tester,
  ) async {
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      winner: GamePlayer.second,
      winReason: GameWinReason.immobilization,
      snapshotHash: 'immobilized',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOverMatch(
              terminalSnapshot,
              winner: GamePlayer.second,
              reason: GameWinReason.immobilization,
            ),
          ),
        ),
      ),
    );

    expect(_inOverlay('Player 2'), findsOneWidget);
    expect(find.text('wins the match'), findsOneWidget);
    expect(find.text('by immobilization'), findsOneWidget);
    // The position that ended the round stays readable underneath.
    expect(find.byType(RoundBoard), findsOneWidget);
    expect(find.text('Your turn'), findsNothing);
  });

  testWidgets('keeps the board square on a small and a large screen', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'layout',
    );
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'layout-terminal',
    );
    addTearDown(tester.view.reset);

    for (final size in const [
      Size(320, 480),
      Size(1024, 1280),
      Size(568, 320),
    ]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
          ),
        ),
      );

      final boardRect = tester.getRect(
        find.byKey(const Key('round-board-canvas')),
      );

      expect(boardRect.width, boardRect.height, reason: 'at $size');
      expect(boardRect.width, greaterThan(0), reason: 'at $size');
      expect(
        boardRect.width,
        lessThanOrEqualTo(size.width),
        reason: 'at $size',
      );
      expect(tester.takeException(), isNull, reason: 'ongoing at $size');

      // The overlay carries its own overflow risk, so it is laid out here too.
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            key: const Key('terminal'),
            rulesEngine: FakeRulesEngine.playing(
              initial: matchOverMatch(
                terminalSnapshot,
                winner: GamePlayer.first,
              ),
            ),
          ),
        ),
      );

      expect(find.text('New Match'), findsOneWidget, reason: 'at $size');
      expect(tester.takeException(), isNull, reason: 'terminal at $size');
    }
  });

  testWidgets('keeps a panel at its own height when space is short', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'landscape',
    );
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(568, 320)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    // A panel squeezed below its content height deforms the player mark
    // before it ever reports an overflow, so the mark is measured directly.
    final mark = tester.getRect(
      find.byKey(const Key('player-mark-first')),
    );

    expect(mark.width, mark.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feels a selection and then an ordinary move', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'haptic-start',
    );
    const afterMove = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 3),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'haptic-moved',
    );
    const moveDown = GameMove(pieceId: 0, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: matchOf(afterMove, hash: 'next'),
            legalMoves: const [moveDown],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, ['select']);

    felt.clear();
    await tester.tapAt(cellCenter(2, 3));
    await tester.pump();

    expect(felt, ['move']);
  });

  testWidgets('feels the won round rather than the push that won it', (
    tester,
  ) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'haptic-winning',
    );
    const afterPush = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'haptic-won',
    );
    const pushUp = GameMove(pieceId: 0, direction: GameDirection.up);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: roundOverMatch(afterPush, winner: GamePlayer.first),
            legalMoves: const [pushUp],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();

    expect(felt, ['select', 'win']);
  });

  testWidgets('feels a push that leaves the round ongoing', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'push-ongoing',
    );
    const afterPush = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'push-ongoing-next',
    );
    const pushUp = GameMove(pieceId: 0, direction: GameDirection.up);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: matchOf(afterPush, hash: 'next'),
            legalMoves: const [pushUp],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();

    expect(felt, [
      'select',
      'push',
    ]);
  });

  testWidgets('stays silent when a tap changes nothing', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0),
      ],
      snapshotHash: 'silent',
    );
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(start)),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);

    // An empty cell, an opposing piece, and an own piece with no legal move.
    await tester.tapAt(cellCenter(4, 4));
    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('stays silent when applying a move fails', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'failing',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine(
            initial: [matchOf(start)],
            moveResults: [StateError('bridge unavailable')],
            legalMovesFor: (_) => const [move],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(2, 2));
    felt.clear();
    await tester.tapAt(cellCenter(2, 3));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('says nothing when the same piece is tapped again', (
    tester,
  ) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'reselect',
    );
    const moveDown = GameMove(pieceId: 0, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: matchOf(start, hash: 'next'),
            legalMoves: const [moveDown],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, ['select']);

    felt.clear();
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('feels a move that lands on retry', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'retry-feel',
    );
    const afterPush = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'retry-feel-next',
    );
    const pushUp = GameMove(pieceId: 0, direction: GameDirection.up);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine(
            initial: [matchOf(start)],
            moveResults: [
              StateError('bridge unavailable'),
              matchOf(afterPush, hash: 'next'),
            ],
            legalMovesFor: (_) => const [pushUp],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    felt.clear();

    // The board advances on retry, so it must feel like the push it is.
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(felt, ['push']);
  });

  testWidgets('says nothing when retrying initialization', (tester) async {
    const ready = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'init-retry',
    );
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine(
            initial: [StateError('bridge unavailable'), ready],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('shows a finished round and advances past it', (tester) async {
    const finalBoard = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.damaged)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'round-1-final',
    );
    const nextBoard = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'round-2',
    );
    final engine = FakeRulesEngine(
      initial: [roundOverMatch(finalBoard, winner: GamePlayer.first)],
      advanceResults: [matchOf(nextBoard, firstWins: 1, hash: 'round-2-match')],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    expect(_inOverlay('Player 1'), findsOneWidget);
    expect(find.text('takes the round'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    expect(find.text('1 - 0'), findsOneWidget);
    // The board that ended the round is what the result sits over.
    expect(find.byType(RoundBoard), findsOneWidget);
    // Neither player is on turn while the result is up.
    expect(find.text('Your turn'), findsNothing);

    await tester.tap(find.text('Next Round'));
    await tester.pump();

    expect(engine.advanceCount, 1);
    _expectActiveTurn(GamePlayer.second);
    expect(find.text('Next Round'), findsNothing);
  });

  testWidgets('shows each player their round wins', (tester) async {
    const board = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'scored',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(board, firstWins: 1),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('round-wins-first-1')), findsOneWidget);
    expect(find.byKey(const Key('round-wins-second-0')), findsOneWidget);
  });

  testWidgets('states the result without truncating it', (tester) async {
    const finalBoard = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      winner: GamePlayer.second,
      winReason: GameWinReason.immobilization,
      snapshotHash: 'legible',
    );
    addTearDown(tester.view.reset);

    for (final size in const [Size(320, 480), Size(390, 844)]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            key: ValueKey(size),
            rulesEngine: FakeRulesEngine.playing(
              initial: roundOverMatch(
                finalBoard,
                winner: GamePlayer.second,
                reason: GameWinReason.immobilization,
                firstWins: 0,
                secondWins: 1,
              ),
            ),
          ),
        ),
      );

      // Ellipsis is silent: it raises no exception and passes every layout
      // assertion while removing the half that says what happened.
      for (final text in const [
        'Player 2',
        'takes the round',
        'by immobilization',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          _inOverlay(text),
        );

        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"$text" is cut off at $size',
        );
      }
    }
  });

  testWidgets('cycles the opponent from the second seat panel', (tester) async {
    const board = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'opponent',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(board)),
        ),
      ),
    );

    expect(_inPanel('second', 'Player 2'), findsOneWidget);

    for (final label in const ['Random bot', 'Greedy bot', 'Minimax bot']) {
      await tester.tap(find.byKey(const Key('player-panel-second')));
      await tester.pump();

      expect(_inPanel('second', label), findsOneWidget, reason: label);
    }

    await tester.tap(find.byKey(const Key('player-panel-second')));
    await tester.pump();

    expect(_inPanel('second', 'Player 2'), findsOneWidget);
    // The first seat is always the person and never changes.
    expect(_inPanel('first', 'Player 1'), findsOneWidget);
  });

  testWidgets('lets the bot answer after a pause, not instantly', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      snapshotHash: 'bot-turn',
    );
    const answered = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'bot-answered',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [matchOf(answered, hash: 'answered-match')],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    await tester.tap(find.byKey(const Key('player-panel-second')));
    await tester.pump();

    // The board must not change while the person is still reading it.
    expect(engine.appliedMoves, isEmpty);

    await tester.pump(const Duration(milliseconds: 600));

    expect(engine.appliedMoves, [move]);
    expect(engine.botRequests, [BotPolicy.random]);
    _expectActiveTurn(GamePlayer.first);
  });

  testWidgets('cancels a pending bot move when the opponent changes', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      snapshotHash: 'cancelled',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [matchOf(botTurn, hash: 'unused')],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    await tester.tap(find.byKey(const Key('player-panel-second')));
    await tester.pump();
    // Hand the seat back to a person before the pause elapses.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('player-panel-second')));
    await tester.tap(find.byKey(const Key('player-panel-second')));
    await tester.tap(find.byKey(const Key('player-panel-second')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(engine.appliedMoves, isEmpty);
    expect(_inPanel('second', 'Player 2'), findsOneWidget);
  });

  testWidgets('keeps a valid board visible and retries a failed move', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'retry-move',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'move-retried',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(initialSnapshot)],
      moveResults: [
        StateError('bridge unavailable'),
        matchOf(nextSnapshot, hash: 'next'),
      ],
      legalMovesFor: (_) => const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    Offset cellCenter(int x, int y) {
      return Offset(
        boardRect.left + boardRect.width * (x + 0.5) / 5,
        boardRect.top + boardRect.height * (y + 0.5) / 5,
      );
    }

    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();

    _expectActiveTurn(GamePlayer.first);
    expect(find.textContaining('Unable to update round'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(engine.appliedMoves, [move, move]);
    _expectActiveTurn(GamePlayer.second);
    expect(find.textContaining('Unable to update round'), findsNothing);
  });
}

/// Maps a board cell to the point to tap for it.
Offset Function(int x, int y) _cellCenterOf(WidgetTester tester) {
  final board = tester.getRect(find.byKey(const Key('round-board-canvas')));
  return (x, y) => Offset(
    board.left + board.width * (x + 0.5) / 5,
    board.top + board.height * (y + 0.5) / 5,
  );
}

/// Scopes a text finder to one player's panel.
Finder _inPanel(String seat, String text) {
  return find.descendant(
    of: find.byKey(Key('player-panel-$seat')),
    matching: find.text(text),
  );
}

/// Scopes a text finder to the result overlay, since the panels carry the
/// player names too.
Finder _inOverlay(String text) {
  return find.descendant(
    of: find.byKey(const Key('result-overlay')),
    matching: find.text(text),
  );
}

/// Records what the page reported, without asserting how it is felt.
final class _RecordingFeedback implements RoundFeedback {
  final List<String> events = [];

  @override
  void pieceSelected() => events.add('select');

  @override
  void moveApplied() => events.add('move');

  @override
  void pushApplied() => events.add('push');

  @override
  void roundWon() => events.add('win');
}

void _expectActiveTurn(GamePlayer player) {
  expect(
    find.descendant(
      of: find.byKey(Key('player-panel-${player.name}')),
      matching: find.text('Your turn'),
    ),
    findsOneWidget,
  );
}
