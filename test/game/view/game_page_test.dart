import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';

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
      const MaterialApp(
        home: GamePage(
          rulesEngine: _FakeRulesEngine(snapshot: snapshot),
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
          rulesEngine: _SequencedRulesEngine(
            initialStateResults: [
              StateError('bridge unavailable'),
              readySnapshot,
            ],
            legalMoves: const [],
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
    final engine = _SequencedRulesEngine(
      initialStateResults: [terminalSnapshot, restartedSnapshot],
      legalMoves: const [],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    expect(find.text('Player 1 wins'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    await tester.tapAt(boardRect.center);

    expect(engine.appliedMoves, isEmpty);

    await tester.tap(find.text('Play Again'));
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
    final engine = _MoveRulesEngine(
      initialSnapshot: initialSnapshot,
      nextSnapshot: nextSnapshot,
      legalMoves: [move],
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
      final engine = _MoveRulesEngine(
        initialSnapshot: initialSnapshot,
        nextSnapshot: nextSnapshot,
        legalMoves: [move],
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
    final engine = _MoveRulesEngine(
      initialSnapshot: initialSnapshot,
      nextSnapshot: nextSnapshot,
      legalMoves: [move],
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
      const MaterialApp(
        home: GamePage(
          rulesEngine: _FakeRulesEngine(snapshot: terminalSnapshot),
        ),
      ),
    );

    expect(find.text('Player 2 wins'), findsOneWidget);
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
        const MaterialApp(
          home: GamePage(
            rulesEngine: _FakeRulesEngine(snapshot: snapshot),
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
        const MaterialApp(
          home: GamePage(
            key: Key('terminal'),
            rulesEngine: _FakeRulesEngine(snapshot: terminalSnapshot),
          ),
        ),
      );

      expect(find.text('Play Again'), findsOneWidget, reason: 'at $size');
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
      const MaterialApp(
        home: GamePage(
          rulesEngine: _FakeRulesEngine(snapshot: snapshot),
        ),
      ),
    );

    // A panel squeezed below its content height deforms the player mark
    // before it ever reports an overflow, so the mark is measured directly.
    final mark = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('player-panel-first')),
        matching: find.byType(DecoratedBox),
      ),
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
          rulesEngine: _MoveRulesEngine(
            initialSnapshot: start,
            nextSnapshot: afterMove,
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
          rulesEngine: _MoveRulesEngine(
            initialSnapshot: start,
            nextSnapshot: afterPush,
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
      'win',
    ]);
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
          rulesEngine: _MoveRulesEngine(
            initialSnapshot: start,
            nextSnapshot: afterPush,
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
          rulesEngine: const _FakeRulesEngine(snapshot: start),
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
          rulesEngine: _SequencedMoveRulesEngine(
            initialSnapshot: start,
            moves: const [move],
            moveResults: [StateError('bridge unavailable')],
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
          rulesEngine: _MoveRulesEngine(
            initialSnapshot: start,
            nextSnapshot: start,
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
          rulesEngine: _SequencedMoveRulesEngine(
            initialSnapshot: start,
            moves: const [pushUp],
            moveResults: [StateError('bridge unavailable'), afterPush],
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
          rulesEngine: _SequencedRulesEngine(
            initialStateResults: [StateError('bridge unavailable'), ready],
            legalMoves: const [],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(felt, isEmpty);
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
    final engine = _SequencedMoveRulesEngine(
      initialSnapshot: initialSnapshot,
      moves: [move],
      moveResults: [StateError('bridge unavailable'), nextSnapshot],
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

final class _FakeRulesEngine implements RulesEngine {
  const _FakeRulesEngine({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    throw UnsupportedError('applyMove is not used by this test');
  }

  @override
  GameSnapshot initialState() => snapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) => const [];
}

final class _SequencedRulesEngine implements RulesEngine {
  _SequencedRulesEngine({
    required this._initialStateResults,
    required this._legalMoves,
  });

  final List<Object> _initialStateResults;
  final List<GameMove> _legalMoves;
  final List<GameMove> appliedMoves = [];

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    appliedMoves.add(move);
    return state;
  }

  @override
  GameSnapshot initialState() {
    final result = _initialStateResults.removeAt(0);
    if (result case final GameSnapshot snapshot) {
      return snapshot;
    }
    if (result case final Error error) {
      throw error;
    }
    throw StateError('initial state result must be a GameSnapshot or Error');
  }

  @override
  List<GameMove> legalMoves(GameSnapshot state) => _legalMoves;
}

final class _MoveRulesEngine implements RulesEngine {
  _MoveRulesEngine({
    required this.initialSnapshot,
    required this.nextSnapshot,
    required this._legalMoves,
  });

  final GameSnapshot initialSnapshot;
  final GameSnapshot nextSnapshot;
  final List<GameMove> _legalMoves;
  final List<GameMove> appliedMoves = [];

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    appliedMoves.add(move);
    return nextSnapshot;
  }

  @override
  GameSnapshot initialState() => initialSnapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) {
    return state.snapshotHash == initialSnapshot.snapshotHash
        ? _legalMoves
        : const [];
  }
}

final class _SequencedMoveRulesEngine implements RulesEngine {
  _SequencedMoveRulesEngine({
    required this.initialSnapshot,
    required this.moves,
    required this.moveResults,
  });

  final GameSnapshot initialSnapshot;
  final List<GameMove> moves;
  final List<Object> moveResults;
  final List<GameMove> appliedMoves = [];

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    appliedMoves.add(move);
    final result = moveResults.removeAt(0);
    if (result case final GameSnapshot snapshot) {
      return snapshot;
    }
    if (result case final Error error) {
      throw error;
    }
    throw StateError('move result must be a GameSnapshot or Error');
  }

  @override
  GameSnapshot initialState() => initialSnapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) => moves;
}
